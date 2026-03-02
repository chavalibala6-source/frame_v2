#!/bin/bash

mkdir -p images

for img in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep frame); do
  echo "Saving $img"
  fname=$(echo $img | tr '/:' '_')
  docker save "$img" -o "images/$fname.tar"
done

echo "Images exported to ./images"
