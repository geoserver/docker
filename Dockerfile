FROM tomcat:9.0.100-jdk17-temurin-jammy@sha256:a0a1095732a9c66e43321b6ef5c10e72bb05fdfecfca552877bc62be88983f8e
LABEL vendor="osgeo.org"

# Build arguments
ARG ADDITIONAL_FONTS_PATH=./additional_fonts/
ARG ADDITIONAL_LIBS_PATH=./additional_libs/
ARG COMMUNITY_PLUGIN_URL=''
ARG CORS_ALLOWED_HEADERS=Origin,Accept,X-Requested-With,Content-Type,Access-Control-Request-Method,Access-Control-Request-Headers
ARG CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,HEAD,OPTIONS
ARG CORS_ALLOWED_ORIGINS=*
ARG CORS_ALLOW_CREDENTIALS=false
ARG CORS_ENABLED=false
ARG GS_BUILD=release
ARG GS_DATA_PATH=./geoserver_data/
ARG GS_VERSION=2.26.2
ARG STABLE_PLUGIN_URL=https://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/extensions
ARG WAR_ZIP_URL=https://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/geoserver-${GS_VERSION}-war.zip

# Environment variables
ENV ADDITIONAL_FONTS_DIR=/opt/additional_fonts/
ENV ADDITIONAL_LIBS_DIR=/opt/additional_libs/
ENV CATALINA_HOME=$CATALINA_HOME
ENV COMMUNITY_EXTENSIONS=''
ENV COMMUNITY_PLUGIN_URL=$COMMUNITY_PLUGIN_URL
ENV CONFIG_DIR=/opt/config
ENV CONFIG_OVERRIDES_DIR=/opt/config_overrides
ENV CORS_ALLOWED_HEADERS=$CORS_ALLOWED_HEADERS
ENV CORS_ALLOWED_METHODS=$CORS_ALLOWED_METHODS
ENV CORS_ALLOWED_ORIGINS=$CORS_ALLOWED_ORIGINS
ENV CORS_ALLOW_CREDENTIALS=$CORS_ALLOW_CREDENTIALS
ENV CORS_ENABLED=$CORS_ENABLED
ENV EXTRA_JAVA_OPTS="-Xms256m -Xmx1g"
ENV GEOSERVER_BUILD=$GS_BUILD
ENV GEOSERVER_DATA_DIR=/opt/geoserver_data/
ENV GEOSERVER_LIB_DIR=$CATALINA_HOME/webapps/geoserver/WEB-INF/lib/
ENV SET_GEOSERVER_REQUIRE_FILE=true
ENV GEOSERVER_VERSION=$GS_VERSION
ENV HEALTHCHECK_URL=''
ENV INSTALL_EXTENSIONS=false
ENV POSTGRES_JNDI_ENABLED=false
ENV ROOT_WEBAPP_REDIRECT=false
ENV RUN_UNPRIVILEGED=false
ENV RUN_WITH_USER_UID=
ENV RUN_WITH_USER_GID=
ENV CHANGE_OWNERSHIP_ON_FOLDERS="/opt $GEOSERVER_DATA_DIR"
ENV SKIP_DEMO_DATA=false
ENV STABLE_EXTENSIONS=''
ENV STABLE_PLUGIN_URL=$STABLE_PLUGIN_URL
ENV WAR_ZIP_URL=$WAR_ZIP_URL
ENV WEBAPP_CONTEXT=geoserver

# ENV JDK_JAVA_OPTIONS=--add-exports=java.desktop/sun.awt.image=ALL-UNNAMED \
#    --add-opens=java.base/java.lang=ALL-UNNAMED \
#    --add-opens=java.base/java.util=ALL-UNNAMED \
#    --add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
#    --add-opens=java.base/java.text=ALL-UNNAMED \
#    --add-opens=java.desktop/java.awt.font=ALL-UNNAMED \
#    --add-opens=java.desktop/sun.awt.image=ALL-UNNAMED \
#    --add-opens=java.naming/com.sun.jndi.ldap=ALL-UNNAMED \
#    --add-opens=java.desktop/sun.java2d.pipe=ALL-UNNAMED

# see https://docs.geoserver.org/stable/en/user/production/container.html
ENV CATALINA_OPTS="\$EXTRA_JAVA_OPTS \
    --add-exports=java.desktop/sun.awt.image=ALL-UNNAMED \
    --add-opens=java.base/java.lang=ALL-UNNAMED \
    --add-opens=java.base/java.util=ALL-UNNAMED \
    --add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
    --add-opens=java.base/java.text=ALL-UNNAMED \
    --add-opens=java.desktop/java.awt.font=ALL-UNNAMED \
    --add-opens=java.desktop/sun.awt.image=ALL-UNNAMED \
    --add-opens=java.naming/com.sun.jndi.ldap=ALL-UNNAMED \
    --add-opens=java.desktop/sun.java2d.pipe=ALL-UNNAMED \
    -Djava.awt.headless=true -server \
    -Dfile.encoding=UTF-8 \
    -Djavax.servlet.request.encoding=UTF-8 \
    -Djavax.servlet.response.encoding=UTF-8 \
    -D-XX:SoftRefLRUPolicyMSPerMB=36000 \
    -Xbootclasspath/a:$CATALINA_HOME/lib/marlin.jar \
    -Dsun.java2d.renderer=sun.java2d.marlin.DMarlinRenderingEngine \
    -Dorg.geotools.coverage.jaiext.enabled=true"

WORKDIR /tmp

# Install dependencies
RUN set -eux \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends openssl unzip curl locales gettext gosu \
    && apt-get clean \
    && rm -rf /var/cache/apt/* \
    && rm -rf /var/lib/apt/lists/*

# Download geoserver
RUN set -eux \
    && echo "Downloading GeoServer ${GS_VERSION} ${GS_BUILD}" \
    && wget -q -O /tmp/geoserver.zip $WAR_ZIP_URL \
    && unzip geoserver.zip geoserver.war -d /tmp/ \
    && unzip -q /tmp/geoserver.war -d /tmp/geoserver \
    && rm /tmp/geoserver.war \
    && rm geoserver.zip \
    && echo "Installing GeoServer $GS_VERSION $GS_BUILD" \
    && mv /tmp/geoserver $CATALINA_HOME/webapps/geoserver \
    && mv $CATALINA_HOME/webapps/geoserver/WEB-INF/lib/marlin-*.jar $CATALINA_HOME/lib/marlin.jar \
    && mv $CATALINA_HOME/webapps/geoserver/WEB-INF/lib/postgresql-*.jar $CATALINA_HOME/lib/ \
    && mkdir -p $GEOSERVER_DATA_DIR

# Copy data and additional libs / fonts
COPY $GS_DATA_PATH $GEOSERVER_DATA_DIR
COPY $ADDITIONAL_LIBS_PATH $GEOSERVER_LIB_DIR
COPY $ADDITIONAL_FONTS_PATH /usr/share/fonts/truetype/

# Add default configs
COPY config $CONFIG_DIR

# Apply CIS Apache tomcat recommendations regarding server information
# * Alter the advertised server.info String (2.1 - 2.3)
RUN cd $CATALINA_HOME/lib \
    && jar xf catalina.jar org/apache/catalina/util/ServerInfo.properties \
    && sed -i 's/Apache Tomcat\/'"${TOMCAT_VERSION}"'/i_am_a_teapot/g' org/apache/catalina/util/ServerInfo.properties \
    && sed -i 's/'"${TOMCAT_VERSION}"'/x.y.z/g' org/apache/catalina/util/ServerInfo.properties \
    && sed -i 's/^server.built=.*/server.built=/g' org/apache/catalina/util/ServerInfo.properties \
    && jar uf catalina.jar org/apache/catalina/util/ServerInfo.properties \
    && rm -rf org/apache/catalina/util/ServerInfo.properties

# copy scripts
COPY *.sh /opt/

# CIS Docker benchmark: Remove setuid and setgid permissions in the images to prevent privilege escalation attacks within containers.
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

# cleanup
RUN apt purge -y  \
  && apt autoremove --purge -y \
  && rm -rf /tmp/ \
  && rm -rf $CATALINA_HOME/webapps/ROOT \
  && rm -rf $CATALINA_HOME/webapps/docs \
  && rm -rf $CATALINA_HOME/webapps/examples \
  && rm -rf $CATALINA_HOME/webapps/host-manager \
  && rm -rf $CATALINA_HOME/webapps/manager

# GeoServer user => restrict access to $CATALINA_HOME and GeoServer directories
# See also CIS Docker benchmark and docker best practices

RUN chmod +x /opt/*.sh && sed -i 's/\r$//' /opt/startup.sh

# # Create a non-privileged tomcat user
# ARG USER_GID=999
# ARG USER_UID=999
# RUN addgroup --gid ${USER_GID} tomcat && \
#     adduser --system  -u ${USER_UID} --gid ${USER_GID} --no-create-home tomcat && \
#     chown -R tomcat:tomcat /opt && \
#     chown tomcat:tomcat $GEOSERVER_DATA_DIR

ENTRYPOINT ["bash", "/opt/startup.sh"]

WORKDIR /opt

EXPOSE 8080

HEALTHCHECK --interval=1m --timeout=20s --retries=3 \
  CMD curl --fail --url "$(cat $CATALINA_HOME/conf/healthcheck_url.txt)" || exit 1
