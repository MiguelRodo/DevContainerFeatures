#!/usr/bin/env bash
set -e

FITSNE_VERSION="${VERSION:-"latest"}"
FFTW_VERSION="3.3.10"

# Ensure we are running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root.'
    exit 1
fi

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -rf /tmp/fftw-${FFTW_VERSION}
    rm -rf /tmp/fftw-${FFTW_VERSION}.tar.gz
    rm -rf /tmp/FIt-SNE
    rm -rf /var/lib/apt/lists/*
}
trap cleanup EXIT

echo "Installing dependencies..."
apt-get update
apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    git \
    ca-certificates

# Switch to /tmp directory
cd /tmp

# Install FFTW
echo "Downloading and compiling FFTW ${FFTW_VERSION}..."
wget "https://www.fftw.org/fftw-${FFTW_VERSION}.tar.gz"
tar -xzf "fftw-${FFTW_VERSION}.tar.gz"
cd "fftw-${FFTW_VERSION}"
./configure --prefix=/usr/local --enable-shared
make -j$(nproc)
make install
ldconfig

cd /tmp

# Install FIt-SNE
echo "Cloning FIt-SNE..."
git clone https://github.com/KlugerLab/FIt-SNE.git
cd FIt-SNE

if [ "${FITSNE_VERSION}" != "latest" ] && [ "${FITSNE_VERSION}" != "" ]; then
    echo "Checking out version ${FITSNE_VERSION}..."
    git checkout "${FITSNE_VERSION}"
fi

echo "Compiling FIt-SNE..."
g++ -std=c++11 -O3 src/sptree.cpp src/tsne.cpp src/nbodyfft.cpp \
    -o fast_tsne \
    -pthread \
    -I/usr/local/include \
    -L/usr/local/lib \
    -lfftw3 -lm \
    -Wno-address-of-packed-member

# Move binary
mv fast_tsne /usr/local/bin/fast_tsne
chmod +x /usr/local/bin/fast_tsne

echo "FIt-SNE installed successfully at /usr/local/bin/fast_tsne"
