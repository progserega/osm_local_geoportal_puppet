#!/bin/bash
dirs=`ls /var/tilecache`

for dir in $dirs
do
	path="/var/tilecache/${dir}/"
	echo "Очищаю ${path}"
	rm -rf ${path}/*
done

mkdir /var/tilecache/osm
chown www-data:www-data /var/tilecache/osm
