ARG BUILDER_BASE_IMAGE=eclipse-temurin:17.0.15_6-jdk-jammy@sha256:d9c5400568038464d7d6cf5e6326351845becc7ac565823ebf9ab8bcffb85e74
ARG GEOSERVER_BASE_IMAGE=tomcat:9.0.107-jdk17-temurin-jammy@sha256:2a9bfa87e78e2b5bb2eeca97c0ede9ae5d4c93134b8d25d2428514348da61206

ARG GS_VERSION=2.27.0
ARG BUILD_GDAL=false
ARG PROJ_VERSION=9.5.1
ARG GDAL_VERSION=3.10.2
ARG INSTALL_PREFIX=/usr/local

# This is a multi stage build.

# The gdal_builder image/stage can be enabled by using
# `--build-arg BUILD_GDAL=true`. The gdal_builder is derived
# from the osgeo/gdal Dockerfile (small ubuntu) and simplified
# version activating the JAVA features on top.
# It builds gdal from sources, which is necessary to get
# working gdal JAVA Bindings, e.g. for the geoserver gdal extension.
# see https://trac.osgeo.org/osgeolive/ticket/2288
#
# NOTE: the build process can take up to 15 mins on average hardware!
FROM $BUILDER_BASE_IMAGE AS gdal_builder

ARG BUILD_GDAL
ARG PROJ_VERSION
ARG GDAL_VERSION
ARG INSTALL_PREFIX

ENV HOME="/root"
USER root

# Setup build env for PROJ and GDAL
RUN mkdir -p /build_projgrids/usr/ \
    mkdir -p /build${INSTALL_PREFIX}/share/proj/ \
    mkdir -p /build${INSTALL_PREFIX}/include/\
    mkdir -p /build${INSTALL_PREFIX}/bin/ \
    mkdir -p /build${INSTALL_PREFIX}/lib/ \
    mkdir -p /build/usr/share/bash-completion/ \
    mkdir -p /build/usr/share/gdal/ \
    mkdir -p /build/usr/include/ \
    mkdir -p /build_gdal_python/usr/ \
    mkdir -p /build_gdal_version_changing/usr/ \
    && if test "${BUILD_GDAL}" = "true"; then \
        apt-get update -y \
        && apt-get upgrade -y \
        && DEBIAN_FRONTEND=noninteractive apt-get install -y --fix-missing --no-install-recommends \
            # PROJ build dependencies
            build-essential ca-certificates \
            git make ninja-build cmake wget unzip libtool automake \
            zlib1g-dev libsqlite3-dev pkg-config sqlite3 libcurl4-openssl-dev \
            libtiff-dev patchelf rsync \
            # GDAL build dependencies
            python3-dev python3-numpy python3-setuptools \
            libjpeg-dev libgeos-dev \
            libexpat-dev libxerces-c-dev \
            libwebp-dev libpng-dev \
            libdeflate-dev \
            libzstd-dev bash zip curl \
            libpq-dev libssl-dev libopenjp2-7-dev \
            libspatialite-dev \
            libmuparser-dev \
            autoconf automake sqlite3 bash-completion swig ant bison; \
    fi

# Build PROJ
RUN if test "${BUILD_GDAL}" = "true"; then \
        export GCC_ARCH="$(uname -m)" \
        && mkdir -p /build_projgrids/${INSTALL_PREFIX}/share/proj \
        && curl -LO -fsS http://download.osgeo.org/proj/proj-datumgrid-latest.zip \
        && unzip -q -j -u -o proj-datumgrid-latest.zip  -d /build_projgrids/${INSTALL_PREFIX}/share/proj \
        && rm -f *.zip \
        && mkdir proj \
        && wget -q https://github.com/OSGeo/PROJ/archive/${PROJ_VERSION}.tar.gz -O - \
            | tar xz -C proj --strip-components=1 \
        && export PROJ_DB_CACHE_PARAM="" \
        && cd proj \
        && CFLAGS='-DPROJ_RENAME_SYMBOLS -O2' CXXFLAGS='-DPROJ_RENAME_SYMBOLS -DPROJ_INTERNAL_CPP_NAMESPACE -O2' \
            cmake . \
        -G Ninja \
            -DBUILD_SHARED_LIBS=ON \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
            -DBUILD_TESTING=OFF \
            $PROJ_DB_CACHE_PARAM \
        && ninja \
        && DESTDIR="/build" ninja install \
        && cd .. \
        && rm -rf proj \
        && PROJ_SO=$(readlink -f /build${INSTALL_PREFIX}/lib/libproj.so | awk 'BEGIN {FS="libproj.so."} {print $2}') \
        && PROJ_SO_FIRST=$(echo $PROJ_SO | awk 'BEGIN {FS="."} {print $1}') \
        && mv /build${INSTALL_PREFIX}/lib/libproj.so.${PROJ_SO} /build${INSTALL_PREFIX}/lib/libinternalproj.so.${PROJ_SO} \
        && ln -s libinternalproj.so.${PROJ_SO} /build${INSTALL_PREFIX}/lib/libinternalproj.so.${PROJ_SO_FIRST} \
        && ln -s libinternalproj.so.${PROJ_SO} /build${INSTALL_PREFIX}/lib/libinternalproj.so \
        && rm /build${INSTALL_PREFIX}/lib/libproj.*  \
        && ${GCC_ARCH}-linux-gnu-strip -s /build${INSTALL_PREFIX}/lib/libinternalproj.so.${PROJ_SO} \
        && for i in /build${INSTALL_PREFIX}/bin/*; do ${GCC_ARCH}-linux-gnu-strip -s $i 2>/dev/null || /bin/true; done \
        && patchelf --set-soname libinternalproj.so.${PROJ_SO_FIRST} /build${INSTALL_PREFIX}/lib/libinternalproj.so.${PROJ_SO} \
        && for i in /build${INSTALL_PREFIX}/bin/*; do patchelf --replace-needed libproj.so.${PROJ_SO_FIRST} libinternalproj.so.${PROJ_SO_FIRST} $i; done \
    fi

# Build GDAL
RUN if test "${BUILD_GDAL}" = "true"; then \
        export GCC_ARCH="$(uname -m)" \
        && if test "${GDAL_VERSION}" = "master"; then \
            export GDAL_VERSION=$(curl -Ls https://api.github.com/repos/OSGeo/gdal/commits/HEAD -H "Accept: application/vnd.github.VERSION.sha"); \
            export GDAL_RELEASE_DATE=$(date "+%Y%m%d"); \
        fi \
        && if test "${GCC_ARCH}" = "x86_64"; then \
            export GDAL_CMAKE_EXTRA_OPTS="-DENABLE_IPO=ON"; \
        else \
            export GDAL_CMAKE_EXTRA_OPTS=""; \
        fi \
        && mkdir gdal \
        && wget -q https://github.com/OSGeo/gdal/archive/v${GDAL_VERSION}.tar.gz -O - \
            | tar xz -C gdal --strip-components=1 \
        && cd gdal \
        && mkdir build \
        && cd build \
        && CFLAGS='-DPROJ_RENAME_SYMBOLS -O2' CXXFLAGS='-DPROJ_RENAME_SYMBOLS -DPROJ_INTERNAL_CPP_NAMESPACE -O2 -Wno-psabi' \
            cmake .. \
            -G Ninja \
            -DCMAKE_INSTALL_PREFIX=/usr \
            -DGDAL_FIND_PACKAGE_PROJ_MODE=MODULE \
            -DPROJ_INCLUDE_DIR="/build${INSTALL_PREFIX-/usr/local}/include" \
            -DPROJ_LIBRARY="/build${INSTALL_PREFIX-/usr/local}/lib/libinternalproj.so" \
            -DGDAL_USE_TIFF_INTERNAL=ON \
            -DGDAL_USE_GEOTIFF_INTERNAL=ON ${GDAL_CMAKE_EXTRA_OPTS} \
            -DBUILD_TESTING=OFF \
            -DBUILD_JAVA_BINDINGS=ON \
            -DGDAL_JAVA_INSTALL_DIR=${INSTALL_PREFIX-/usr/local}/lib \
            -DGDAL_JAVA_JNI_INSTALL_DIR=${INSTALL_PREFIX-/usr/local}/lib \
        && ninja \
        && DESTDIR="/build" ninja install \
        && cd .. \
        && cd .. \
        && rm -rf gdal \
        && mkdir -p /build_gdal_python/usr/lib \
        && mkdir -p /build_gdal_python/usr/bin \
        && mkdir -p /build_gdal_version_changing/usr/include \
        && mv /build/usr/lib/python*            /build_gdal_python/usr/lib \
        && mv /build/usr/lib                    /build_gdal_version_changing/usr \
        && mv /build/usr/include/gdal_version.h /build_gdal_version_changing/usr/include \
        && mv /build/usr/bin/*.py               /build_gdal_python/usr/bin \
        && mv /build/usr/bin                    /build_gdal_version_changing/usr \
        && for i in /build_gdal_version_changing/usr/lib/${GCC_ARCH}-linux-gnu/*; do ${GCC_ARCH}-linux-gnu-strip -s $i 2>/dev/null || /bin/true; done \
        && for i in /build_gdal_python/usr/lib/python3/dist-packages/osgeo/*.so; do ${GCC_ARCH}-linux-gnu-strip -s $i 2>/dev/null || /bin/true; done \
        && for i in /build_gdal_version_changing/usr/bin/*; do ${GCC_ARCH}-linux-gnu-strip -s $i 2>/dev/null || /bin/true; done \
    fi

#############################
#############################
### final GeoServer image ###
#############################
#############################
FROM $GEOSERVER_BASE_IMAGE AS geoserver
LABEL vendor="osgeo.org"

# Build arguments
ARG ADDITIONAL_FONTS_PATH=./additional_fonts/
ARG ADDITIONAL_LIBS_PATH=./additional_libs/
ARG BUILD_GDAL
ARG COMMUNITY_PLUGIN_URL=''
ARG CORS_ALLOWED_HEADERS=Origin,Accept,X-Requested-With,Content-Type,Access-Control-Request-Method,Access-Control-Request-Headers
ARG CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,HEAD,OPTIONS
ARG CORS_ALLOWED_ORIGINS=*
ARG CORS_ALLOW_CREDENTIALS=false
ARG CORS_ENABLED=false
ARG GS_VERSION
ARG GS_BUILD=release
ARG GS_DATA_PATH=./geoserver_data/
ARG INSTALL_PREFIX
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
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
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
    && apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    # Basic dependencies
    openssl curl unzip locales gettext gosu \
    && if test "${BUILD_GDAL}" = "true"; then \
        # PROJ dependencies
        apt-get install -y --no-install-recommends libsqlite3-0 libtiff5 libcurl4 ca-certificates \
        # GDAL dependencies
        bash-completion python3-numpy libpython3.11 libjpeg-turbo8 libgeos3.10.2 libgeos-c1v5 \
            libexpat1 libxerces-c3.2 libwebp7 libpng16-16 libdeflate0 libzstd1 bash libpq5 libssl3 \
            libopenjp2-7 libspatialite7 libmuparser2v5 python3-pil python-is-python3; \
    fi \
    && apt-get clean \
    && rm -rf /var/cache/apt/* \
    && rm -rf /var/lib/apt/lists/*

# install gdal (and proj)
# the source directories are empty in case of
# BUILD_GDAL=false
COPY --from=gdal_builder  /build_projgrids/usr/ /usr/

COPY --from=gdal_builder  /build${INSTALL_PREFIX}/share/proj/ ${INSTALL_PREFIX}/share/proj/
COPY --from=gdal_builder  /build${INSTALL_PREFIX}/include/ ${INSTALL_PREFIX}/include/
COPY --from=gdal_builder  /build${INSTALL_PREFIX}/bin/ ${INSTALL_PREFIX}/bin/
COPY --from=gdal_builder  /build${INSTALL_PREFIX}/lib/ ${INSTALL_PREFIX}/lib/

COPY --from=gdal_builder  /build/usr/share/bash-completion/ /usr/share/bash-completion/
COPY --from=gdal_builder  /build/usr/share/gdal/ /usr/share/gdal/
COPY --from=gdal_builder  /build/usr/include/ /usr/include/
COPY --from=gdal_builder  /build_gdal_python/usr/ /usr/
COPY --from=gdal_builder  /build_gdal_version_changing/usr/ /usr/

RUN if test "${BUILD_GDAL}" = "true"; then \
        ldconfig; \
        echo "source /usr/share/bash-completion/bash_completion" >> /root/.bashrc; \
    fi

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

ENTRYPOINT ["bash", "/opt/startup.sh"]

WORKDIR /opt

EXPOSE 8080

HEALTHCHECK --interval=1m --timeout=20s --retries=3 \
  CMD curl --fail --url "$(cat $CATALINA_HOME/conf/healthcheck_url.txt)" || exit 1
