#!/bin/bash

# error out if any statements fail
set -e

# update this each time a new release cycle started on https://github.com/geoserver/geoserver
MAIN="3.0"

function usage() {
  echo "$0 <mode> <version> [<build>]"
  echo ""
  echo " mode : The mode. Choose one of 'build', 'publish' or 'buildandpublish'"
  echo " version : The released version to build an docker image for (eg: 2.28.1, ${MAIN}-SNAPSHOT, ${MAIN}-RC)"
  echo " build : Build number (optional)"
}

function build_geoserver_image() {
    local VERSION=$1
    local BUILD=$2
    local BUILD_GDAL=$3
    local TAG=$4
    local BRANCH=$5

    if [ -n "$VERSION" ] && [ -n "$BUILD" ] && [ -n "$BUILD_GDAL" ] && [ -n "$TAG" ]; then
      
      if [[ "$VERSION" == "3."* ]]; then
         GEOSERVER_BASE_IMAGE=tomcat:11.0-jdk21-temurin-noble
      else
         GEOSERVER_BASE_IMAGE=tomcat:9.0-jdk17-temurin-noble
      fi

      if [ -n "$BRANCH" ]; then
        # all needed vars are set

        (set -x # echo docker build command
        docker build \
            --build-arg WAR_ZIP_FILE="geoserver-$BRANCH-latest-war.zip" \
            --build-arg WAR_ZIP_URL="https://build.geoserver.org/geoserver/$BRANCH/geoserver-$BRANCH-latest-war.zip" \
            --build-arg STABLE_PLUGIN_URL="https://build.geoserver.org/geoserver/$BRANCH/ext-latest" \
            --build-arg COMMUNITY_PLUGIN_URL="https://build.geoserver.org/geoserver/$BRANCH/community-latest" \
            --build-arg GS_VERSION="$VERSION" \
            --build-arg GS_BUILD="$BUILD" \
            --build-arg BUILD_GDAL="$BUILD_GDAL" \
            --build-arg GEOSERVER_BASE_IMAGE="$GEOSERVER_BASE_IMAGE" \
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
    echo "  dowloading geoserver-$BRANCH-latest-war.zip"
    wget -c -q -P./geoserver/ \
         "https://build.geoserver.org/geoserver/$BRANCH/geoserver-$BRANCH-latest-war.zip" 
    echo
    build_geoserver_image $VERSION $BUILD "false" $TAG $BRANCH     # without gdal
    build_geoserver_image $VERSION $BUILD "true" $GDAL_TAG $BRANCH # with gdal
  else
    echo "  release build from https://downloads.sourceforge.net/project/geoserver/GeoServer/${VERSION}"
    echo "  dowloading geoserver-${VERSION}-war.zip"
    wget -c -q -P./geoserver/ \
         "https://downloads.sourceforge.net/project/geoserver/GeoServer/${VERSION}/geoserver-${VERSION}-war.zip"
    echo    
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
