#!/bin/bash
# Inspired by https://github.com/kartoza/docker-geoserver

function download_extension() {
  URL=$1
  EXTENSION=$2
  DOWNLOAD_FILE="${ADDITIONAL_LIBS_DIR}geoserver-${GS_VERSION}-${EXTENSION}-plugin.zip"

  if [ -e "$DOWNLOAD_FILE" ]; then
      echo "$DOWNLOAD_FILE already exists. Skipping download."
  else
    if curl --output /dev/null --silent --head --fail "${URL}"; then
        echo -e "\nDownloading ${EXTENSION}-extension from ${URL}"
        wget --progress=bar:force:noscroll -c --no-chec k-certificate "${URL}" -O ${DOWNLOAD_FILE}
      else
        echo "URL does not exist: ${URL}"
    fi
  fi
}

# Download stable plugins only if DOWNLOAD_EXTENSIONS is true
if [ "$DOWNLOAD_EXTENSIONS" = "true" ]; then
  echo "Starting download of extensions"
  for EXTENSION in $(echo "${STABLE_EXTENSIONS}" | tr ',' ' '); do
    URL="${STABLE_PLUGIN_URL}/geoserver-${GS_VERSION}-${EXTENSION}-plugin.zip"
    download_extension ${URL} ${EXTENSION}
  done
  echo "Finished download of extensions"
fi

TARGET_LIB_DIR="${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/"
# Install all extensions that are available in the additional lib dir now
echo "Starting installation of extensions"
for ADDITIONAL_LIB in ${ADDITIONAL_LIBS_DIR}*; do
  [ -e "$ADDITIONAL_LIB" ] || continue

  if [[ $ADDITIONAL_LIB == *.zip ]]; then
    unzip -q -o -d ${TARGET_LIB_DIR} ${ADDITIONAL_LIB} "*.jar"
    echo "Installed all jar files from ${ADDITIONAL_LIB}"
  elif [[ $ADDITIONAL_LIB == *.jar ]]; then
    cp ${ADDITIONAL_LIB} ${TARGET_LIB_DIR}
    echo "Installed ${ADDITIONAL_LIB}"
  else
    echo "Skipping ${ADDITIONAL_LIB}: unknown file extension."
  fi
done
echo "Finished installation of extensions"
