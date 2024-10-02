#!/bin/bash
# Inspired by https://github.com/kartoza/docker-geoserver

function download_extension() {
  URL=$1
  EXTENSION=$2
  VERSION=$3
  DOWNLOAD_FILE="${ADDITIONAL_LIBS_DIR}geoserver-${VERSION}-${EXTENSION}-plugin.zip"

  if [ -e "$DOWNLOAD_FILE" ]; then
      echo "$DOWNLOAD_FILE already exists. Skipping download."
  else
    echo -e "\nDownloading ${EXTENSION} extension from ${URL} to ${DOWNLOAD_FILE}"
    wget --progress=bar:force:noscroll -c $WGET_OPTS "${URL}" -O ${DOWNLOAD_FILE}
    if [ "$?" != 0 ]; then
        echo "ERROR downloading: ${URL}"
    fi
  fi
}

function install_lib() {
    ADDITIONAL_LIB=$1
    if [ ! -e "$ADDITIONAL_LIB" ]; then
      echo "Skipping ${ADDITIONAL_LIB}: file not found."
      return
    fi

    if [[ $ADDITIONAL_LIB == *.zip ]]; then
      unzip -q -o -d ${GEOSERVER_LIB_DIR} ${ADDITIONAL_LIB} "*.jar"
      echo "Installed all jar files from ${ADDITIONAL_LIB}"
    elif [[ $ADDITIONAL_LIB == *.jar ]]; then
      cp ${ADDITIONAL_LIB} ${GEOSERVER_LIB_DIR}
      echo "Installed ${ADDITIONAL_LIB}"
    else
      echo "Skipping ${ADDITIONAL_LIB}: unknown file extension."
    fi
}

# Download plugins only if DOWNLOAD_EXTENSIONS is true
if [ "$DOWNLOAD_EXTENSIONS" = "true" ]; then
  echo "Starting download of extensions"
  if [ ! -d "$ADDITIONAL_LIBS_DIR" ]; then
    mkdir -p $ADDITIONAL_LIBS_DIR
  fi
  for EXTENSION in $(echo "${STABLE_EXTENSIONS}" | tr ',' ' '); do
    URL="${STABLE_PLUGIN_URL}/geoserver-${GEOSERVER_VERSION}-${EXTENSION}-plugin.zip"
    download_extension ${URL} ${EXTENSION} ${GEOSERVER_VERSION}
  done
  if [ ${#COMMUNITY_EXTENSIONS} -gt 0 ]; then
    # build community version string from GEOSERVER_VERSION by removing the last part and adding SNAPSHOT
    if [ -z "$COMMUNITY_EXTENSIONS_VERSION" ]; then
      COMMUNITY_EXTENSIONS_VERSION="${GEOSERVER_VERSION/-SNAPSHOT/.x}"
      COMMUNITY_EXTENSIONS_VERSION="${COMMUNITY_EXTENSIONS_VERSION%.*}-SNAPSHOT"
    fi
    COMMUNITY_PLUGIN_BASE_URL=${COMMUNITY_PLUGIN_BASE_URL:-"https://build.geoserver.org/geoserver/"}
    if [ -z "$GEOSERVER_RELEASE_BRANCH" ]; then
      GEOSERVER_RELEASE_BRANCH="${GEOSERVER_VERSION/-SNAPSHOT/.x}"
      GEOSERVER_RELEASE_BRANCH="${GEOSERVER_RELEASE_BRANCH%.*}.x"

    fi
    COMMUNITY_PLUGIN_URL=${COMMUNITY_PLUGIN_URL:-"${COMMUNITY_PLUGIN_BASE_URL}${GEOSERVER_RELEASE_BRANCH}/community-latest/"}

    echo "installing community modules from COMMUNITY_PLUGIN_URL=${COMMUNITY_PLUGIN_URL} with GEOSERVER_RELEASE_BRANCH=${GEOSERVER_RELEASE_BRANCH} and COMMUNITY_EXTENSIONS_VERSION=${COMMUNITY_EXTENSIONS_VERSION} from GEOSERVER_VERSION=${GEOSERVER_VERSION}"



    for EXTENSION in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
      URL="${COMMUNITY_PLUGIN_URL}/geoserver-${COMMUNITY_EXTENSIONS_VERSION}-${EXTENSION}-plugin.zip"
      download_extension ${URL} ${EXTENSION} ${COMMUNITY_EXTENSIONS_VERSION}
    done
  fi
  echo "Finished download of extensions"
else
  echo "Skipping download of extensions as DOWNLOAD_EXTENSIONS is false"
fi

# Install the extensions only if INSTALL_EXTENSIONS is true
if [ "$INSTALL_EXTENSIONS" = "true" ]; then
  echo "Starting installation of extensions"
  for EXTENSION in $(echo "${STABLE_EXTENSIONS}" | tr ',' ' '); do
    ADDITIONAL_LIB=${ADDITIONAL_LIBS_DIR}geoserver-${GEOSERVER_VERSION}-${EXTENSION}-plugin.zip
    install_lib $ADDITIONAL_LIB
  done
  if [ ${#COMMUNITY_EXTENSIONS} -gt 0 ]; then
    # print warning if COMMUNITY extensions are installed on an official release (where GEOSERVER_VERSION is not ending with -SNAPSHOT)
    if [[ ! $GEOSERVER_VERSION == *-SNAPSHOT ]]; then
      echo "WARNING: Installing community extensions on an official release version. Be sure to check compatibility."
    fi
    
    for EXTENSION in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
      if [ -z "$COMMUNITY_EXTENSIONS_VERSION" ]; then
        COMMUNITY_EXTENSIONS_VERSION="${GEOSERVER_VERSION%.*}-SNAPSHOT"
      fi
      ADDITIONAL_LIB=${ADDITIONAL_LIBS_DIR}geoserver-${COMMUNITY_EXTENSIONS_VERSION}-${EXTENSION}-plugin.zip
      install_lib $ADDITIONAL_LIB
    done
  fi
  echo "Finished installation of extensions"
else
  echo "Skipping installation of extensions as INSTALL_EXTENSIONS is false"
fi
