#!/bin/bash
# Inspired by https://github.com/kartoza/docker-geoserver

# Helper: normalize a URL by stripping any trailing slash
normalize_url() {
  echo "${1%/}"
}

# Version inference: Extract GeoServer version from plugin URLs if not explicitly set
# This handles cases where GEOSERVER_VERSION is not provided as a build arg
if [ -z "${GEOSERVER_VERSION}" ]; then
  # Try extracting version from STABLE_PLUGIN_URL (e.g., .../geoserver/2.28.x/ext-latest/ -> 2.28.x)
  if [ -n "${STABLE_PLUGIN_URL}" ]; then
    VERSION=$(echo "${STABLE_PLUGIN_URL}" | sed -n 's#.*/geoserver/\([^/]*\)/.*#\1#p')
  fi
  # Fallback to COMMUNITY_PLUGIN_URL if stable URL didn't yield a version
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
  # Escape special regex characters in extension name for safe use in sed patterns
  EXTENSION_REGEX_ESCAPED=$(printf '%s\n' "${EXTENSION}" | sed 's/[][\\.^$*+?{}|()]/\\&/g')
  DOWNLOAD_DIR="${ADDITIONAL_LIBS_DIR%/}/"
  DOWNLOAD_FILE="${DOWNLOAD_DIR}geoserver-${GEOSERVER_VERSION}-${EXTENSION}-plugin.zip"

  if [ -e "$DOWNLOAD_FILE" ]; then
      echo "$DOWNLOAD_FILE already exists. Skipping download."
  else
    # Try downloading from expected URL first
    if curl --output /dev/null --silent --head --fail "${URL}"; then
        echo -e "\nDownloading ${EXTENSION} extension from ${URL} to ${DOWNLOAD_FILE}"
        wget --progress=bar:force:noscroll --tries=3 -c "${URL}" -O "${DOWNLOAD_FILE}"
    else
        echo "URL does not exist: ${URL}"
        # Fallback: scrape directory listing to discover actual filename
        # This handles cases where version format in filename differs from expected
        BASE_URL="${URL%/geoserver-*-${EXTENSION}-plugin.zip}"
        if [ -n "${BASE_URL}" ]; then
          echo "Attempting to discover plugin filename from ${BASE_URL}/"
          LISTING=$(curl -fsS "${BASE_URL}/" 2>/dev/null || true)
          if [ -z "${LISTING}" ]; then
            echo "Unable to retrieve directory listing from ${BASE_URL}/; skipping automatic plugin discovery."
          else
            # Parse HTML to extract href matching the extension plugin pattern
            LISTING_ONE=$(echo "${LISTING}" | tr '\n' ' ')
            FILE=$(echo "${LISTING_ONE}" | sed -n 's/.*href="\([^" ]*'"${EXTENSION_REGEX_ESCAPED}"'-plugin\\.zip\)".*/\1/p' | head -n 1 || true)
            
            # Basic sanity checks before using the discovered value
            if [ -n "${FILE}" ]; then
              # Security: reject absolute URLs or paths (only accept simple filenames)
              if echo "${FILE}" | grep -qE '://' || echo "${FILE}" | grep -q '/'; then
                echo "Discovered candidate '${FILE}' is not a simple filename; skipping."
                FILE=""
              fi
            fi
            
            if [ -n "${FILE}" ]; then
              # Ensure we only have a bare filename
              FILE=$(basename "${FILE}")
              # Validate filename matches expected pattern: geoserver-<version>-<extension>-plugin.zip
              if ! echo "${FILE}" | grep -qE '^geoserver-[^-][^/]*-'"${EXTENSION_REGEX_ESCAPED}"'-plugin\.zip$'; then
                echo "Discovered candidate filename '${FILE}' does not match expected pattern; skipping."
                FILE=""
              fi
            fi
            
            if [ -n "${FILE}" ]; then
              echo "Found candidate file: ${FILE}"
              NEW_URL="${BASE_URL}/${FILE}"
              # Extract version from discovered filename if GEOSERVER_VERSION is not yet set
              VERSION=$(echo "${FILE}" | sed -n 's/^geoserver-\(.*\)-'"${EXTENSION_REGEX_ESCAPED}"'-plugin\\.zip$/\1/p')
              if [ -n "${VERSION}" ] && [ -z "${GEOSERVER_VERSION}" ]; then
                GEOSERVER_VERSION="${VERSION}"
                echo "Resolved GEOSERVER_VERSION=${GEOSERVER_VERSION} from ${FILE}"
              fi
              DOWNLOAD_FILE="${DOWNLOAD_DIR}${FILE}"
              echo -e "\nDownloading ${EXTENSION} extension from ${NEW_URL} to ${DOWNLOAD_FILE}"
              wget --progress=bar:force:noscroll --tries=3 -c "${NEW_URL}" -O "${DOWNLOAD_FILE}"
            else
              echo "No matching plugin found at ${BASE_URL}/"
            fi
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
  # Validate extension name contains only safe characters (lowercase letters, numbers, hyphens, underscores)
  if ! [[ "$EXTENSION" =~ ^[a-z0-9_-]+$ ]]; then
    echo "WARNING: Skipping invalid extension name: ${EXTENSION}" >&2
    continue
  fi
  # Find downloaded plugin (handles both expected and discovered filenames)
  ADDITIONAL_LIB=$(ls -1 "${ADDITIONAL_LIBS_DIR%/}"/geoserver-*-${EXTENSION}-plugin.zip 2>/dev/null | head -n 1 || true)
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
