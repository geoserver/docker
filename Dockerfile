FROM tomcat:9-jdk11-openjdk as mother
LABEL maintainer="Alessandro Parma<alessandro.parma@geo-solutions.it>"

RUN apt-get update && apt-get install -y unzip

# accepts local files and URLs. Tar(s) are automatically extracted
WORKDIR /output/datadir
ARG GEOSERVER_DATA_DIR_SRC="./.placeholder"
ADD "${GEOSERVER_DATA_DIR_SRC}" "./"

# accepts local files and URLs. Tar(s) are automatically extracted
WORKDIR /output/webapp
ARG GEOSERVER_WEBAPP_SRC="./.placeholder"
ADD "${GEOSERVER_WEBAPP_SRC}" "./"

# zip files require explicit extracion
RUN \
    if [ "${GEOSERVER_WEBAPP_SRC##*.}" = "zip" ]; then \
        unzip "./*zip"; \
        rm ./*zip; \
    fi \
    && [ -d "./geoserver" ] || (mkdir -p ./geoserver && unzip ./geoserver.war -d ./geoserver && rm ./geoserver.war)

RUN apt-get update; apt-get upgrade --yes; apt-get install wget --yes
RUN wget https://downloads.sourceforge.net/project/libjpeg-turbo/1.5.3/libjpeg-turbo-official_1.5.3_amd64.deb && dpkg -i ./libjpeg*.deb && apt-get -f install

WORKDIR /output/plugins
ARG PLUG_IN_URLS=""
ADD .placeholder ${PLUG_IN_URLS} /output/plugins/
# RUN \
#   if [ "$(echo ${PLUG_IN_URLS}| grep http)" != "" ]; then \
#     for URL in "${PLUG_IN_URLS}"; do wget $URL;done; unzip -o "./*zip"; rm -f ./*zip; \
#   fi
RUN unzip -o "./*.zip";rm -f ./*zip

WORKDIR /output/webapp
ARG APP_LOCATION="geoserver"
RUN \
    if [ "${APP_LOCATION}" != "geoserver" ]; then \
      mv /output/webapp/geoserver /output/webapp/${APP_LOCATION}; \
    fi


FROM tomcat:9-jdk11-openjdk


ENV CATALINA_BASE "$CATALINA_HOME"
# set externalizations
ENV GEOSERVER_HOME="/var/geoserver"
ENV GEOSERVER_LOG_DIR="${GEOSERVER_HOME}/logs"
ENV GEOSERVER_DATA_DIR="${GEOSERVER_HOME}/datadir"
ENV GEOSERVER_LOG_LOCATION="${GEOSERVER_LOG_DIR}/geoserver.log"
ENV GEOWEBCACHE_CONFIG_DIR="${GEOSERVER_DATA_DIR}/gwc"
ENV GEOWEBCACHE_CACHE_DIR="${GEOSERVER_HOME}/gwc_cache_dir"
ENV NETCDF_DATA_DIR="${GEOSERVER_HOME}/netcdf_data_dir"
ENV GRIB_CACHE_DIR="${GEOSERVER_HOME}/grib_cache_dir"
# override at run time as needed JAVA_OPTS
ENV INITIAL_MEMORY="2G"
ENV MAXIMUM_MEMORY="4G"
ENV LD_LIBRARY_PATH="/opt/libjpeg-turbo/lib64"
ENV JAIEXT_ENABLED="true"

ENV GEOSERVER_OPTS=" \
  -Dorg.geotools.coverage.jaiext.enabled=${JAIEXT_ENABLED} \
  -Duser.timezone=GMT \
  -Dorg.geotools.shapefile.datetime=true \
  -DGEOSERVER_LOG_LOCATION=${GEOSERVER_LOG_LOCATION} \
  -DGEOWEBCACHE_CONFIG_DIR=${GEOWEBCACHE_CONFIG_DIR} \
  -DGEOWEBCACHE_CACHE_DIR=${GEOWEBCACHE_CACHE_DIR} \
  -DNETCDF_DATA_DIR=${NETCDF_DATA_DIR} \
  -DGRIB_CACHE_DIR=${GRIB_CACHE_DIR}"

ENV JAVA_OPTS="-Xms${INITIAL_MEMORY} -Xmx${MAXIMUM_MEMORY} \
  -Djava.awt.headless=true -server \
  -Dfile.encoding=UTF8 \
  -Djavax.servlet.request.encoding=UTF-8 \
  -Djavax.servlet.response.encoding=UTF-8 \
  -XX:SoftRefLRUPolicyMSPerMB=36000 -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 \
  ${GEOSERVER_OPTS}"

ADD run_tests.sh /docker/tests/run_tests.sh

# create externalized dirs
RUN apt-get update \
    && apt-get install --yes gdal-bin postgresql-client-11 fontconfig libfreetype6 \
    && apt-get clean \
    && apt-get autoclean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/man/* \
    && rm -rf /usr/share/doc/* \
    && mkdir -p \
    "${GEOSERVER_DATA_DIR}" \
    "${GEOSERVER_LOG_DIR}"  \
    "${GEOWEBCACHE_CONFIG_DIR}" \
    "${GEOWEBCACHE_CACHE_DIR}" \
    "${NETCDF_DATA_DIR}" \
    "${GRIB_CACHE_DIR}"

# copy from mother

COPY --from=mother "/opt/libjpeg-turbo" "/opt/libjpeg-turbo"
COPY --from=mother "/output/datadir" "${GEOSERVER_DATA_DIR}"
COPY --from=mother "/output/webapp/geoserver" "${CATALINA_BASE}/webapps/geoserver"
COPY --from=mother "/output/plugins" "${CATALINA_BASE}/webapps/geoserver/WEB-INF/lib"



WORKDIR "$CATALINA_BASE"


ENV TERM xterm
EXPOSE 8080/tcp
