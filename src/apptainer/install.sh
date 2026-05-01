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
            ca-certificates \
            curl \
            gnupg \
            tzdata
        # Fetch the PPA signing key via HTTPS to avoid Launchpad API and keyserver HKP port timeouts
        KEY_FILE="$(mktemp)"
        if ! curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x6A74CF8FDE9E8436" -o "${KEY_FILE}"; then
            echo "Error: Failed to fetch apptainer PPA signing key from keyserver.ubuntu.com" >&2
            rm -f "${KEY_FILE}"
            exit 1
        fi
        gpg --dearmor < "${KEY_FILE}" > /usr/share/keyrings/apptainer-archive-keyring.gpg
        rm -f "${KEY_FILE}"
        UBUNTU_CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME}}")
        if [ -z "${UBUNTU_CODENAME}" ]; then
            echo "Error: Could not determine Ubuntu codename from /etc/os-release" >&2
            exit 1
        fi
        echo "deb [signed-by=/usr/share/keyrings/apptainer-archive-keyring.gpg] https://ppa.launchpadcontent.net/apptainer/ppa/ubuntu ${UBUNTU_CODENAME} main" \
            > /etc/apt/sources.list.d/apptainer.list
        apt-get update
        apt-get install -y apptainer
        rm -rf /var/lib/apt/lists/*
        ;;
    debian)
        apt-get update
        apt-get install -y --no-install-recommends \
            ca-certificates curl tzdata
        # Try installing apptainer from distribution repositories first (available in Debian 13+).
        # apt-get update has already been run above, so the cache is current.
        if apt-cache show apptainer >/dev/null 2>&1; then
            apt-get install -y apptainer
        else
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
            # On Debian trixie+ fuse3 bumped its soname from 3 to 4 (fuse3 >= 3.16), renaming
            # the library package from libfuse3-3 to libfuse3-4.  The upstream Apptainer .deb
            # still declares "Depends: libfuse3-3", which is unresolvable on trixie+.
            # Work-around: install equivs + fuse3, then build a tiny virtual package that
            # satisfies the declared dependency so apt can install the .deb cleanly.
            # Version 999.0.0 is intentionally high to act as an obvious compatibility shim.
            if ! apt-cache show libfuse3-3 >/dev/null 2>&1; then
                apt-get install -y --no-install-recommends equivs fuse3
                cat > /tmp/libfuse3-3-compat.control << 'EOF'
Section: libs
Priority: optional
Standards-Version: 3.9.2
Package: libfuse3-3
Version: 999.0.0
Architecture: all
Maintainer: dummy <dummy@example.com>
Provides: libfuse3-3
Depends: fuse3
Description: Dummy compatibility shim satisfying libfuse3-3 on systems that provide libfuse3-4
EOF
                (cd /tmp && equivs-build libfuse3-3-compat.control)
                SHIM_DEB="/tmp/libfuse3-3_999.0.0_all.deb"
                if [ ! -f "${SHIM_DEB}" ]; then
                    echo "Error: equivs-build did not produce expected file ${SHIM_DEB}"
                    exit 1
                fi
                dpkg -i "${SHIM_DEB}"
                rm -f "${SHIM_DEB}" /tmp/libfuse3-3-compat.control
            fi
            apt-get install -y /tmp/apptainer.deb
            rm -f /tmp/apptainer.deb
        fi
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

# 🛡️ Sentinel: Validate TIMEZONE to prevent path traversal
if echo "$TIMEZONE" | grep -Fq ".." || { echo "$TIMEZONE" | grep -Fq "/" && ! echo "$TIMEZONE" | grep -Eq '^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)+$'; }; then
    echo "Error: Invalid or dangerous TIMEZONE provided."
    exit 1
fi

# Apptainer often requires a valid /etc/localtime to mount properly
ln -fs "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
echo "${TIMEZONE}" > /etc/timezone
# Reconfigure tzdata if available (Debian/Ubuntu)
if command -v dpkg-reconfigure >/dev/null 2>&1; then
    dpkg-reconfigure -f noninteractive tzdata
fi

echo "Apptainer installation complete!"
