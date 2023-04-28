# A geoserver docker image

This Dockerfile can be used to create images for all geoserver versions since 2.5.

* Debian based Linux
* OpenJDK 11
* Tomcat 9
* GeoServer
  * Support of custom fonts (e.g. for SLD styling)
  * CORS support
  * Support extensions
  * Support additional libraries

This README.md file covers use of official docker image, additional [build](BULD.md) and [release](RELEASE.md) instructions are available.

## How to run official release?

To pull an official image use ``docker.osgeo.org/geoserver:{{VERSION}}``, e.g.:

```shell
docker pull docker.osgeo.org/geoserver:2.23.0
```

Afterwards you can run the pulled image locally with:

```shell
docker run -it -p 80:8080 docker.osgeo.org/geoserver:2.23.0
```

Or if you want to start the container daemonized, use e.g.:

```shell
docker run -d -p 80:8080 docker.osgeo.org/geoserver:2.23.0
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
  docker.osgeo.org/geoserver:2.23.0
```

An empty data directory will be populated on first use. You can easily update GeoServer while
using the same data directory.

## How to start a GeoServer without sample data?

This image populates ``/opt/geoserver_data/`` with demo data by default. For production scenarios this is typically not desired.

The environment variable `SKIP_DEMO_DATA` can be set to `true` to create an empty data directory.

```shell
docker run -it -p 80:8080 \
  --env SKIP_DEMO_DATA=true \
  docker.osgeo.org/geoserver:2.23.0
```

## How to issue a redirect from the root ("/") to GeoServer web interface ("/geoserver/web")?

By default, the ROOT webapp is not available which makes requests to the root endpoint "/" return a 404 error.
The environment variable `ROOT_WEBAPP_REDIRECT` can be set to `true` to issue a permanent redirect to the web interface.

## How to download and install additional extensions on startup?

The ``startup.sh`` script allows some customization on startup:

* ``INSTALL_EXTENSIONS`` to ``true`` to download and install extensions
* ``STABLE_EXTENSIONS`` list of extensions to download and install
* ``CORS_ENABLED``

Example installing wps and ysld extensions:

```shell
docker run -it -p 80:8080 \
  --env INSTALL_EXTENSIONS=true --env STABLE_EXTENSIONS="wps,ysld" \
  docker.osgeo.org/geoserver:2.23.0
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
  docker.osgeo.org/geoserver:2.23.0
```

## How to add additional fonts to the docker image (e.g. for SLD styling)?

If you want to add custom fonts (the base image only contains 26 fonts) by using a mount:

```shell
docker run -it -p 80:8080 \
  --mount src="/dir/with/fonts/on/host",target=/opt/additional_fonts,type=bind \
  docker.osgeo.org/geoserver:2.23.0
```

**Note:** Do not change the target value!

## How to use the docker-compose demo?

The ``docker-compose-demo.yml`` to build with your own data directory and extensions.

Stage geoserver data directory contents into ``geoserver_data``, and any extensions into ``additional_libs`` folder.

Run ``docker-compose``:

```shell
docker-compose -f docker-compose-demo.yml up --build
```

## Troubleshooting

### How to watch geoserver.log from host?

To watch ``geoserver.log`` of a running container:

```shell
docker exec -it {CONTAINER_ID} tail -f /opt/geoserver_data/logs/geoserver.log
```
