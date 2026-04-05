#!/bin/bash
docker run --rm -v $(pwd):/workspace debian:latest bash -c "
apt-get update && apt-get install -y curl dpkg tzdata ca-certificates
bash /workspace/src/apptainer/install.sh
"
