#!/bin/bash

# error out if any statements fail
set -e

MAIN="3.0"

function usage() {
  echo "$0 <mode> <version> [<build>]"
  echo ""
  echo " mode : The mode. Choose one of 'build', 'publish' or 'buildandpublish'"
  echo " version : The released version to build an docker image for (eg: 2.27.1, ${MAIN}-SNAPSHOT, ${MAIN}-RC)"
  echo " build : Build number (optional)"
}

function build_geoserver_image() {
    local VERSION=$1
    local BUILD=$2
    local BUILD_GDAL=$3
    local TAG=$4
    local BRANCH=$5

    if [ -n "$VERSION" ] && [ -n "$BUILD" ] && [ -n "$BUILD_GDAL" ] && [ -n "$TAG" ]; then
      if [ -n "$BRANCH" ]; then
        # all needed vars are set

        (set -x # echo docker build command
        docker build \
            --build-arg WAR_ZIP_URL="https://build.geoserver.org/geoserver/$BRANCH/geoserver-$BRANCH-latest-war.zip" \
            --build-arg STABLE_PLUGIN_URL="https://build.geoserver.org/geoserver/$BRANCH/ext-latest" \
            --build-arg COMMUNITY_PLUGIN_URL="https://build.geoserver.org/geoserver/$BRANCH/community-latest" \
            --build-arg GS_VERSION="$VERSION" \
            --build-arg GS_BUILD="$BUILD" \
            --build-arg BUILD_GDAL="$BUILD_GDAL" \
            -t "$TAG" .)
      elif [ -z "$BRANCH" ]; then
        # BRANCH is not set

        (set -x # echo docker build command
        docker build \
          --build-arg GS_VERSION=$VERSION \
          --build-arg GS_BUILD=$BUILD \
          --build-arg BUILD_GDAL=$BUILD_GDAL \
          -t $TAG .)
      fi

    else
      echo "Missing required parameters"
      exit 1
    fi
}

if [ -z $1 ] || [ -z $2 ] || [[ $1 != "build" && $1 != "publish" && $1 != "buildandpublish" ]]; then
  usage
  exit
fi

VERSION=$2
echo "build: $3"
if [ -z $3 ]; then
  BUILD='local'
else
  BUILD=$3
fi

BASE=geoserver-docker.osgeo.org/geoserver
GDAL_SUFFIX=gdal

echo "Building GeoServer Docker Image for version $VERSION"

if [[ "$VERSION" == *"-M"* ]]; then
    # release candidate branch release
    BRANCH="${VERSION}"
    TAG=$BASE:$BRANCH
    GDAL_TAG=$TAG-$GDAL_SUFFIX
elif [[ "$VERSION" == *"-RC"* ]]; then
    # release candidate branch release
    BRANCH="${VERSION}"
    TAG=$BASE:$BRANCH
    GDAL_TAG=$TAG-$GDAL_SUFFIX
elif [[ "${VERSION:0:4}" == "$MAIN" ]]; then
  # main branch snapshot release
  BRANCH=main
  TAG=$BASE:$MAIN.x
  GDAL_TAG=$TAG-$GDAL_SUFFIX
else
  if [[ "$VERSION" == *"-SNAPSHOT"* ]]; then
  # stable or maintenance branch snapshot release
  BRANCH="${VERSION:0:4}.x"
  TAG=$BASE:$BRANCH
  GDAL_TAG=$TAG-$GDAL_SUFFIX
  else
  BRANCH="${VERSION:0:4}.x"
  TAG=$BASE:$VERSION
  GDAL_TAG=$TAG-$GDAL_SUFFIX
  fi
fi

# Prerequisite for Multi-Arch via QEM
# docker run --privileged --rm tonistiigi/binfmt --install all

echo "Release from branch $BRANCH GeoServer $VERSION as $TAG"
echo "Release from branch $BRANCH GeoServer $VERSION (with GDAL) as $GDAL_TAG"

# Go up one level to the Dockerfile
cd ".."

if [[ $1 == *build* ]]; then
  echo "Building GeoServer Docker Image..."
  if [[ "$VERSION" == *"-SNAPSHOT"* ]]; then
    echo "  nightly build from https://build.geoserver.org/geoserver/$BRANCH"
    echo
    build_geoserver_image $VERSION $BUILD "false" $TAG $BRANCH     # without gdal
    build_geoserver_image $VERSION $BUILD "true" $GDAL_TAG $BRANCH # with gdal
  else
    build_geoserver_image $VERSION $BUILD "false" $TAG   # without gdal
    build_geoserver_image $VERSION $BUILD "true" $GDAL_TAG # with gdal
  fi
fi

if [[ $1 == *"publish"* ]]; then
  echo "Publishing GeoServer Docker Images..."
  echo $DOCKERPASSWORD | docker login -u $DOCKERUSER --password-stdin geoserver-docker.osgeo.org
  echo "docker push $TAG"
  docker push $TAG
  echo "docker push $GDAL_TAG"
  docker push $GDAL_TAG
fi
