#!/usr/bin/env bash
# Install CmdStan – the Stan probabilistic programming system CLI.
#
# Key design goal: the installation must survive the Docker image build process.
# We therefore:
#   1. Extract CmdStan to a *system-wide* directory (/opt/cmdstan by default),
#      not to a user home directory that may be overwritten on container rebuild.
#   2. Export the CMDSTAN environment variable via /etc/profile.d/cmdstan.sh so
#      that it is available in every shell session baked into the image.
#   3. Pre-compile the Stan C++ toolchain objects during the build (make build)
#      so that downstream Stan programs compile as fast as possible at runtime.
#   4. Optionally install the cmdstanr R package and point it at the system
#      installation via the R_CMDSTAN environment variable.

set -e

CMDSTAN_VERSION="${VERSION:-"latest"}"
INSTALL_DIR="${INSTALLDIR:-"/opt/cmdstan"}"
INSTALL_R_PACKAGE="${INSTALLRPACKAGE:-"true"}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Must run as root
if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root.' >&2
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

# Cleanup on exit
WORK_DIR="/tmp/cmdstan-install"
cleanup() {
    rm -rf "${WORK_DIR}"
}
trap cleanup EXIT
mkdir -p "${WORK_DIR}"

# ---------------------------------------------------------------------------
# Install build dependencies
# ---------------------------------------------------------------------------
echo "Installing build dependencies..."
case "$OS_ID" in
    ubuntu|debian)
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -q
        apt-get install -y --no-install-recommends \
            build-essential \
            wget \
            curl \
            git \
            ca-certificates
        rm -rf /var/lib/apt/lists/*
        ;;
    fedora)
        dnf install -y \
            gcc gcc-c++ make \
            wget curl git ca-certificates
        dnf clean all
        ;;
    centos|rhel|rocky|almalinux)
        yum install -y \
            gcc gcc-c++ make \
            wget curl git ca-certificates
        yum clean all
        ;;
    alpine)
        apk add --no-cache \
            build-base \
            wget curl git ca-certificates
        ;;
    opensuse*|sles)
        zypper install -y \
            gcc gcc-c++ make \
            wget curl git ca-certificates
        zypper clean
        ;;
    *)
        echo "Warning: Unknown OS '${OS_ID}'. Checking for required tools..."
        for cmd in g++ make wget; do
            if ! command -v "$cmd" >/dev/null 2>&1; then
                echo "Error: Required command '${cmd}' not found." >&2
                exit 1
            fi
        done
        ;;
esac

# ---------------------------------------------------------------------------
# Resolve version
# ---------------------------------------------------------------------------
if [ "${CMDSTAN_VERSION}" = "latest" ] || [ -z "${CMDSTAN_VERSION}" ]; then
    echo "Resolving latest CmdStan version from GitHub..."
    CMDSTAN_VERSION=$(curl -sSfL \
        https://api.github.com/repos/stan-dev/cmdstan/releases/latest \
        | grep '"tag_name"' \
        | sed -E 's/.*"v([^"]+)".*/\1/')
    if [ -z "${CMDSTAN_VERSION}" ]; then
        echo "Error: Could not determine latest CmdStan version from GitHub API." >&2
        exit 1
    fi
    echo "Resolved latest version: ${CMDSTAN_VERSION}"
fi

# 🛡️ Sentinel: Validate version format (X.Y.Z) to prevent path injection
if ! echo "${CMDSTAN_VERSION}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Error: Invalid CmdStan version '${CMDSTAN_VERSION}'. Expected format: X.Y.Z" >&2
    exit 1
fi

echo "Installing CmdStan ${CMDSTAN_VERSION}..."

# ---------------------------------------------------------------------------
# Download and extract
# ---------------------------------------------------------------------------
TARBALL="cmdstan-${CMDSTAN_VERSION}.tar.gz"
DOWNLOAD_URL="https://github.com/stan-dev/cmdstan/releases/download/v${CMDSTAN_VERSION}/${TARBALL}"
TARBALL_PATH="${WORK_DIR}/${TARBALL}"

echo "Downloading ${DOWNLOAD_URL}..."
wget -q --show-progress -O "${TARBALL_PATH}" "${DOWNLOAD_URL}" 2>&1 || \
    wget -O "${TARBALL_PATH}" "${DOWNLOAD_URL}"

# The release tarball extracts to cmdstan-X.Y.Z/ so the versioned dir is
# automatically created inside INSTALL_DIR.
mkdir -p "${INSTALL_DIR}"
echo "Extracting CmdStan to ${INSTALL_DIR}..."
tar -xzf "${TARBALL_PATH}" -C "${INSTALL_DIR}"

VERSIONED_DIR="${INSTALL_DIR}/cmdstan-${CMDSTAN_VERSION}"
if [ ! -d "${VERSIONED_DIR}" ]; then
    echo "Error: Expected directory '${VERSIONED_DIR}' not found after extraction." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Build CmdStan (compiles Stan math + utilities; bakes toolchain into image)
# ---------------------------------------------------------------------------
echo "Building CmdStan – compiling Stan C++ toolchain (this may take several minutes)..."
cd "${VERSIONED_DIR}"
make build -j"$(nproc)"

# Create a stable "current" symlink so users and tools can reference a
# fixed path that does not embed the version number.
ln -sfn "${VERSIONED_DIR}" "${INSTALL_DIR}/current"

# ---------------------------------------------------------------------------
# Persist environment variables system-wide
# ---------------------------------------------------------------------------
# /etc/profile.d/ is sourced by all interactive login shells (bash, sh, dash).
PROFILE_SCRIPT="/etc/profile.d/cmdstan.sh"
cat > "${PROFILE_SCRIPT}" << ENVEOF
# CmdStan – set by the cmdstan DevContainer feature
export CMDSTAN="${VERSIONED_DIR}"
export PATH="\${CMDSTAN}/bin:\${PATH}"
ENVEOF
chmod 644 "${PROFILE_SCRIPT}"

# /etc/environment is read by PAM and therefore reaches non-login shells and
# GUI sessions; it does NOT support variable expansion so we write the full
# path directly.
if [ -f /etc/environment ]; then
    # Remove any pre-existing CMDSTAN assignment, then append the new one.
    grep -v '^CMDSTAN=' /etc/environment > "${WORK_DIR}/environment.tmp" || true
    echo "CMDSTAN=${VERSIONED_DIR}" >> "${WORK_DIR}/environment.tmp"
    mv "${WORK_DIR}/environment.tmp" /etc/environment
else
    echo "CMDSTAN=${VERSIONED_DIR}" > /etc/environment
fi

# ---------------------------------------------------------------------------
# Optional: install the cmdstanr R package
# ---------------------------------------------------------------------------
if [ "${INSTALL_R_PACKAGE}" = "true" ] && command -v Rscript >/dev/null 2>&1; then
    echo "R detected – installing cmdstanr and configuring it to use ${VERSIONED_DIR}..."

    # Install cmdstanr from the Stan universe
    CMDSTAN="${VERSIONED_DIR}" Rscript -e "
        if (!requireNamespace('cmdstanr', quietly = TRUE)) {
            install.packages(
                'cmdstanr',
                repos = c('https://stan-dev.r-universe.dev', 'https://cloud.r-project.org')
            )
        }
        cat('[cmdstanr] installed.\n')
    "

    # Persist the CmdStan path for cmdstanr via Renviron.site so that it is
    # automatically picked up without requiring users to call set_cmdstan_path().
    R_HOME_DIR=$(Rscript --vanilla -e "cat(R.home())" 2>/dev/null)
    if [ -n "${R_HOME_DIR}" ] && [ -d "${R_HOME_DIR}/etc" ]; then
        RENVIRON_SITE="${R_HOME_DIR}/etc/Renviron.site"
        # Remove any existing CMDSTAN or CMDSTAN_PATH entries to avoid duplicates
        if [ -f "${RENVIRON_SITE}" ]; then
            grep -v '^CMDSTAN' "${RENVIRON_SITE}" > "${WORK_DIR}/Renviron.tmp" || true
            mv "${WORK_DIR}/Renviron.tmp" "${RENVIRON_SITE}"
        fi
        echo "# CmdStan path for cmdstanr – set by the cmdstan DevContainer feature" >> "${RENVIRON_SITE}"
        echo "CMDSTAN=${VERSIONED_DIR}" >> "${RENVIRON_SITE}"
        echo "[cmdstanr] Wrote CMDSTAN=${VERSIONED_DIR} to ${RENVIRON_SITE}"
    fi
fi

echo "CmdStan ${CMDSTAN_VERSION} installed successfully."
echo "  Installation directory : ${VERSIONED_DIR}"
echo "  Stable symlink         : ${INSTALL_DIR}/current"
echo "  CMDSTAN env var        : ${VERSIONED_DIR} (via /etc/profile.d/cmdstan.sh)"
