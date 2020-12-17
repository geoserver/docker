FROM tomcat:jdk11-openjdk-slim

ARG GS_VERSION=2.18.1

ARG WAR_URL=https://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/geoserver-${GS_VERSION}-war.zip
ARG STABLE_PLUGIN_URL=https://sourceforge.net/projects/geoserver/files/GeoServer/${GS_VERSION}/extensions

# environment variables
ENV GS_VERSION=${GS_VERSION} \
    WAR_URL=${WAR_URL} \
    STABLE_PLUGIN_URL=${STABLE_PLUGIN_URL} \
    INITIAL_MEMORY="2G" \
    MAXIMUM_MEMORY="4G" \
    JAIEXT_ENABLED=true \
    DOWNLOAD_EXTENSIONS=false \
    STABLE_EXTENSIONS='' \
    DEBIAN_FRONTEND=noninteractive \
    EXTENSION_DOWNLOAD_DIR=/opt/geoserver_extension_downloads \
    GEOSERVER_DATA_DIR=/opt/geoserver_data \
    GEOWEBCACHE_CACHE_DIR=/opt/geowebcache_data

RUN mkdir ${EXTENSION_DOWNLOAD_DIR} ${GEOSERVER_DATA_DIR} ${GEOWEBCACHE_CACHE_DIR}

# install required dependencies
# also clear the initial webapps
RUN apt update && \
    apt install -y curl wget openssl zip fontconfig libfreetype6 && \
    rm -rf ${CATALINA_HOME}/webapps/*

# install geoserver
RUN wget --progress=bar:force:noscroll -c --no-check-certificate "${WAR_URL}" -O /tmp/geoserver.zip && \
    unzip /tmp/geoserver.zip geoserver.war -d ${CATALINA_HOME}/webapps && \
    mkdir -p ${CATALINA_HOME}/webapps/geoserver && \
    unzip -q ${CATALINA_HOME}/webapps/geoserver.war -d ${CATALINA_HOME}/webapps/geoserver && \
    rm ${CATALINA_HOME}/webapps/geoserver.war

# copy scripts
COPY scripts /scripts
RUN chmod +x /scripts/*.sh

# cleanup
RUN apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR ${CATALINA_HOME}

CMD ["/bin/sh", "/scripts/entrypoint.sh"]
