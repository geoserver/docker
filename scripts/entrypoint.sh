#!/bin/bash
## Inspired by https://github.com/kartoza/docker-geoserver
set -e

## install GeoServer extensions before starting the tomcat
echo "Starting installation of extensions"
/scripts/install-extensions.sh
echo "\nFinished installation of extensions"

export GEOSERVER_OPTS="-Djava.awt.headless=true -server \
       -Dfile.encoding=UTF8 \
       -Djavax.servlet.request.encoding=UTF-8 \
       -Djavax.servlet.response.encoding=UTF-8 \
       -Xms${INITIAL_MEMORY} -Xmx${MAXIMUM_MEMORY} \
       -XX:SoftRefLRUPolicyMSPerMB=36000 -XX:+UseG1GC \
       -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 \
       -Xbootclasspath/a:${CATALINA_HOME}/lib/marlin-${MARLIN_VERSION}-Unsafe.jar \
       -Dsun.java2d.renderer=org.marlin.pisces.MarlinRenderingEngine \
       -Dorg.geotools.coverage.jaiext.enabled=${JAIEXT_ENABLED}"

## JVM command line arguments
export JAVA_OPTS="${JAVA_OPTS} ${GEOSERVER_OPTS}"

## Start the tomcat
exec /usr/local/tomcat/bin/catalina.sh run
