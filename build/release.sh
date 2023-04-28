#!/bin/bash

# error out if any statements fail
set -e

function usage() {
  echo "$0 [options] <version>"
  echo " version : The released version to build an docker image for (eg: 2.23.1, 2.24-SNAPSHOT)"
  echo " mode : The mode. Choose one of 'build', 'publish' or 'buildandpublish'"
}

if [ -z $1 ] || [ -z $2 ] || [[ $2 != "build" && $2 != "publish" && $2 != "buildandpublish" ]]; then
  usage
  exit
fi

VERSION=$1
MAIN="2.24"
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

echo "Release from branch $BRANCH GeoServer $VERSION as $TAG" 

# Go up one level to the Dockerfile
cd ".."

if [[ $2 == *build* ]]; then
  echo "Building GeoServer Docker Image..."
  if [[ "$VERSION" == *"-SNAPSHOT"* ]]; then
    echo "  nightly build from https://build.geoserver.org/geoserver/$BRANCH"
    echo
    if [[ "$BRANCH" == "main" ]]; then
      echo "docker build --build-arg GS_VERSION=$VERSION -t $TAG ."
      docker build \
        --build-arg WAR_ZIP_URL=https://build.geoserver.org/geoserver/main/geoserver-main-latest-war.zip \
        --build-arg STABLE_PLUGIN_URL=https://build.geoserver.org/geoserver/main/ext-latest/ \
        --build-arg COMMUNITY_PLUGIN_URL=https://build.geoserver.org/geoserver/main/community-latest/ \
        --build-arg GS_VERSION=$VERSION \
        -t $TAG .
    else
      echo "docker build --build-arg GS_VERSION=$VERSION -t $TAG ."
      docker build \
        --build-arg WAR_ZIP_URL=https://build.geoserver.org/geoserver/$BRANCH/geoserver-$BRANCH-latest-war.zip \
        --build-arg STABLE_PLUGIN_URL=https://build.geoserver.org/geoserver/$BRANCH/ext-latest/ \
        --build-arg COMMUNITY_PLUGIN_URL=https://build.geoserver.org/geoserver/$BRANCH/community-latest/ \
        --build-arg GS_VERSION=$VERSION \
        -t $TAG .
    fi
  else
    echo "docker build --build-arg GS_VERSION=$VERSION -t $TAG ."
    docker build --build-arg GS_VERSION=$VERSION -t $TAG .
  fi
fi

if [[ $2 == *"publish"* ]]; then
  echo "Publishing GeoServer Docker Image..."
  echo $DOCKERPASSWORD | docker login -u $DOCKERUSER --password-stdin geoserver-docker.osgeo.org
  echo "docker push $TAG"
  docker push $TAG
fi
