#!/bin/bash

# Credits to https://github.com/meggsimum/geoserver-docker/ and https://github.com/kartoza/docker-geoserver

echo "Updating GeoServer Credentials ..."

if [ ${DEBUG} ]; then
  set -e
  set -x
fi;

# copy over default security folder to data dir (if not existing)
if [ ! -d "${GEOSERVER_DATA_DIR}/security" ]; then
  cp -r "${CATALINA_HOME}/webapps/geoserver/data/security" "${GEOSERVER_DATA_DIR}/"
fi

GEOSERVER_ADMIN_USER=${GEOSERVER_ADMIN_USER:-admin}
GEOSERVER_ADMIN_PASSWORD=${GEOSERVER_ADMIN_PASSWORD:-geoserver}

# templates to use as base for replacement
USERS_XML_ORIG="${CATALINA_HOME}/webapps/geoserver/data/security/usergroup/default/users.xml"
echo "USING USERS XML ORIGINAL:" $USERS_XML_ORIG
ROLES_XML_ORIG="${CATALINA_HOME}/webapps/geoserver/data/security/role/default/roles.xml"
echo "USING ROLES XML ORIGINAL:" $ROLES_XML_ORIG

# final users.xml file GeoServer data dir
USERS_XML=${USERS_XML:-"${GEOSERVER_DATA_DIR}/security/usergroup/default/users.xml"}
echo "SETTING USERS XML:" $USERS_XML
# final roles.xml file GeoServer data dir
ROLES_XML=${ROLES_XML:-"${GEOSERVER_DATA_DIR}/security/role/default/roles.xml"}
echo "SETTING ROLES XML:" . $ROLES_XML

CLASSPATH="$CATALINA_HOME/webapps/geoserver/WEB-INF/lib/"

# tmp files
TMP_USERS=/tmp/users.xml
TMP_ROLES=/tmp/roles.xml

make_hash(){
  NEW_PASSWORD=$1
  (echo "digest1:" && java -classpath $(find $CLASSPATH -regex ".*jasypt-[0-9]\.[0-9]\.[0-9].*jar") org.jasypt.intf.cli.JasyptStringDigestCLI digest.sh algorithm=SHA-256 saltSizeBytes=16 iterations=100000 input="$NEW_PASSWORD" verbose=0) | tr -d '\n'
}

# create PW hash for given password
PWD_HASH=$(make_hash $GEOSERVER_ADMIN_PASSWORD)

# USERS.XML SETUP
# <user enabled="true" name="admin" password="digest1:D9miJH/hVgfxZJscMafEtbtliG0ROxhLfsznyWfG38X2pda2JOSV4POi55PQI4tw"/>
cat $USERS_XML_ORIG | sed -e "s/ name=\".*\" / name=\"${GEOSERVER_ADMIN_USER}\" /" | sed -e "s|password=\".*\"/|password=\"${PWD_HASH}\"\/|" > $TMP_USERS
if [ $? -eq 0 ]
then
    mv $TMP_USERS $USERS_XML
    echo "Successfully replaced $USERS_XML"
else
    echo "CAUTION: Abort update_credentials.sh due to error while creating users.xml. File at $USERS_XML keeps untouched"
    exit
fi

# ROLES.XML SETUP
# <userRoles username="admin">
cat $ROLES_XML_ORIG | sed -e "s/ username=\".*\"/ username=\"${GEOSERVER_ADMIN_USER}\"/" > $TMP_ROLES
if [ $? -eq 0 ]
then
    mv $TMP_ROLES $ROLES_XML
    echo "Successfully replaced $ROLES_XML"
else
    echo "CAUTION: Abort update_credentials.sh due to error while creating roles.xml. File at $ROLES_XML keeps untouched"
    exit
fi

echo "... DONE updating GeoServer Credentials ..."
