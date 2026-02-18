#!/usr/bin/env bash
set -e

TIMEZONE="${TIMEZONE:-"UTC"}"

# Ensure we are running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Clean up apt cache at the end
cleanup() {
    rm -rf /var/lib/apt/lists/*
}
trap cleanup EXIT

echo "Installing Apptainer..."

apt-get update
apt-get install -y --no-install-recommends \
    software-properties-common \
    ca-certificates \
    tzdata

# Add PPA for Apptainer
add-apt-repository -y ppa:apptainer/ppa
apt-get update
apt-get install -y apptainer

echo "Configuring timezone to ${TIMEZONE}..."
# Apptainer often requires a valid /etc/localtime to mount properly
ln -fs "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

echo "Apptainer installation complete!"
