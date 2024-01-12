FROM ubuntu:22.04 as tomcat

ARG TOMCAT_VERSION=9.0.84
ARG CORS_ENABLED=false
ARG CORS_ALLOWED_ORIGINS=*
ARG CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,HEAD,OPTIONS
ARG CORS_ALLOWED_HEADERS=*
ARG CORS_ALLOW_CREDENTIALS=false

# Environment variables
ENV CATALINA_HOME=/opt/apache-tomcat-${TOMCAT_VERSION}
ENV EXTRA_JAVA_OPTS="-Xms256m -Xmx1g"
ENV CORS_ENABLED=$CORS_ENABLED
ENV CORS_ALLOWED_ORIGINS=$CORS_ALLOWED_ORIGINS
ENV CORS_ALLOWED_METHODS=$CORS_ALLOWED_METHODS
ENV CORS_ALLOWED_HEADERS=$CORS_ALLOWED_HEADERS
ENV CORS_ALLOW_CREDENTIALS=$CORS_ALLOW_CREDENTIALS
ENV DEBIAN_FRONTEND=noninteractive
ENV WEBAPP_CONTEXT=geoserver

# see https://docs.geoserver.org/stable/en/user/production/container.html
ENV CATALINA_OPTS="\$EXTRA_JAVA_OPTS \
    -Djava.awt.headless=true -server \
    -Dfile.encoding=UTF-8 \
    -Djavax.servlet.request.encoding=UTF-8 \
    -Djavax.servlet.response.encoding=UTF-8 \
    -D-XX:SoftRefLRUPolicyMSPerMB=36000 \
    -Xbootclasspath/a:$CATALINA_HOME/lib/marlin.jar \
    -Dsun.java2d.renderer=sun.java2d.marlin.DMarlinRenderingEngine \
    -Dorg.geotools.coverage.jaiext.enabled=true"

# init
RUN apt update \
&& apt -y upgrade \
&& apt install -y --no-install-recommends openssl unzip gdal-bin wget curl openjdk-11-jdk gettext \
&& apt clean \
&& rm -rf /var/cache/apt/* \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /opt/

RUN wget -q https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz \
&& tar xf apache-tomcat-${TOMCAT_VERSION}.tar.gz \
&& rm apache-tomcat-${TOMCAT_VERSION}.tar.gz \
&& rm -rf /opt/apache-tomcat-${TOMCAT_VERSION}/webapps/ROOT \
&& rm -rf /opt/apache-tomcat-${TOMCAT_VERSION}/webapps/docs \
&& rm -rf /opt/apache-tomcat-${TOMCAT_VERSION}/webapps/examples

# cleanup
RUN apt purge -y  \
&& apt autoremove --purge -y \
&& rm -rf /tmp/*

FROM tomcat as download

ARG GS_VERSION=2.24.1
ARG GS_BUILD=release
ARG WAR_ZIP_URL=https://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/geoserver-${GS_VERSION}-war.zip
ENV GEOSERVER_VERSION=$GS_VERSION
ENV GEOSERVER_BUILD=$GS_BUILD

WORKDIR /tmp

RUN echo "Downloading GeoServer ${GS_VERSION} ${GS_BUILD}" \
&& wget -q -O /tmp/geoserver.zip $WAR_ZIP_URL \
&& unzip geoserver.zip geoserver.war -d /tmp/ \
&& unzip -q /tmp/geoserver.war -d /tmp/geoserver \
&& rm /tmp/geoserver.war

FROM tomcat as install

ARG GS_VERSION=2.24.1
ARG GS_BUILD=release
ARG STABLE_PLUGIN_URL=https://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/extensions
ARG COMMUNITY_PLUGIN_URL=''

ARG GS_DATA_PATH=./geoserver_data/
ARG ADDITIONAL_LIBS_PATH=./additional_libs/
ARG ADDITIONAL_FONTS_PATH=./additional_fonts/

ENV GEOSERVER_VERSION=$GS_VERSION
ENV GEOSERVER_BUILD=$GS_BUILD
ENV GEOSERVER_DATA_DIR=/opt/geoserver_data/
ENV GEOSERVER_REQUIRE_FILE=$GEOSERVER_DATA_DIR/global.xml
ENV GEOSERVER_LIB_DIR=$CATALINA_HOME/webapps/$WEBAPP_CONTEXT/WEB-INF/lib/
ENV INSTALL_EXTENSIONS=false
ENV WAR_ZIP_URL=$WAR_ZIP_URL
ENV STABLE_EXTENSIONS=''
ENV STABLE_PLUGIN_URL=$STABLE_PLUGIN_URL
ENV COMMUNITY_EXTENSIONS=''
ENV COMMUNITY_PLUGIN_URL=$COMMUNITY_PLUGIN_URL
ENV ADDITIONAL_LIBS_DIR=/opt/additional_libs/
ENV ADDITIONAL_FONTS_DIR=/opt/additional_fonts/
ENV SKIP_DEMO_DATA=false
ENV ROOT_WEBAPP_REDIRECT=false
ENV POSTGRES_JNDI_ENABLED=false
ENV CONFIG_DIR=/opt/config
ENV CONFIG_OVERRIDES_DIR=/opt/config_overrides
ENV HEALTHCHECK_URL=http://localhost:8080/$WEBAPP_CONTEXT/web/wicket/resource/org.geoserver.web.GeoServerBasePage/img/logo.png
ENV ROOT_HEALTHCHECK_URL=http://localhost:8080/web/wicket/resource/org.geoserver.web.GeoServerBasePage/img/logo.png
EXPOSE 8080

WORKDIR /tmp

RUN echo "Installing GeoServer $GS_VERSION $GS_BUILD"

COPY --from=download /tmp/geoserver $CATALINA_HOME/webapps/$WEBAPP_CONTEXT

RUN mv $CATALINA_HOME/webapps/$WEBAPP_CONTEXT/WEB-INF/lib/marlin-*.jar $CATALINA_HOME/lib/marlin.jar \
&& mkdir -p $GEOSERVER_DATA_DIR

RUN mv $CATALINA_HOME/webapps/$WEBAPP_CONTEXT/WEB-INF/lib/postgresql-*.jar $CATALINA_HOME/lib/

COPY $GS_DATA_PATH $GEOSERVER_DATA_DIR
COPY $ADDITIONAL_LIBS_PATH $GEOSERVER_LIB_DIR
COPY $ADDITIONAL_FONTS_PATH /usr/share/fonts/truetype/

# cleanup
RUN rm -rf /tmp/*

# Add default configs
ADD config $CONFIG_DIR

# copy scripts
COPY *.sh /opt/
RUN chmod +x /opt/*.sh

ENTRYPOINT ["/opt/startup.sh"]

WORKDIR /opt

HEALTHCHECK --interval=1m --timeout=20s --retries=3 \
  CMD if [ $WEBAPP_CONTEXT == "ROOT" ];then (curl --fail ROOT_HEALTHCHECK_URL || exit 1); else (curl --fail HEALTHCHECK_URL || exit 1);fi
