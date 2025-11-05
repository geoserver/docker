#!/bin/bash

# Configure GeoServer admin credentials
# Supports: GEOSERVER_ADMIN_USER/PASSWORD (env vars) or GEOSERVER_ADMIN_USER_FILE/PASSWORD_FILE (file paths)
# Priority: Direct env vars take precedence over files

ADMIN_USER="admin"
ADMIN_PASSWORD=""

# Resolve password from file or env var
if [ -n "$GEOSERVER_ADMIN_PASSWORD_FILE" ] && [ -f "$GEOSERVER_ADMIN_PASSWORD_FILE" ]; then
    if [ -n "$GEOSERVER_ADMIN_PASSWORD" ]; then
        echo "Warning: Both GEOSERVER_ADMIN_PASSWORD and GEOSERVER_ADMIN_PASSWORD_FILE are set. Using GEOSERVER_ADMIN_PASSWORD."
        ADMIN_PASSWORD="$GEOSERVER_ADMIN_PASSWORD"
    else
        ADMIN_PASSWORD=$(cat "$GEOSERVER_ADMIN_PASSWORD_FILE")
        echo "Loaded GeoServer admin password from file."
    fi
elif [ -n "$GEOSERVER_ADMIN_PASSWORD_FILE" ]; then
    echo "Error: GEOSERVER_ADMIN_PASSWORD_FILE is set to '$GEOSERVER_ADMIN_PASSWORD_FILE' but file does not exist or is not readable."
    exit 1
elif [ -n "$GEOSERVER_ADMIN_PASSWORD" ]; then
    echo "Using GeoServer admin password from environment variable."
    ADMIN_PASSWORD="$GEOSERVER_ADMIN_PASSWORD"
fi

# Resolve username from file or env var
if [ -n "$GEOSERVER_ADMIN_USER_FILE" ] && [ -f "$GEOSERVER_ADMIN_USER_FILE" ]; then
    if [ -n "$GEOSERVER_ADMIN_USER" ]; then
        echo "Warning: Both GEOSERVER_ADMIN_USER and GEOSERVER_ADMIN_USER_FILE are set. Using GEOSERVER_ADMIN_USER."
        ADMIN_USER="$GEOSERVER_ADMIN_USER"
    else
        ADMIN_USER=$(cat "$GEOSERVER_ADMIN_USER_FILE")
        echo "Loaded GeoServer admin user from file."
    fi
elif [ -n "$GEOSERVER_ADMIN_USER_FILE" ]; then
    echo "Error: GEOSERVER_ADMIN_USER_FILE is set to '$GEOSERVER_ADMIN_USER_FILE' but file does not exist or is not readable."
    exit 1
elif [ -n "$GEOSERVER_ADMIN_USER" ]; then
    echo "Using GeoServer admin username from environment variable."
    ADMIN_USER="$GEOSERVER_ADMIN_USER"
fi

# Update credentials if both username and password are available
if [ -n "$ADMIN_PASSWORD" ] && [ -n "$ADMIN_USER" ]; then
    echo "Updating GeoServer admin credentials..."
    /bin/sh /opt/update_credentials.sh "$ADMIN_USER" "$ADMIN_PASSWORD"
fi
