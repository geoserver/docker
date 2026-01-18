#!/bin/bash
# Inspired by https://github.com/kartoza/docker-geoserver

# Helper: normalize a URL by stripping any trailing slash
normalize_url() {
  echo "${1%/}"
}

# If GEOSERVER_VERSION is not set, try to infer it from the plugin URLs
# e.g. https://build.geoserver.org/geoserver/<branch>/ext-latest/ -> <branch>
if [ -z "${GEOSERVER_VERSION}" ]; then
  if [ -n "${STABLE_PLUGIN_URL}" ]; then
    VERSION=$(echo "${STABLE_PLUGIN_URL}" | sed -n 's#.*/geoserver/\([^/]*\)/.*#\1#p')
  fi
  if [ -z "${VERSION}" ] && [ -n "${COMMUNITY_PLUGIN_URL}" ]; then
    VERSION=$(echo "${COMMUNITY_PLUGIN_URL}" | sed -n 's#.*/geoserver/\([^/]*\)/.*#\1#p')
  fi
  if [ -n "${VERSION}" ]; then
    GEOSERVER_VERSION="${VERSION}"
    echo "Inferred GEOSERVER_VERSION=${GEOSERVER_VERSION} from plugin URL"
  else
    echo "Warning: GEOSERVER_VERSION is not set and could not be inferred from plugin URLs"
  fi
fi

function download_extension() {
  URL=$1
  EXTENSION=$2
  DOWNLOAD_DIR="${ADDITIONAL_LIBS_DIR%/}/"
  DOWNLOAD_FILE="${DOWNLOAD_DIR}geoserver-${GEOSERVER_VERSION}-${EXTENSION}-plugin.zip"

  if [ -e "$DOWNLOAD_FILE" ]; then
      echo "$DOWNLOAD_FILE already exists. Skipping download."
  else
    if curl --output /dev/null --silent --head --fail "${URL}"; then
        echo -e "\nDownloading ${EXTENSION} extension from ${URL} to ${DOWNLOAD_FILE}"
        wget --progress=bar:force:noscroll -c --no-check-certificate "${URL}" -O "${DOWNLOAD_FILE}"
    else
        echo "URL does not exist: ${URL}"
        # Try to discover an actual plugin file at the base URL and use it
        BASE_URL="${URL%/geoserver-*-${EXTENSION}-plugin.zip}"
        if [ -n "${BASE_URL}" ]; then
          echo "Attempting to discover plugin filename from ${BASE_URL}/"
          LISTING=$(curl -s "${BASE_URL}/" || true)
          FILE=$(echo "${LISTING}" | grep -oE "geoserver-[^/]*-${EXTENSION}-plugin.zip" | head -n 1 || true)
          if [ -n "${FILE}" ]; then
            echo "Found candidate file: ${FILE}"
            NEW_URL="${BASE_URL}/${FILE}"
            # extract version (e.g., geoserver-3.0-SNAPSHOT-authkey-plugin.zip -> 3.0-SNAPSHOT)
            VERSION=$(echo "${FILE}" | sed -n 's/^geoserver-\(.*\)-'"${EXTENSION}"'-plugin\.zip$/\1/p')
            if [ -n "${VERSION}" ]; then
              GEOSERVER_VERSION="${VERSION}"
              echo "Resolved GEOSERVER_VERSION=${GEOSERVER_VERSION} from ${FILE}"
            fi
            echo -e "\nDownloading ${EXTENSION} extension from ${NEW_URL} to ${DOWNLOAD_FILE}"
            wget --progress=bar:force:noscroll -c --no-check-certificate "${NEW_URL}" -O "${DOWNLOAD_FILE}"
          else
            echo "No matching plugin found at ${BASE_URL}/"
          fi
        fi
    fi
  fi
}

# Download stable plugins only if INSTALL_EXTENSIONS is true
if [ "$INSTALL_EXTENSIONS" = "true" ]; then
  echo "Starting download of extensions"
  if [ ! -d "$ADDITIONAL_LIBS_DIR" ]; then
    mkdir -p "$ADDITIONAL_LIBS_DIR"
  fi
  BASE_STABLE_URL=$(normalize_url "${STABLE_PLUGIN_URL}")
  BASE_COMM_URL=$(normalize_url "${COMMUNITY_PLUGIN_URL}")

  for EXTENSION in $(echo "${STABLE_EXTENSIONS}" | tr ',' ' '); do
    EXTENSION=$(echo "${EXTENSION}" | xargs)
    [ -z "$EXTENSION" ] && continue
    URL="${BASE_STABLE_URL}/geoserver-${GEOSERVER_VERSION}-${EXTENSION}-plugin.zip"
    download_extension "${URL}" "${EXTENSION}"
  done

  for EXTENSION in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
    EXTENSION=$(echo "${EXTENSION}" | xargs)
    [ -z "$EXTENSION" ] && continue
    URL="${BASE_COMM_URL}/geoserver-${GEOSERVER_VERSION}-${EXTENSION}-plugin.zip"
    download_extension "${URL}" "${EXTENSION}"
  done
  echo "Finished download of extensions"
fi

# Install the extensions
echo "Starting installation of extensions"
for EXTENSION in $(echo "${STABLE_EXTENSIONS},${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
  EXTENSION=$(echo "${EXTENSION}" | xargs)
  [ -z "$EXTENSION" ] && continue
  ADDITIONAL_LIB="${ADDITIONAL_LIBS_DIR%/}/geoserver-${GEOSERVER_VERSION}-${EXTENSION}-plugin.zip"
  [ -e "$ADDITIONAL_LIB" ] || continue

  if [[ $ADDITIONAL_LIB == *.zip ]]; then
    unzip -q -o -d "${GEOSERVER_LIB_DIR}" "${ADDITIONAL_LIB}" "*.jar"
    echo "Installed all jar files from ${ADDITIONAL_LIB}"
  elif [[ $ADDITIONAL_LIB == *.jar ]]; then
    cp "${ADDITIONAL_LIB}" "${GEOSERVER_LIB_DIR}"
    echo "Installed ${ADDITIONAL_LIB}"
  else
    echo "Skipping ${ADDITIONAL_LIB}: unknown file extension."
  fi
done
echo "Finished installation of extensions"
