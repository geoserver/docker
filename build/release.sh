#!/bin/bash

# error out if any statements fail
set -e

function usage() {
  echo "$0 [options] <version>"
  echo " version : The released version to build an docker image for (eg: 2.1.4)"
  echo " mode : The mode. Choose one of 'build', 'publish' or 'buildandpublish'"
}

if [ -z $1 ] || [ -z $2 ] || [[ $2 != "build" && $2 != "publish" && $2 != "buildandpublish" ]]; then
  usage
  exit
fi

VERSION=$1
TAG=geoserver-docker.osgeo.org/geoserver:$VERSION

# Go up one level to the Dockerfile
cd ".."

if [ $2 != "publish" ]; then
  echo "Building GeoServer Docker Image..."
  echo "docker build --build-arg GS_VERSION=$VERSION -t $TAG ."
  docker build --build-arg GS_VERSION=$VERSION -t $TAG .
fi

if [ $2 != "build" ]; then
  echo "Publishing GeoServer Docker Image..."
  echo $DOCKERPASSWORD | docker login -u $DOCKERUSER --password-stdin geoserver-docker.osgeo.org
  echo "docker push $TAG"
  docker push $TAG
fi
