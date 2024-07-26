# Build Instructions

## How to build a local image?

```shell
docker build -t {YOUR_TAG} .
```

## How to run local build?

After building run using local tag:

```shell
docker run -it -p 80:8080 {YOUR_TAG}
```

## How to build a specific GeoServer version?

```shell
docker build \
  --build-arg GS_VERSION={YOUR_VERSION} \
  -t {YOUR_TAG} .
```

## How to build with custom geoserver data directory?

```shell
docker build \
  --build-arg GS_DATA_PATH={RELATIVE_PATH_TO_YOUR_GS_DATA} \
  -t {YOUR_TAG} .
```

**Note:** The passed path **must not** be absolute! Instead, the path should be within the build context (e.g. next to the Dockerfile) and should be passed as a relative path, e.g. `GS_DATA_PATH=./my_data/`

## Can a build use a specific GeoServer version AND custom data?

Yes! Just pass the `--build-arg` param twice, e.g.

```shell
docker build \
  --build-arg GS_VERSION={VERSION} \
  --build-arg GS_DATA_PATH={PATH} \
  -t {YOUR_TAG} .
```

## How to build with additional libs/extensions/plugins?

Put your `*.jar` files (e.g. the WPS extension) in the `additional_libs` folder and build with one of the commands from above! (They will be copied to the GeoServer `WEB-INF/lib` folder during the build.)

**Note:** Similar to the GeoServer data path from above, you can also configure the path to the additional libraries by passing the `ADDITIONAL_LIBS_PATH` argument when building:

```shell
docker build \
  --build-arg ADDITIONAL_LIBS_PATH={RELATIVE_PATH_TO_YOUR_LIBS}
  -t {YOUR_TAG} .
```

## How to build from nightly snapshot releases?

By default ``WAR_ZIP_URL``, ``STABLE_PLUGIN_URL`` make use of sourceforge downloads to obtain official releases.

Override these arguments to make use of build.geoserver.org nightly releases:

* ``--build-arg WAR_ZIP_URL=https://build.geoserver.org/geoserver/${GS_VERSION}/geoserver-${GS_VERSION}-latest-war.zip``
* ``--build-arg STABLE_PLUGIN_URL=https://build.geoserver.org/geoserver/${GS_VERSION}/ext-latest/``
* ``--build-arg COMMUNITY_PLUGIN_URL=https://build.geoserver.org/geoserver/${GS_VERSION}/community-latest/``

Here is a working example for building 2.25.x nightly build::
```
docker build --no-cache-filter download,install \
  --build-arg WAR_ZIP_URL=https://build.geoserver.org/geoserver/2.25.x/geoserver-2.25.x-latest-war.zip \
  --build-arg STABLE_PLUGIN_URL=https://build.geoserver.org/geoserver/2.25.x/ext-latest/ \
  --build-arg COMMUNITY_PLUGIN_URL=https://build.geoserver.org/geoserver/2.25.x/community-latest/ \
  --build-arg GS_VERSION=2.24-SNAPSHOT \
  -t 2.25.x .
```

When running both stable extensions and community modules can be included:

```
docker run -it -p 80:8080 \
  --env INSTALL_EXTENSIONS=true \
  --env STABLE_EXTENSIONS="ysld" \
  --env COMMUNITY_EXTENSIONS="ogcapi" \
  -t 2.25.x
```

Community modules are only available for nightly builds as they have not yet met the requirements for production use. Developers have shared these to attract participation, feedback and funding.

## How to build from main snapshot releases?

The build.geoserver.org output for the ``main`` branch requires the following:

* ``--build-arg WAR_ZIP_URL=https://build.geoserver.org/geoserver/main/geoserver-main-latest-war.zip``
* ``--build-arg STABLE_PLUGIN_URL=https://build.geoserver.org/geoserver/main/ext-latest/``
* ``--build-arg COMMUNITY_PLUGIN_URL=https://build.geoserver.org/geoserver/main/community-latest/``


Here is a working example for building main branch as 2.25.x build:

```
docker build --no-cache-filter download,install \
  --build-arg WAR_ZIP_URL=https://build.geoserver.org/geoserver/main/geoserver-main-latest-war.zip \
  --build-arg STABLE_PLUGIN_URL=https://build.geoserver.org/geoserver/main/ext-latest/ \
  --build-arg COMMUNITY_PLUGIN_URL=https://build.geoserver.org/geoserver/main/community-latest/ \
  --build-arg GS_VERSION=2.24-SNAPSHOT \
  -t 2.25.x .
```

When running both [stable extensions](https://build.geoserver.org/geoserver/main/ext-latest/) and [community modules](https://build.geoserver.org/geoserver/main/community-latest/) can be included:

```
docker run -it -p 80:8080 \
  --env INSTALL_EXTENSIONS=true \
  --env STABLE_EXTENSIONS="wps,css" \
  --env COMMUNITY_EXTENSIONS="ogcapi-coverages,ogcapi-dggs,ogcapi-features,ogcapi-images,ogcapi-maps,ogcapi-styles,ogcapi-tiled-features,ogcapi-tiles" \
  -t 2.25.x
```

