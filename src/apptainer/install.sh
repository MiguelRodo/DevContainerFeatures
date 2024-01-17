#!/usr/bin/env bash
# source: https://apptainer.org/docs/admin/main/installation.html
set -e
apt-get update
apt-get install -y software-properties-common
add-apt-repository -y ppa:apptainer/ppa
apt-get update
apt-get install -y apptainer
# as singularity mounts localtime
# source: https://carpentries-incubator.github.io/singularity-introduction/07-singularity-images-building/index.html#using-singularity-run-from-within-the-docker-container
apt-get install -y tzdata
cp /usr/share/zoneinfo/Europe/London /etc/localtime
