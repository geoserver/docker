# A GeoServer docker image

This Dockerfile can be used to create images for all geoserver versions since 2.5.

* Based on the official [`tomcat` docker image](https://hub.docker.com/_/tomcat), in particular:
  * Tomcat 9
  * JDK11 (eclipse temurin)
  * Ubuntu Jammy (22.04 LTS)
* GeoServer installation is configurable and supports
  * Dynamic installation of extensions
  * Custom fonts (e.g. for SLD styling)
  * CORS
  * Additional libraries
  * PostgreSQL JNDI
  * HTTPS

This README.md file covers use of official docker image, additional [build](BUILD.md) and [release](RELEASE.md) instructions are available.

## How to run official release?

To pull an official image use ``docker.osgeo.org/geoserver:{{VERSION}}``, e.g.:

```shell
docker pull docker.osgeo.org/geoserver:2.25.2
```
All the images can be found at: [https://repo.osgeo.org](https://repo.osgeo.org/#browse/browse:geoserver-docker:v2/geoserver/tags) and the latest stable and maintenance version numbers can be obtained from [https://geoserver.org/download/](https://geoserver.org/download/)

Afterwards you can run the pulled image locally with:

```shell
docker run -it -p 80:8080 docker.osgeo.org/geoserver:2.25.2
```

Or if you want to start the container daemonized, use e.g.:

```shell
docker run -d -p 80:8080 docker.osgeo.org/geoserver:2.25.2
```

Check <http://localhost/geoserver> to see the geoserver page,
and login with geoserver default `admin:geoserver` credentials.

**IMPORTANT NOTE:** Please change the default ``geoserver`` and ``master`` passwords.

For more information see the user-guide [docker installation instructions](https://docs.geoserver.org/latest/en/user/installation/docker.html).

## How to mount an external folder for use as a data directory

To use an external folder as your geoserver data directory.

```shell
docker run -it -p 80:8080 \
  --mount src="/absolute/path/on/host",target=/opt/geoserver_data/,type=bind \
  docker.osgeo.org/geoserver:2.25.2
```

An empty data directory will be populated on first use. You can easily update GeoServer while
using the same data directory.

## How to start a GeoServer without sample data?

This image populates ``/opt/geoserver_data/`` with demo data by default. For production scenarios this is typically not desired.

The environment variable `SKIP_DEMO_DATA` can be set to `true` to create an empty data directory.

```shell
docker run -it -p 80:8080 \
  --env SKIP_DEMO_DATA=true \
  docker.osgeo.org/geoserver:2.25.2
```

## How to set the application context path?

By default, GeoServer is served from <http://localhost/geoserver>. Use the environment variable `WEBAPP_CONTEXT` to change the context path.

examples:

The following will serve GeoServer from the root (<http://localhost/>):
```shell
docker run -it -p 80:8080 \
  --env WEBAPP_CONTEXT="" \
  docker.osgeo.org/geoserver:2.25.1
```

The following will serve GeoServer from <http://localhost/my_context_path>:
```shell
docker run -it -p 80:8080 \
  --env WEBAPP_CONTEXT="my_context_path" \
  docker.osgeo.org/geoserver:2.25.1
```

## How to issue a redirect from the root ("/") to GeoServer web interface ("/geoserver/web")?

By default, the ROOT webapp is not available which makes requests to the root endpoint "/" return a 404 error.
The environment variable `ROOT_WEBAPP_REDIRECT` can be set to `true` to issue a permanent redirect to the web interface.

## How to download and install additional extensions on startup?

The ``startup.sh`` script allows some customization on startup:

* ``INSTALL_EXTENSIONS`` to ``true`` to download and install extensions
* ``STABLE_EXTENSIONS`` list of extensions to download and install
* ``CORS_ENABLED`` to ``true`` to enable CORS support. The following environment variables can be used to customize the CORS configuration.
  * ``CORS_ALLOWED_ORIGINS`` (default ``*``)
  * ``CORS_ALLOWED_METHODS`` (default ``GET,POST,PUT,DELETE,HEAD,OPTIONS``)
  * ``CORS_ALLOWED_HEADERS`` (default ``*``)
  * ``CORS_ALLOW_CREDENTIALS`` (default ``false``) **Setting this to ``true`` will only have the desired effect if ``CORS_ALLOWED_ORIGINS`` defines explicit origins (not ``*``)**
* ``PROXY_BASE_URL`` to the base URL of the GeoServer web app if GeoServer is behind a proxy. Example: ``https://example.com/geoserver``.

The CORS variables customize tomcat's `web.xml` file. If you need more customization,
you can provide your own customized `web.xml` file to tomcat by mounting it into the container
at `/opt/config_overrides/web.xml`.

Example installing wps and ysld extensions:

```shell
docker run -it -p 80:8080 \
  --env INSTALL_EXTENSIONS=true --env STABLE_EXTENSIONS="wps,ysld" \
  docker.osgeo.org/geoserver:2.25.2
```

The list of extensions (taken from SourceForge download page):

```shell
app-schema   gdal            jp2k          ogr-wps          web-resource
authkey      geofence        libjpeg-turbo oracle           wmts-multi-dimensional
cas          geofence-server mapml         params-extractor wps-cluster-hazelcast
charts       geopkg-output   mbstyle       printing         wps-cluster-hazelcast
control-flow grib            mongodb       pyramid          wps-download
css          gwc-s3          monitor       querylayer       wps-jdbc
csw          h2              mysql         sldservice       wps
db2          imagemap        netcdf-out    sqlserver        xslt
dxf          importer        netcdf        vectortiles      ysld
excel        inspire         ogr-wfs       wcs2_0-eo
```

## How to install additional extensions from local folder?

If you want to add geoserver extensions/libs, place the respective jar files in a directory and mount it like

```shell
docker run -it -p 80:8080 \
  --mount src="/dir/with/libs/on/host",target=/opt/additional_libs,type=bind \
  docker.osgeo.org/geoserver:2.25.2
```

## How to add additional fonts to the docker image (e.g. for SLD styling)?

If you want to add custom fonts (the base image only contains 26 fonts) by using a mount:

```shell
docker run -it -p 80:8080 \
  --mount src="/dir/with/fonts/on/host",target=/opt/additional_fonts,type=bind \
  docker.osgeo.org/geoserver:2.25.2
```

**Note:** Do not change the target value!


## How to enable a PostgreSQL JNDI resource?

To enable a PostgreSQL JNDI resource, provide the following environment variables:

* ``POSTGRES_JNDI_ENABLED`` to ``true``
* ``POSTGRES_HOST``
* ``POSTGRES_PORT`` (optional; defaults to 5432)
* ``POSTGRES_DB``
* ``POSTGRES_USERNAME``
* ``POSTGRES_PASSWORD``
* ``POSTGRES_JNDI_RESOURCE_NAME`` (optional; defaults to ``jdbc/postgres``)

In geoserver, you can then reference this JNDI resource using the name `java:comp/env/jdbc/postgres` (if using default).

## How to use custom (tomcat) configuration files

This image provides default (tomcat) configurations that are located in the `./config/` subdir.

* `context.xml` (see/compare JNDI feature from above)
* `server.xml` (security hardened version by default)

In case you want to fully overwrite such a config file, you can do so by mounting it to the `/opt/config_overrides/` directory of a container.
The `startup.sh` script will then copy (and overwrite) these files to the catalina conf directory before starting tomcat.

Example:

```shell
docker run -it -p 80:8080 \
  --mount src="/path/to/my/server.xml",target=/opt/config_overrides/server.xml,type=bind \
  docker.osgeo.org/geoserver:2.25.2
```

## How to enable HTTPS?

To enable HTTPS, mount a JKS file to the container (ex. `/opt/keystore.jks`) and provide the following environment 
variables:

* ``HTTPS_ENABLED`` to `true`
* ``HTTPS_KEYSTORE_FILE`` (defaults to `/opt/keystore.jks`)
* ``HTTPS_KEYSTORE_PASSWORD`` (defaults to `changeit`)
* ``HTTPS_KEY_ALIAS`` (defaults to `server`)

## How to use the docker-compose demo?

The ``docker-compose-demo.yml`` to build with your own data directory and extensions.

Stage geoserver data directory contents into ``geoserver_data``, and any extensions into ``additional_libs`` folder.

Run ``docker-compose``:

```shell
docker-compose -f docker-compose-demo.yml up --build
```
## Environment Variables

Following is the list of the all the environment variables that can be passed down to the geoserver docker image, you can check the default values for an image using `docker inspect [IMAGE_NAME]`
| VAR NAME | DESCRIPTION | SAMPLE VALUE |
|--------------|-----------|------------|
| PATH | Used by geoserver internally to find all the libs | `/usr/local/sbin:/usr/local/bin:` |
| CATALINA_HOME | CATALINA home path | `/usr/local/tomcat` (see also [here](https://github.com/docker-library/tomcat/blob/master/9.0/jdk11/temurin-jammy/Dockerfile)) |
| EXTRA_JAVA_OPTS | Used to pass params to the JAVA environment. Check [ref](https://docs.oracle.com/en/java/javase/11/tools/java.html) | `-Xms256m -Xmx1g` |
| CORS_ENABLED | CORS enabled configuration | `false` |
| CORS_ALLOWED_ORIGINS | CORS origins configuration | `*` |
| CORS_ALLOWED_METHODS | CORS method configuration | `GET,POST,PUT,DELETE,HEAD,OPTIONS` |
| CORS_ALLOWED_HEADERS | CORS headers configuration | `*` |
| DEBIAN_FRONTEND | Configures the Debian package manager frontend | `noninteractive`|
| CATALINA_OPTS | Catalina options. Check [ref](https://www.baeldung.com/tomcat-catalina_opts-vs-java_opts) | `-Djava.awt.headless=true` |
| GEOSERVER_DATA_DIR | Geoserver data directory location | `/opt/geoserver_data/` |
| GEOSERVER_REQUIRE_FILE | Geoserver configuration used interally | `/opt/geoserver_data/global.xml` |
| INSTALL_EXTENSIONS | Indicates whether additional GeoServer extensions should be installed | `false` |
| WAR_ZIP_URL | Specifies the URL for a GeoServer Web Archive (WAR) file | |
| STABLE_EXTENSIONS | Specifies stable GeoServer extensions | |
| STABLE_PLUGIN_URL | Specifies the URL for downloading the latest stable GeoServer plugins | `https://build.geoserver.org/geoserver/2.25.x/ext-latest` |
| COMMUNITY_EXTENSIONS | Specifies community-contributed GeoServer extensions | |
| COMMUNITY_PLUGIN_URL | Specifies the URL for downloading the latest community-contributed GeoServer plugins | `https://build.geoserver.org/geoserver/2.25.x/community-latest` |
| ADDITIONAL_LIBS_DIR | Sets the directory for additional libraries used by GeoServer | `/opt/additional_libs/` |
| ADDITIONAL_FONTS_DIR | Sets the directory for additional fonts used by GeoServer | `/opt/additional_fonts/` |
| SKIP_DEMO_DATA | Indicates whether to skip the installation of demo data provided by GeoServer | `false` |
| ROOT_WEBAPP_REDIRECT | Indicates whether to issue a permanent redirect to the web interface | `false` |
| HEALTHCHECK_URL | URL to the resource / endpoint used for `docker` health checks | `http://localhost:8080/geoserver/web/wicket/resource/org.geoserver.web.GeoServerBasePage/img/logo.png` |
| GEOSERVER_ADMIN_USER | Admin username |   |
| GEOSERVER_ADMIN_PASSWORD | Admin password |  |

The following values cannot really be safely changed (as they are used to download extensions and community modules as the docker image first starts up).
| VAR NAME | DESCRIPTION | SAMPLE VALUE |
|--------------|-----------|------------|
| GEOSERVER_VERSION | Geoserver version (used internally) | `2.24-SNAPSHOT`|
| GEOSERVER_BUILD | Geoserver build (used internally) | `1628` |

## Troubleshooting

### How to watch geoserver.log from host?

To watch ``geoserver.log`` of a running container:

```shell
docker exec -it {CONTAINER_ID} tail -f /opt/geoserver_data/logs/geoserver.log
```
