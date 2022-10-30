#!/bin/bash

set -e

VER=2022f

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
3e2ef91b972f1872e3e8da9eae9d1c4638bfdb32600f164484edd7147be45a116db80443cd5ae61b5c34f8b841e4362f4beefd957633f6cc9b7def543ed6752b  tzcode2022f.tar.gz
72d05d05be999075cdf57b896c0f4238b1b862d4d0ed92cc611736592a4ada14d47bd7f0fc8be39e7938a7f5940a903c8af41e87859482bcfab787d889d429f6  tzdata2022f.tar.gz
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
