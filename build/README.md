# Release Process

## How to publish official release?

OSGeo maintains geoserver-docker.osgeo.org repository for publishing. The results are combined into docker.osgeo.org repository alongside other software such as PostGIS.

Build locally:

```shell
docker build -t geoserver-docker.osgeo.org/geoserver:2.27.2 .
```

Login using with osgeo user id:

```shell
docker login geoserver-docker.osgeo.org
```

Push to osgeo repository:

```shell
docker push geoserver-docker.osgeo.org/geoserver:2.27.2
```

## How to automate release?

For CI purposes, scripts in the `build` folder are used to simplify the above steps.

1. The variables `DOCKERUSER` and `DOCKERPASSWORD` have to be set with valid credentials before this script can push the image to the osgeo repo.

2. Optional, pre-download geoserver, so that both normal and gdal builds do not duplicate effort.
   
   ```bash
   ./download.sh 3.0-SNAPSHOT clean
   ```
   
   The first argument is the version number to release.
   
   The third argument, optional, is `clean` if you wish to remove any prior download.
   This is useful when downloading SNAPSHOTs where the same filename is used, and thus
   resuming a download is problematic.
   
3. The release script builds both a normal build and a gdal build:
   
   ```bash 
   ./release.sh buildandpublish 3.0-SNAPSHOT 1234
   ```
   
   The script action is the first argument (one of `build`, `publish` or `buildandpublish`).
   
   The second argument is the version to release.

   The third, optional, is used to supply the jenkins build number - triggering a new war download.
   This is used when a release is re-published (such as with a nightly build).

## Examples

`./release.sh build 2.28.2`

`./release.sh publish 2.28.2`

`./release.sh buildandpublish 2.28.2`

`./release.sh buildandpublish 2.28-SNAPSHOT 1234`
