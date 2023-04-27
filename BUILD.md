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
