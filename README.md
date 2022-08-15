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

## How to Use

### How to run official release?

Pull an official image use ``docker.osgeo.org/{{VERSION}}``:

```
docker pull docker.osgeo.org/geoserver:2.21.1
docker run -it -p 80:8080 docker.osgeo.org/geoserver:2.21.1
```

or if you want to start the container daemonized:

```
docker run -d -p 80:8080 docker.osgeo.org/geoserver:2.21.1
```

Check http://localhost/geoserver to see the geoserver page,
and login with geoserver default `admin:geoserver` credentials.

**IMPORTANT NOTE:** Please change the default ``geoserver`` and ``master`` passwords.

For more information see the user-guide [docker installation instructions](https://docs.geoserver.org/latest/en/user/installation/docker).

### How to download and install additional extensions on startup?

The ``startup.sh`` script allows some customization on startup:

* ``INSTALL_EXTENSIONS`` to ``true`` to download and install extensions
* ``STABLE_EXTENSIONS`` list of extensions to download and install
* ``CORS_ENABLED`` 

Example installing wps and ysld extensions:

```
docker run -it -p 80:8080 \
  --env INSTALL_EXTENSIONS=true --env STABLE_EXTENSIONS="wps,ysld" \
  docker.osgeo.org/geoserver:2.21.1 
```

The list of extensions (taken from SourceForge download page):

```
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

### How to install additional extensions from local folder?

If you want to add geoserver extensions/libs by using a mount, you can add something like

```
docker run -it -p 80:8080 \
  --mount src="/dir/with/libs/on/host",target=/opt/additional_libs,type=bind \
  docker.osgeo.org/geoserver:2.21.1 
```

### How to add additional fonts to the docker image (e.g. for SLD styling)?

If you want to add custom fonts (the base image only contains 26 fonts) by using a mount:

```
docker run -it -p 80:8080 \
  --mount src="/dir/with/fonts/on/host",target=/opt/additional_fonts,type=bind \
  docker.osgeo.org/geoserver:2.21.1
```

**Note:** Do not change the target value!

## Troubleshooting

### How to watch geoserver.log from host?

To watch ``geoserver.log`` of a running container:

```
docker exec -it {CONTAINER_ID} tail -f /opt/geoserver_data/logs/geoserver.log
```

### How to use the docker-compose demo?

The ``docker-compose-demo.yml`` to build with your own data directory and extensions.

Stage geoserver data directory contents into ``geoserver_data``, and any extensions into ``additional_libs`` folder.

Run ``docker-compose``:

```
docker-compose -f docker-compose-demo.yml up --build
```

## How to Build?


### How to build a local image?

```
docker build -t {YOUR_TAG} .
```

### How to run local build?

After building run using local tag:

```
docker run -it -p 80:8080 {YOUR_TAG}
```

### How to build a specific GeoServer version?

```
docker build \
  --build-arg GS_VERSION={YOUR_VERSION} \
  -t {YOUR_TAG} .
```

### How to build with custom geoserver data directory?

```
docker build \
  --build-arg GS_DATA_PATH={RELATIVE_PATH_TO_YOUR_GS_DATA} \
  -t {YOUR_TAG} .
```

**Note:** The passed path **must not** be absolute! Instead, the path should be within the build context (e.g. next to the Dockerfile) and should be passed as a relative path, e.g. `GS_DATA_PATH=./my_data/`

### Can a build use a specific GeoServer version AND custom data?

Yes! Just pass the `--build-arg` param twice, e.g.

```
docker build \
  --build-arg GS_VERSION={VERSION} \
  --build-arg GS_DATA_PATH={PATH} \
  -t {YOUR_TAG} .
```

### How to build with additional libs/extensions/plugins?

Put your `*.jar` files (e.g. the WPS extension) in the `additional_libs` folder and build with one of the commands from above! (They will be copied to the GeoServer `WEB-INF/lib` folder during the build.)

**Note:** Similar to the GeoServer data path from above, you can also configure the path to the additional libraries by passing the `ADDITIONAL_LIBS_PATH` argument when building:

```
docker build \
  --build-arg ADDITIONAL_LIBS_PATH={RELATIVE_PATH_TO_YOUR_LIBS}
  -t {YOUR_TAG} .
```