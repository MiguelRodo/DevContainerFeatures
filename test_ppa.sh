#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y software-properties-common
add-apt-repository -y ppa:apptainer/ppa
apt-key adv --list-public-keys
