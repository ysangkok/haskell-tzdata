#!/bin/bash

set -e

VER=2023a

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
d45fc677a0a32ae807bf421faceff675565ee15e3ff42d3a4121df10e1f7855ac16b27fbc28bd365f93c57f40c5bdf19cde88546f7090cfab7676cac0a5516a4  tzcode2023a.tar.gz
10aadd6eba50f63f427399281065ba34cb474f6a854f8dc7a6f4f1343b1474a05f22b69b1e113ea67bb5f3f479253610a16b89d9dfa157bf0fde4c69aa3d6493  tzdata2023a.tar.gz
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

sudo apt install rdfind
# How do decide which tz is the 'primary'? We punt and just use the
# deterministic flag from rdfind.
RDFIND="rdfind -dryrun false -removeidentinode false -deterministic true -makeresultsfile false"

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
