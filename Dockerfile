ARG TOMCAT_VERSION=9.0.38
ARG JAVA_VERSION=8
ARG IMAGE_VERSION=${TOMCAT_VERSION}-jdk${JAVA_VERSION}-openjdk-slim

FROM tomcat:$IMAGE_VERSION

ARG GS_VERSION=2.18.0
ARG MARLIN_TAG=0_9_4_3
ARG MARLIN_VERSION=0.9.4.3

ARG WAR_URL=https://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/geoserver-${GS_VERSION}-war.zip
ARG STABLE_PLUGIN_URL=https://sourceforge.net/projects/geoserver/files/GeoServer/${GS_VERSION}/extensions

# environment variables
ENV GS_VERSION=${GS_VERSION} \
    MARLIN_TAG=${MARLIN_TAG} \
    MARLIN_VERSION=${MARLIN_VERSION} \
    WAR_URL=${WAR_URL} \
    STABLE_PLUGIN_URL=${STABLE_PLUGIN_URL} \
    INITIAL_MEMORY="2G" \
    MAXIMUM_MEMORY="4G" \
    JAIEXT_ENABLED=true \
    STABLE_EXTENSIONS='' \
#    COMMUNITY_EXTENSIONS='' \
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

# install marlin renderer
RUN wget --progress=bar:force:noscroll -c --no-check-certificate https://github.com/bourgesl/marlin-renderer/releases/download/v${MARLIN_TAG}/marlin-${MARLIN_VERSION}-Unsafe.jar -O ${CATALINA_HOME}/lib/marlin-${MARLIN_VERSION}-Unsafe.jar

# copy scripts
COPY scripts /scripts
RUN chmod +x /scripts/*.sh

# cleanup
RUN apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR ${CATALINA_HOME}

CMD ["/bin/sh", "/scripts/entrypoint.sh"]
