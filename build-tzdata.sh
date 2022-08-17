#!/bin/bash

set -e

VER=2022c

base=$(dirname $(readlink -f $0))
cd $base

echo Downloading... >&2
download() {
  if [ ! -e $(basename "$1") ]; then
    wget "$1"
  fi
}

download http://www.iana.org/time-zones/repository/releases/tzdata$VER.tar.gz
download http://www.iana.org/time-zones/repository/releases/tzcode$VER.tar.gz
download http://www.iana.org/time-zones/repository/releases/tzdata$VER.tar.gz.asc
download http://www.iana.org/time-zones/repository/releases/tzcode$VER.tar.gz.asc

echo Checking... >&2

sha512sum tzcode$VER.tar.gz tzdata$VER.tar.gz

sha512sum -c /dev/stdin <<EOF
3373fa16a12007415c3dc3a75c4a0d61d6ae54968eeecedcdf4bcfd7f554020a15c4687dde107b90462b75d848eebe1e200c33322ebe0d3f1ad11bc769cade06  tzcode$VER.tar.gz
e2ae92abac6d87ce4ab4ba9012e868e1791b842e083293489debc0c671b9cf135b5b70426dacb6dbebbf6eba24463205225ae45bb7df891a086b25475f85ee0b  tzdata$VER.tar.gz
EOF

echo Unpacking... >&2
rm -rf ./tzdist
mkdir tzdist
cd tzdist
tar xzf ../tzcode$VER.tar.gz
tar xzf ../tzdata$VER.tar.gz

echo Building... >&2
make TOPDIR=$base/tzdist/dest ZFLAGS='-b fat' install

echo Renaming... >&2
cd $base
rm -rf tzdata
mv tzdist/dest/usr/share/zoneinfo tzdata
cd tzdata
find . -type f -name '[A-Z]*' -exec mv '{}' '{}.zone' \;

echo Patching for symlinked compilation... >&2
cd $base/tzdist
patch -p1 < $base/tzcode.patch

echo Building symlinked zoneinfo for compilation... >&2
make clean
make TOPDIR=$base/tzdist/dest ZFLAGS='-b fat' CFLAGS=-DHAVE_LINK=0 install

echo Cleaning up zoneinfo root directory... >&2
cd $base/tzdist/dest/usr/share/zoneinfo
# We don't want these:
rm -f *.tab Factory posixrules localtime leapseconds tzdata.zi
mkdir Root
find . -maxdepth 1 -type f -exec mv '{}' Root \;
for f in Root/*; do ln -s $f .; done

if [ "x$USE_CABAL" = "xYES" ]; then
  echo Compiling the tool... >&2
  cd $base
  cabal new-build genZones

  echo Creating DB.hs... >&2
  cd $base
  cabal new-run genZones -- tzdist/dest/usr/share/zoneinfo/ Data/Time/Zones/DB.hs.template Data/Time/Zones/DB.hs
else
  echo Compiling the tool... >&2
  cd $base
  stack build tools/

  echo Creating DB.hs... >&2
  cd $base
  stack exec genZones tzdist/dest/usr/share/zoneinfo/ Data/Time/Zones/DB.hs.template Data/Time/Zones/DB.hs
fi
