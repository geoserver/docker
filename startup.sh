#!/bin/sh
echo "Welcome to GeoServer $GEOSERVER_VERSION"

## Skip demo data
if [ "${SKIP_DEMO_DATA}" = "true" ]; then
  unset GEOSERVER_REQUIRE_FILE
fi

## install release data directory if needed before starting tomcat
if [ ! -z "$GEOSERVER_REQUIRE_FILE" ] && [ ! -f "$GEOSERVER_REQUIRE_FILE" ]; then
  echo "Initialize $GEOSERVER_DATA_DIR from data directory included in geoserver.war"
  cp -r $CATALINA_HOME/webapps/geoserver/data/* $GEOSERVER_DATA_DIR
fi

## install GeoServer extensions before starting the tomcat
/opt/install-extensions.sh

# copy additional geoserver libs before starting the tomcat
# we also count whether at least one file with the extensions exists
count=`ls -1 $ADDITIONAL_LIBS_DIR/*.jar 2>/dev/null | wc -l`
if [ -d "$ADDITIONAL_LIBS_DIR" ] && [ $count != 0 ]; then
    cp $ADDITIONAL_LIBS_DIR/*.jar $CATALINA_HOME/webapps/geoserver/WEB-INF/lib/
fi

# copy additional fonts before starting the tomcat
# we also count whether at least one file with the fonts exists
count=`ls -1 *.ttf 2>/dev/null | wc -l`
if [ -d "$ADDITIONAL_FONTS_DIR" ] && [ $count != 0 ]; then
    cp $ADDITIONAL_FONTS_DIR/*.ttf /usr/share/fonts/truetype/
fi

# configure CORS (inspired by https://github.com/oscarfonts/docker-geoserver)
# if enabled, this will add the filter definitions
# to the end of the web.xml
# (this will only happen if our filter has not yet been added before)
if [ "${CORS_ENABLED}" = "true" ]; then
  if ! grep -q DockerGeoServerCorsFilter "$CATALINA_HOME/webapps/geoserver/WEB-INF/web.xml"; then
    echo "Enable CORS for $CATALINA_HOME/webapps/geoserver/WEB-INF/web.xml"
    sed -i "\:</web-app>:i\\
    <filter>\n\
      <filter-name>DockerGeoServerCorsFilter</filter-name>\n\
      <filter-class>org.apache.catalina.filters.CorsFilter</filter-class>\n\
      <init-param>\n\
          <param-name>cors.allowed.origins</param-name>\n\
          <param-value>${CORS_ALLOWED_ORIGINS}</param-value>\n\
      </init-param>\n\
      <init-param>\n\
          <param-name>cors.allowed.methods</param-name>\n\
          <param-value>${CORS_ALLOWED_METHODS}</param-value>\n\
      </init-param>\n\
      <init-param>\n\
        <param-name>cors.allowed.headers</param-name>\n\
        <param-value>${CORS_ALLOWED_HEADERS}</param-value>\n\
      </init-param>\n\
    </filter>\n\
    <filter-mapping>\n\
      <filter-name>DockerGeoServerCorsFilter</filter-name>\n\
      <url-pattern>/*</url-pattern>\n\
    </filter-mapping>" "$CATALINA_HOME/webapps/geoserver/WEB-INF/web.xml";
  fi
fi

# replace the default port with the one provided by the environment variable
if [ ! -z "$TOMCAT_HTTP_PORT" ]; then
  echo "Tomcat HTTP port set to $TOMCAT_HTTP_PORT"
  sed -i "s/port=\"[0-9]\+\" protocol=\"HTTP\/1.1\"/port=\"$TOMCAT_HTTP_PORT\" protocol=\"HTTP\/1.1\"/" $CATALINA_HOME/conf/server.xml
fi

# start the tomcat
$CATALINA_HOME/bin/catalina.sh run
