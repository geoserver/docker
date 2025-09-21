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

Here is a working example for building 2.27.x nightly build::
```
docker build --no-cache-filter download,install \
  --build-arg WAR_ZIP_URL=https://build.geoserver.org/geoserver/2.27.x/geoserver-2.27.x-latest-war.zip \
  --build-arg STABLE_PLUGIN_URL=https://build.geoserver.org/geoserver/2.27.x/ext-latest/ \
  --build-arg COMMUNITY_PLUGIN_URL=https://build.geoserver.org/geoserver/2.27.x/community-latest/ \
  --build-arg GS_VERSION=2.27-SNAPSHOT \
  -t 2.27.x .
```

When running both stable extensions and community modules can be included:

```
docker run -it -p 80:8080 \
  --env INSTALL_EXTENSIONS=true \
  --env STABLE_EXTENSIONS="ysld" \
  --env COMMUNITY_EXTENSIONS="ogcapi" \
  -t 2.27.x
```

Community modules are only available for nightly builds as they have not yet met the requirements for production use. Developers have shared these to attract participation, feedback and funding.

## How to build from main snapshot releases?

The build.geoserver.org output for the ``main`` branch requires the following:

* ``--build-arg WAR_ZIP_URL=https://build.geoserver.org/geoserver/main/geoserver-main-latest-war.zip``
* ``--build-arg STABLE_PLUGIN_URL=https://build.geoserver.org/geoserver/main/ext-latest/``
* ``--build-arg COMMUNITY_PLUGIN_URL=https://build.geoserver.org/geoserver/main/community-latest/``


Here is a working example for building main branch as 2.27.x build:

```
docker build --no-cache-filter download,install \
  --build-arg WAR_ZIP_URL=https://build.geoserver.org/geoserver/main/geoserver-main-latest-war.zip \
  --build-arg STABLE_PLUGIN_URL=https://build.geoserver.org/geoserver/main/ext-latest/ \
  --build-arg COMMUNITY_PLUGIN_URL=https://build.geoserver.org/geoserver/main/community-latest/ \
  --build-arg GS_VERSION=2.27-SNAPSHOT \
  -t 2.27.x .
```

When running both [stable extensions](https://build.geoserver.org/geoserver/main/ext-latest/) and [community modules](https://build.geoserver.org/geoserver/main/community-latest/) can be included:

```
docker run -it -p 80:8080 \
  --env INSTALL_EXTENSIONS=true \
  --env STABLE_EXTENSIONS="wps,css" \
  --env COMMUNITY_EXTENSIONS="ogcapi-coverages,ogcapi-dggs,ogcapi-features,ogcapi-images,ogcapi-maps,ogcapi-styles,ogcapi-tiled-features,ogcapi-tiles" \
  -t 2.27.x
```

## How to build from your own development releases?

Instead of downloading from sourceforge or build.geoserver.org, you need to package your WAR file locally.  Follow the [Building guide](https://docs.geoserver.org/latest/en/developer/maven-guide/index.html#building) for extra details.

```
git clone git://github.com/geoserver/geoserver.git geoserver
cd geoserver/src
# edit files as needed
mvn clean install -P release -DskipTests
```
which results in a WAR file located at: `src/web/app/target/geoserver.war`

First zip up the WAR file: `zip src/web/app/target/geoserver.war geoserver.zip`
and host a temporary webserver e.g.
```
python3 -m http.server 8000
```
then build the docker image, pulling from your locally hosted WAR file, and extensions as needed:
```
docker build \
  --build-arg WAR_ZIP_URL=http://host.docker.internal:8000/geoserver.zip \
  --build-arg STABLE_PLUGIN_URL=https://downloads.sourceforge.net/project/geoserver/GeoServer/2.27.2/extensions \
  --build-arg COMMUNITY_PLUGIN_URL=https://build.geoserver.org/geoserver/2.27.x/community-latest/ \
  --build-arg GS_VERSION=2.27-SNAPSHOT \
  -t my-2.27.x .
```

**Note:** For Linux only (not macOS nor Windows): you possibly need to add `--add-host=host.docker.internal:host-gateway` to the docker build command above.

Run as usual:
```
docker run -it -p 80:8080 \
  --env INSTALL_EXTENSIONS=true \
  --env STABLE_EXTENSIONS="ysld" \
  --env COMMUNITY_EXTENSIONS="ogcapi" \
  -t my-2.27.x
```