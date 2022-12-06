#!/bin/bash

set -e

VER=2022g

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
5188edd8d05238a88da734cf78fadfb57640d4db3e7a0a9dddd70e3071e16b6eebc2e2ab17109b7dafafae68abfbc857df481cfdc3ffe63f7eb1569ea0b5997a  tzcode2022g.tar.gz
7f79394295e00e3a24ebdbf9af3bc454a65f432a93b517e7e96c7f9db9949f6f5fdae9892a9d3789ff44ae0eb1bfe4744d36976b4624659af951d26414f94e65  tzdata2022g.tar.gz
EOF

echo Unpacking... >&2
rm -rf ./tzdist
mkdir tzdist
cd tzdist
tar xzf ../tzcode$VER.tar.gz
tar xzf ../tzdata$VER.tar.gz

echo Building symlinked zoneinfo for compilation... >&2
cd $base/tzdist
make TOPDIR=$base/tzdist/dest ZFLAGS='-b fat' CFLAGS=-DHAVE_LINK=0 install

mkdir $base/tzdata
rm dest/usr/share/zoneinfo/leapseconds
rm dest/usr/share/zoneinfo/tzdata.zi
mv dest/usr/share/zoneinfo/*.tab $base/tzdata

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
find $base/tzdist/dest/usr/share/zoneinfo -type f -name '[A-Z]*' -exec mv '{}' '{}.zone' \;
cp -vr $base/tzdist/dest/usr/share/zoneinfo/* $base/tzdata/
