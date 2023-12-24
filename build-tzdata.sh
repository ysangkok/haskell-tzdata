#!/bin/bash

set -e

VER=2023d

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
3994a5a060a7a5fffc6585f5191cf7679f9f9be44dbcee4d67d0e42c5b6020c308cb55caf8bf8d51554697665105a174cb470c8c4fc069438350f3bac725709b  tzcode2023d.tar.gz
81832b2d738c28cecbcb3906cc07568c5ae574adc9de35b25d4bf613581c92d471d67213b4261a56f0ec02efcf211b4e298b7e1dc367c972e726b0a2e9498df4  tzdata2023d.tar.gz
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

sudo apt install rdfind fdupes
# How do decide which tz is the 'primary'? We punt and just use the
# deterministic flag from rdfind.
RDFIND="rdfind -dryrun false -removeidentinode false -deterministic true -makeresultsfile false"

fdupes -Hr $base/tzdist/dest/usr/share/zoneinfo | python3 $base/split.py | sh
$RDFIND -makesymlinks true -makehardlinks false $base/tzdist/dest/usr/share/zoneinfo

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

# Convert symlinks from above back into hardlinks, so that ... (continued below)
find $base/tzdist/dest/usr/share/zoneinfo -type l -exec bash -c 'ln -f "$(readlink -m "$0")" "$0"' {} \;

# ... this command won't break them
find $base/tzdist/dest/usr/share/zoneinfo -type f -name '[A-Z]*' -exec mv '{}' '{}.zone' \;

cp -vr $base/tzdist/dest/usr/share/zoneinfo/* $base/tzdata/
