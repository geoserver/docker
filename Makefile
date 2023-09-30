include .env

IMAGE_NAME=geoserver-docker.osgeo.org/geoserver

docker:
	docker build --build-arg CORS_ALLOWED_METHODS=GET,POST,PUT,HEAD,OPTIONS --build-arg CORS_ENABLED=true --build-arg GS_VERSION=$(GS_VERSION) --build-arg TOMCAT_VERSION=$(TOMCAT_VERSION) --pull -t $(IMAGE_NAME):$(IMAGE_VERSION) .
	docker tag $(IMAGE_NAME):$(IMAGE_VERSION) $(IMAGE_NAME):latest
push:
	docker push $(IMAGE_NAME):$(IMAGE_VERSION)
	docker push $(IMAGE_NAME):latest

