#!/usr/bin/env bash
set -e

FITSNE_VERSION="${VERSION:-"1.2.1"}"
FFTW_VERSION="3.3.10"
FFTW_SHA256="56c932549852cddcfafdab3820b0200c7742675be92179e59e6215b340e26467"

# Ensure we are running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root.'
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

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -rf "/tmp/fftw-${FFTW_VERSION:?}"
    rm -rf "/tmp/fftw-${FFTW_VERSION:?}.tar.gz"
    rm -rf /tmp/FIt-SNE
}
trap cleanup EXIT

echo "Installing dependencies..."
case "$OS_ID" in
    ubuntu|debian)
        apt-get update
        apt-get install -y --no-install-recommends \
            build-essential \
            wget \
            git \
            ca-certificates
        ;;
    alpine)
        apk add --no-cache \
            build-base \
            wget \
            git \
            ca-certificates
        ;;
    fedora)
        dnf install -y \
            gcc gcc-c++ make \
            wget git ca-certificates
        ;;
    centos|rhel|rocky|almalinux)
        yum install -y \
            gcc gcc-c++ make \
            wget git ca-certificates
        ;;
    opensuse*|sles)
        zypper install -y \
            gcc gcc-c++ make \
            wget git ca-certificates
        ;;
    *)
        echo "Warning: Unknown OS '$OS_ID'. Checking for required build tools..."
        for cmd in gcc g++ make wget git sha256sum; do
            if ! command -v "$cmd" >/dev/null 2>&1; then
                echo "Error: Required command '$cmd' not found. Please install build tools for your OS."
                exit 1
            fi
        done
        ;;
esac

# Switch to /tmp directory
cd /tmp

# Install FFTW
echo "Downloading and compiling FFTW ${FFTW_VERSION}..."
wget "https://www.fftw.org/fftw-${FFTW_VERSION}.tar.gz"
printf '%s  %s\n' "$FFTW_SHA256" "fftw-${FFTW_VERSION}.tar.gz" | sha256sum -c -
tar -xzf "fftw-${FFTW_VERSION}.tar.gz"
cd "fftw-${FFTW_VERSION}"
./configure --prefix=/usr/local --enable-shared
make -j"$(nproc)"
make install
if command -v ldconfig >/dev/null 2>&1; then
    if [ -d /etc/ld.so.conf.d ]; then
        echo "/usr/local/lib" > /etc/ld.so.conf.d/local-libs.conf
    fi
    ldconfig
fi

cd /tmp

# Install FIt-SNE
if [ "${FITSNE_VERSION}" = "latest" ]; then
    echo "Cloning latest FIt-SNE..."
    git clone --depth 1 https://github.com/KlugerLab/FIt-SNE.git
else
    # Prevent git ref/option injection.
    if ! echo "${FITSNE_VERSION}" | grep -Eq '^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$'; then
        echo "Error: Invalid FITSNE_VERSION. Must consist of alphanumeric characters, dots, dashes, and underscores, and cannot start with a dash."
        exit 1
    fi

    echo "Fetching FIt-SNE ${FITSNE_VERSION}..."
    git init -q FIt-SNE
    git -C FIt-SNE remote add origin https://github.com/KlugerLab/FIt-SNE.git
    if git -C FIt-SNE fetch --depth 1 origin "refs/tags/v${FITSNE_VERSION}" 2>/dev/null \
        || git -C FIt-SNE fetch --depth 1 origin "refs/tags/${FITSNE_VERSION}" 2>/dev/null \
        || git -C FIt-SNE fetch --depth 1 origin "${FITSNE_VERSION}" 2>/dev/null; then
        git -C FIt-SNE checkout -q --detach FETCH_HEAD
    else
        # Preserve support for abbreviated commit SHAs that cannot be fetched directly.
        git -C FIt-SNE fetch -q origin
        git -C FIt-SNE checkout -q --detach "${FITSNE_VERSION}"
    fi
fi

cd FIt-SNE

echo "Compiling FIt-SNE..."
g++ -std=c++11 -O3 src/sptree.cpp src/tsne.cpp src/nbodyfft.cpp \
    -o fast_tsne \
    -pthread \
    -I/usr/local/include \
    -L/usr/local/lib \
    -Wl,-rpath,/usr/local/lib \
    -lfftw3 -lm \
    -Wno-address-of-packed-member

# Move binary
mv fast_tsne /usr/local/bin/fast_tsne
chmod +x /usr/local/bin/fast_tsne

echo "FIt-SNE installed successfully at /usr/local/bin/fast_tsne"
