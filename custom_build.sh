#!/bin/bash

set -e
TAG=${1}
readonly GEOSERVER_VERSION=${2}
readonly GEOSERVER_MASTER_VERSION=${3}
readonly GEOSERVER_DATA_DIR_RELEASE=${4}
readonly PULL=${5}
readonly ALL_PARAMETERS=$*
readonly BASE_BUILD_URL="https://build.geoserver.org/geoserver"
readonly BASE_BUILD_URL_STABLE="https://netcologne.dl.sourceforge.net/project/geoserver/GeoServer"
readonly EXTRA_FONTS_URL="https://www.dropbox.com/s/hs5743lwf1rktws/fonts.tar.gz?dl=1"
readonly MARLIN_VERSION=0.9.2
readonly ARTIFACT_DIRECTORY=./resources
readonly GEOSERVER_ARTIFACT_DIRECTORY=${ARTIFACT_DIRECTORY}/geoserver/
readonly DATADIR_ARTIFACT_DIRECTORY=${ARTIFACT_DIRECTORY}/geoserver-datadir/
readonly PLUGIN_ARTIFACT_DIRECTORY=${ARTIFACT_DIRECTORY}/geoserver-plugins
readonly FONTS_ARTIFACT_DIRECTORY=${ARTIFACT_DIRECTORY}/fonts/
readonly MARLIN_ARTIFACT_DIRECTORY=${ARTIFACT_DIRECTORY}/marlin/

function help(){
	if [ "$#" -ne 6 ] ; then
		echo "Usage: $0 [docker image tag] [geoserver version] [geoserver master version] [datadir| nodatadir] [pull|no pull];"
		echo "";
		echo "[docker image tag] :          the tag to be used for the docker iamge ";
		echo "[geoserver version] :         the release version of geoserver to be used; you can set it to master if you want the last release";
		echo "[geoserver master version] :  if you use the master version for geoserver you need to set it to the numerical value for the next release;"
		echo "                              if you use a released version you need to put it to the release number";
		echo "[datadir| nodatadir]:         if this parameter is equal to nodatadir the datadir is not burned in the docker images ";
		echo "[pull|no pull]:               docker build use always a remote image or a local image";
		exit 1;
	fi
}

function clean_up_directory() {
	rm -rf ${1}/*
}

function download_from_url_to_a_filepath {
	URL=${1}
	FILE_PATH=${2}
	FILE_DOWNLOADED=$(basename "${FILE_PATH}" )
	if [ -f "${FILE_PATH}" ]; then
		rm -f "${FILE_PATH}"
	fi
	if [ ! -f "${FILE_PATH}" ]; then
		curl -L "${URL}" --output "${FILE_PATH}"
		echo "* ${FILE_DOWNLOADED} artefact dowloaded *"
	else
		echo "* ${FILE_DOWNLOADED} artefact already dowloaded *"
	fi
}

function download_plugin()  {
	TYPE=${1}
	PLUGIN_NAME=${2}

	case ${GEOSERVER_VERSION} in
		"${GEOSERVER_MASTER_VERSION::-2}.x")
		PLUGIN_FULL_NAME=geoserver-${GEOSERVER_VERSION::-2}-SNAPSHOT-${PLUGIN_NAME}-plugin.zip
		PLUGIN_ARTIFACT_URL=${BASE_BUILD_URL}/${GEOSERVER_VERSION}/${TYPE}-latest/${PLUGIN_FULL_NAME}
		;;

		"master")
		PLUGIN_FULL_NAME=geoserver-${GEOSERVER_MASTER_VERSION::-2}-SNAPSHOT-${PLUGIN_NAME}-plugin.zip
		PLUGIN_ARTIFACT_URL=${BASE_BUILD_URL}/${GEOSERVER_VERSION}/${TYPE}-latest/${PLUGIN_FULL_NAME}
		;;

		*)
		PLUGIN_FULL_NAME=geoserver-${GEOSERVER_VERSION}-${PLUGIN_NAME}-plugin.zip
		if [ "${TYPE}" == "ext" ]; then
			NEWTYPE=extensions
			PLUGIN_ARTIFACT_URL=${BASE_BUILD_URL_STABLE}/${GEOSERVER_VERSION}/${NEWTYPE}/${PLUGIN_FULL_NAME}
		else
			VERSION="${GEOSERVER_VERSION::-2}-SNAPSHOT"
			PLUGIN_FULL_NAME=geoserver-${VERSION}-${PLUGIN_NAME}-plugin.zip
			PLUGIN_ARTIFACT_URL=${BASE_BUILD_URL}/${GEOSERVER_VERSION::-2}.x/${TYPE}-latest/${PLUGIN_FULL_NAME}
		fi
		;;

	esac


  if [ ! -e "${PLUGIN_ARTIFACT_URL}" ]; then
      mkdir -p "${PLUGIN_ARTIFACT_URL}"
  fi



  download_from_url_to_a_filepath "${PLUGIN_ARTIFACT_URL}" "${PLUGIN_ARTIFACT_DIRECTORY}/${PLUGIN_FULL_NAME}"
}

function download_fonts()  {
    if [ ! -e "${FONTS_ARTIFACT_DIRECTORY}" ]; then
        mkdir -p "${FONTS_ARTIFACT_DIRECTORY}"
    fi
    download_from_url_to_a_filepath "${EXTRA_FONTS_URL}" "${FONTS_ARTIFACT_DIRECTORY}/fonts.tar.gz"
}

function download_marlin()  {
    IFS='.' read -r -a marlin_v_arr <<< "$MARLIN_VERSION"
    unset IFS

    marlin_major=${marlin_v_arr[0]}
    marlin_minor=${marlin_v_arr[1]}
    marlin_patch=${marlin_v_arr[2]}

    if [ ! -e "${MARLIN_ARTIFACT_DIRECTORY}" ]; then
        mkdir -p "${MARLIN_ARTIFACT_DIRECTORY}"
    fi

    marlin_url_1="https://github.com/bourgesl/marlin-renderer/releases/download/v${marlin_major}_${marlin_minor}_${marlin_patch}/marlin-${marlin_major}.${marlin_minor}.${marlin_patch}-Unsafe.jar"
    marlin_url_2="https://github.com/bourgesl/marlin-renderer/releases/download/v${marlin_major}_${marlin_minor}_${marlin_patch}/marlin-${marlin_major}.${marlin_minor}.${marlin_patch}-Unsafe-sun-java2d.jar"
    download_from_url_to_a_filepath "${marlin_url_1}" "${MARLIN_ARTIFACT_DIRECTORY}/marlin-${marlin_major}.${marlin_minor}.${marlin_patch}-Unsafe.jar"
    download_from_url_to_a_filepath "${marlin_url_2}" "${MARLIN_ARTIFACT_DIRECTORY}/marlin-${marlin_major}.${marlin_minor}.${marlin_patch}-Unsafe-sun-java2d.jar"
}

function download_geoserver() {
    clean_up_directory ${GEOSERVER_ARTIFACT_DIRECTORY}
    local VERSION=${1}
    local GEOSERVER_FILE_NAME_NIGHTLY="geoserver-${VERSION}-latest-war.zip"
		local GEOSERVER_FILE_NAME_STABLE="geoserver-${VERSION}-war.zip"

		if [[ ( "${VERSION}" =~ "x" ) || ( "${VERSION}" == "master" ) ]]; then
			local GEOSERVER_ARTIFACT_URL=${BASE_BUILD_URL}/${VERSION}/${GEOSERVER_FILE_NAME_NIGHTLY}
		else
			local GEOSERVER_ARTIFACT_URL=${BASE_BUILD_URL_STABLE}/${VERSION}/${GEOSERVER_FILE_NAME_STABLE}
		fi

    if [ -f /tmp/geoserver.war.zip ]; then
        rm /tmp/geoserver.war.zip
    fi
    if [ ! -e "${GEOSERVER_ARTIFACT_DIRECTORY}" ]; then
        mkdir -p "${GEOSERVER_ARTIFACT_DIRECTORY}"
    fi
    download_from_url_to_a_filepath  "${GEOSERVER_ARTIFACT_URL}" "/tmp/geoserver.war.zip"
    unzip -p /tmp/geoserver.war.zip geoserver.war > ${GEOSERVER_ARTIFACT_DIRECTORY}/geoserver.war
}


function build_with_data_dir() {

	local TAG=${1}
        local PULL_ENABLED=${2}
        if [[ "${PULL_ENABLED}" == "pull" ]]; then
                DOCKER_BUILD_COMMAND="docker build --pull"
        else
                DOCKER_BUILD_COMMAND="docker build"
        fi;
	${DOCKER_BUILD_COMMAND} --no-cache \
		--build-arg GEOSERVER_WEBAPP_SRC=${GEOSERVER_ARTIFACT_DIRECTORY}/geoserver.war \
    --build-arg PLUG_IN_URLS=$PLUGIN_ARTIFACT_DIRECTORY \
    --build-arg GEOSERVER_DATA_DIR_SRC=${GEOSERVER_DATA_DIR_DIRECTORY} \
		-t geosolutionsit/geoserver:"${TAG}-${GEOSERVER_VERSION}" \
		 .
}

function build_without_data_dir() {

	local TAG=${1}
	local PULL_ENABLED=${2}
	if [[ "${PULL_ENABLED}" == "pull" ]]; then
		DOCKER_BUILD_COMMAND="docker build --pull"
	else
		DOCKER_BUILD_COMMAND="docker build"
	fi;
	${DOCKER_BUILD_COMMAND} --no-cache \
		--build-arg GEOSERVER_WEBAPP_SRC=${GEOSERVER_ARTIFACT_DIRECTORY}/geoserver.war \
    --build-arg PLUG_IN_URLS=$PLUGIN_ARTIFACT_DIRECTORY\
		-t geosolutionsit/geoserver:"${TAG}-${GEOSERVER_VERSION}" \
		 .
}

function main {
    help ${ALL_PARAMETERS}
    download_geoserver "${GEOSERVER_VERSION}"
    clean_up_directory ${PLUGIN_ARTIFACT_DIRECTORY}
    download_plugin ext monitor
    download_plugin ext control-flow
    download_plugin community sec-oauth2-geonode
    #download_marlin

	if  [[ ${GEOSERVER_DATA_DIR_RELEASE} = "nodatadir" ]]; then
   	    build_without_data_dir "${TAG}" "${PULL}"
   	else
   		clean_up_directory ${DATADIR_ARTIFACT_DIRECTORY}
 		build_with_data_dir "${TAG}" "${PULL}"
   	fi
}

main
