#!/bin/bash
# Inspired by https://github.com/kartoza/docker-geoserver

function download_extension() {
  URL=$1
  EXTENSION=$2
  if curl --output /dev/null --silent --head --fail "${URL}"; then
      DOWNLOAD_FILE="${EXTENSION_DOWNLOAD_DIR}/geoserver-${GS_VERSION}-${EXTENSION}-plugin.zip"
      echo -e "\nDownloading ${EXTENSION}-extension from ${URL}"
      wget --progress=bar:force:noscroll -c --no-chec k-certificate "${URL}" -O ${DOWNLOAD_FILE}
      unzip -q -o ${DOWNLOAD_FILE} -d ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib
    else
      echo "URL does not exist: ${URL}"
  fi
}

# Install stable plugins
for EXTENSION in $(echo "${STABLE_EXTENSIONS}" | tr ',' ' '); do
  URL="${STABLE_PLUGIN_URL}/geoserver-${GS_VERSION}-${EXTENSION}-plugin.zip"
  download_extension ${URL} ${EXTENSION}
done
