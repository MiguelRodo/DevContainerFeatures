#!/usr/bin/env bash
set -e

FITSNE_VERSION="${VERSION:-"latest"}"
FFTW_VERSION="3.3.10"

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
    rm -rf /tmp/fftw-${FFTW_VERSION}
    rm -rf /tmp/fftw-${FFTW_VERSION}.tar.gz
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
        for cmd in gcc g++ make wget git; do
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
tar -xzf "fftw-${FFTW_VERSION}.tar.gz"
cd "fftw-${FFTW_VERSION}"
./configure --prefix=/usr/local --enable-shared
make -j"$(nproc)"
make install
if command -v ldconfig >/dev/null 2>&1; then
    ldconfig
fi

cd /tmp

# Install FIt-SNE
echo "Cloning FIt-SNE..."
git clone https://github.com/KlugerLab/FIt-SNE.git
cd FIt-SNE

if [ "${FITSNE_VERSION}" != "latest" ] && [ "${FITSNE_VERSION}" != "" ]; then
    echo "Checking out version ${FITSNE_VERSION}..."
    # Try with 'v' prefix first, then without
    if ! git checkout "v${FITSNE_VERSION}" 2>/dev/null; then
        git checkout "${FITSNE_VERSION}"
    fi
fi

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
