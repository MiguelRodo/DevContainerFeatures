#!/usr/bin/env bash
set -e

TIMEZONE="${TIMEZONE:-"UTC"}"

# Ensure we are running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
else
    OS_ID="unknown"
fi

echo "Detected OS: $OS_ID"
echo "Installing Apptainer..."

case "$OS_ID" in
    ubuntu)
        apt-get update
        apt-get install -y --no-install-recommends \
            software-properties-common \
            ca-certificates \
            tzdata
        add-apt-repository -y ppa:apptainer/ppa
        apt-get update
        apt-get install -y apptainer
        rm -rf /var/lib/apt/lists/*
        ;;
    debian)
        apt-get update
        apt-get install -y --no-install-recommends \
            ca-certificates curl tzdata
        ARCH=$(dpkg --print-architecture)
        APPTAINER_VERSION=$(curl -s https://api.github.com/repos/apptainer/apptainer/releases/latest \
            | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
        if [ -z "$APPTAINER_VERSION" ]; then
            echo "Error: Could not determine latest Apptainer version from GitHub API."
            exit 1
        fi
        echo "Downloading Apptainer ${APPTAINER_VERSION} for ${ARCH}..."
        curl -L -o /tmp/apptainer.deb \
            "https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/apptainer_${APPTAINER_VERSION}_${ARCH}.deb"
        dpkg -i /tmp/apptainer.deb || apt-get install -f -y
        rm -f /tmp/apptainer.deb
        rm -rf /var/lib/apt/lists/*
        ;;
    fedora)
        dnf install -y apptainer tzdata
        dnf clean all
        ;;
    centos|rhel|rocky|almalinux)
        yum install -y epel-release
        yum install -y apptainer tzdata
        yum clean all
        ;;
    opensuse*|sles)
        zypper install -y apptainer timezone
        zypper clean
        ;;
    *)
        echo "Error: Unsupported OS '$OS_ID' for Apptainer installation."
        echo "Supported: ubuntu, debian, fedora, centos, rhel, rocky, almalinux, opensuse, sles"
        exit 1
        ;;
esac

echo "Configuring timezone to ${TIMEZONE}..."
# Apptainer often requires a valid /etc/localtime to mount properly
ln -fs "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
echo "${TIMEZONE}" > /etc/timezone
# Reconfigure tzdata if available (Debian/Ubuntu)
if command -v dpkg-reconfigure >/dev/null 2>&1; then
    dpkg-reconfigure -f noninteractive tzdata
fi

echo "Apptainer installation complete!"
