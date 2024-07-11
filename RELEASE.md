# Release Process

## How to publish official release?

OSGeo maintains geoserver-docker.osgeo.org repository for publishing. The results are combined into docker.osgeo.org repository alongside other software such as PostGIS.

Build locally:

```shell
docker build -t geoserver-docker.osgeo.org/geoserver:2.25.2 .
```

Login using with osgeo user id:

```shell
docker login geoserver-docker.osgeo.org
```

Push to osgeo repository:

```shell
docker push geoserver-docker.osgeo.org/geoserver:2.25.2
```

## How to automate release?

For CI purposes, the script in the `build` folder is used to simplify those steps.

The variables `DOCKERUSER` and `DOCKERPASSWORD` have to be set with valid credentials before this script can push the image to the osgeo repo.

You need to pass the action as the first argument (one of `build`, `publish` or `buildandpublish`), and the version as a second argument.

The third, optional, is used to supply the jenkins build number - triggering a new war download. This is used when a release is re-published (such as with a nightly build).

Examples:

`./release.sh build 2.25.2`

`./release.sh publish 2.25.2`

`./release.sh buildandpublish 2.25.2`

`./release.sh buildandpublish 2.25-SNAPSHOT 1234`
