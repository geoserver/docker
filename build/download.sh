#!/bin/bash

# error out if any statements fail
set -e

# Update this each time a new release cycle started on https://github.com/geoserver/geoserver
MAIN="3.0"

function usage() {
  echo "$0 <version> [<clean>]"
  echo ""
  echo " version : The released version to build an docker image for (eg: 2.28.1, ${MAIN}-SNAPSHOT, ${MAIN}-RC)"
  echo " clean : Used to clear existing downloads from geoserver/ folder."
}


VERSION=$1
echo "clean: $2"
if [ -z $2 ]; then
  CLEAN="resume"
else
  CLEAN=$2
fi

echo "Downloading GeoServer for version $VERSION"

if [[ $VERSION =~ ^([0-9]+)\.([0-9]+) ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
else
  echo "Unable to determine major and minor version from $VERSION"
  exit 1
fi

if [[ "$VERSION" == *"-M"* ]]; then
    # milestone branch release
    BRANCH="${VERSION}"
    TAG=$BASE:$BRANCH
    GDAL_TAG=$TAG-$GDAL_SUFFIX
elif [[ "$VERSION" == *"-RC"* ]]; then
    # release candidate branch release
    BRANCH="${VERSION}"
    TAG=$BASE:$BRANCH
    GDAL_TAG=$TAG-$GDAL_SUFFIX
elif [[ "${VERSION}" == "$MAIN"* ]]; then
  # main branch snapshot release from main
  BRANCH="main"
  TAG=$BASE:$MAIN.x
  GDAL_TAG=$TAG-$GDAL_SUFFIX
else
  if [[ "$VERSION" == *"-SNAPSHOT"* ]]; then
    # stable or maintenance branch snapshot release
    BRANCH="${MAJOR}.${MINOR}.x"
    TAG=$BASE:$BRANCH
    GDAL_TAG=$TAG-$GDAL_SUFFIX
  else
    BRANCH="${MAJOR}.${MINOR}.x"
    TAG=$BASE:$VERSION
    GDAL_TAG=$TAG-$GDAL_SUFFIX
  fi
fi

# Go up one level to the Dockerfile
echo "  Download GeoSesrver $VERSION"

if [[ "$VERSION" == *"-SNAPSHOT"* ]]; then
  echo "  Download nightly build from https://build.geoserver.org/geoserver/$BRANCH"
  if [[ "$CLEAN" == "clean" ]]; then
    rm -rf "../geoserver/geoserver-$BRANCH-latest-war.zip"
  fi
  echo "  dowloading geoserver-$BRANCH-latest-war.zip"
  wget -c -q -P "../geoserver/" \
       "https://build.geoserver.org/geoserver/$BRANCH/geoserver-$BRANCH-latest-war.zip" 
else
  echo "  Download release build from https://downloads.sourceforge.net/project/geoserver/GeoServer/${VERSION}"
  if [[ "$CLEAN" == "clean" ]]; then
    rm -rf "../geoserver/geoserver-${VERSION}-war.zip"
  fi
  echo "  dowloading geoserver-${VERSION}-war.zip"
  wget -c -q -P "../geoserver/" "https://downloads.sourceforge.net/project/geoserver/GeoServer/${VERSION}/geoserver-${VERSION}-war.zip"
fi