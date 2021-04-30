#!/usr/bin/env bash 

CURL=$(which curl) 
catalina.sh start
sleep 4
#$CURL --retry-delay 1 --retry 60 -X GET "http://$HOSTNAME:8080/geoserver/rest/about/manifest" -H "accept: application/json" -H "content-type: application/json"
#$CURL --retry-delay 1 --retry 60 -X GET "http://$HOSTNAME:8080/geoserver/rest/layers" -H "accept: application/json" -H "content-type: application/json"
$CURL -I -s --retry-delay 1 --retry 60 -X GET "http://$HOSTNAME:8080/geoserver/wms?service=wms&version=1.1.1&request=GetCapabilities"
