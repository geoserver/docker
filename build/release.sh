#!/bin/bash

# error out if any statements fail
set -e

MAIN="2.26"

function usage() {
  echo "$0 <mode> <version> [<build>]"
  echo ""
  echo " mode : The mode. Choose one of 'build', 'publish' or 'buildandpublish'"
  echo " version : The released version to build an docker image for (eg: 2.25.2, ${MAIN}-SNAPSHOT, ${MAIN}-RC)"
  echo " build : Build number (optional)"
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

if [[ "$VERSION" == *"-RC"* ]]; then
    # release candidate branch release
    BRANCH="${VERSION:0:4}-RC"
    TAG=geoserver-docker.osgeo.org/geoserver:$BRANCH
else
  if [[ "${VERSION:0:4}" == "$MAIN" ]]; then
    # main branch snapshot release
    BRANCH=main
    TAG=geoserver-docker.osgeo.org/geoserver:$MAIN.x
  else
    if [[ "$VERSION" == *"-SNAPSHOT"* ]]; then
    # stable or maintenance branch snapshot release
    BRANCH="${VERSION:0:4}.x"
    TAG=geoserver-docker.osgeo.org/geoserver:$BRANCH
    else
    BRANCH="${VERSION:0:4}.x"
    TAG=geoserver-docker.osgeo.org/geoserver:$VERSION
    fi
  fi
fi

echo "Release from branch $BRANCH GeoServer $VERSION as $TAG"

# Go up one level to the Dockerfile
cd ".."

if [[ $1 == *build* ]]; then
  echo "Building GeoServer Docker Image..."
  if [[ "$VERSION" == *"-SNAPSHOT"* ]]; then
    echo "  nightly build from https://build.geoserver.org/geoserver/$BRANCH"
    echo
    if [[ "$BRANCH" == "main" ]]; then
      echo "docker build --build-arg GS_VERSION=$VERSION --build-arg GS_BUILD=$BUILD -t $TAG ."
      # todo: --no-cache-filter download,install
      docker build \
        --build-arg WAR_ZIP_URL=https://build.geoserver.org/geoserver/main/geoserver-main-latest-war.zip \
        --build-arg STABLE_PLUGIN_URL=https://build.geoserver.org/geoserver/main/ext-latest \
        --build-arg COMMUNITY_PLUGIN_URL=https://build.geoserver.org/geoserver/main/community-latest \
        --build-arg GS_VERSION=$VERSION \
        --build-arg GS_BUILD=$BUILD \
        -t $TAG .
    else
      echo "docker build --build-arg GS_VERSION=$VERSION --build-arg GS_BUILD=$BUILD -t $TAG ."
      docker build \
        --build-arg WAR_ZIP_URL=https://build.geoserver.org/geoserver/$BRANCH/geoserver-$BRANCH-latest-war.zip \
        --build-arg STABLE_PLUGIN_URL=https://build.geoserver.org/geoserver/$BRANCH/ext-latest \
        --build-arg COMMUNITY_PLUGIN_URL=https://build.geoserver.org/geoserver/$BRANCH/community-latest \
        --build-arg GS_VERSION=$VERSION \
        --build-arg GS_BUILD=$BUILD \
        -t $TAG .
    fi
  else
    echo "docker build --build-arg GS_VERSION=$VERSION --build-arg GS_BUILD=$BUILD -t $TAG ."
    docker build \
      --build-arg GS_VERSION=$VERSION \
      --build-arg GS_BUILD=$BUILD \
      -t $TAG .
  fi
fi

if [[ $1 == *"publish"* ]]; then
  echo "Publishing GeoServer Docker Image..."
  echo $DOCKERPASSWORD | docker login -u $DOCKERUSER --password-stdin geoserver-docker.osgeo.org
  echo "docker push $TAG"
  docker push $TAG
fi
