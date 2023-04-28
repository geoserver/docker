# Release Process

## How to publish official release?

OSGeo maintains geoserver-docker.osgeo.org repository for publishing. The results are combined into docker.osgeo.org repository alongside other software such as PostGIS.

Build locally:

```shell
docker build -t geoserver-docker.osgeo.org/geoserver:2.22.0 .
```

Login using with osgeo user id:

```shell
docker login geoserver-docker.osgeo.org
```

Push to osgeo repository:

```shell
docker push geoserver-docker.osgeo.org/geoserver:2.22.0
```

## How to automate release?

For CI purposes, the script in the `build` folder is used to simplify those steps.

The variables `DOCKERUSER` and `DOCKERPASSWORD` have to be set with valid credentials before this script can push the image to the osgeo repo.

You need to pass the version as first and the type as second argument, where type has to be one of `build`, `publish` or `buildandpublish`.

Examples:

`./release.sh 2.22.1 build`

`./release.sh 2.22.0 publish`

`./release.sh 2.22.1 buildandpublish`

`./release.sh 2.24-SNAPSHOT buildandpublish`
