#!/usr/bin/env bash
# Source: https://xethub.com/assets/docs/getting-started/install

set -e

# Save current directory
ORIGINAL_DIR=$(pwd)

# Switch to /tmp directory
pushd /tmp

# Install FFTW
wget http://www.fftw.org/fftw-3.3.10.tar.gz
tar -xzf fftw-3.3.10.tar.gz
cd fftw-3.3.10
./configure --prefix=/usr/local  # FFTW will be installed to /usr/local
make
sudo make install

# Clean up FFTW files
cd /tmp
rm -rf fftw-3.3.10 fftw-3.3.10.tar.gz

# Install FIt-SNE
git clone https://github.com/KlugerLab/FIt-SNE
cd FIt-SNE
g++ -std=c++11 -O3 src/sptree.cpp src/tsne.cpp src/nbodyfft.cpp -o fast_tsne -pthread -I/usr/local/include -L/usr/local/lib -lfftw3 -lm -Wno-address-of-packed-member

# Move the fast_tsne executable to /usr/local/bin
sudo mv fast_tsne /usr/local/bin

# Clean up FIt-SNE files
cd /tmp
rm -rf FIt-SNE

# Return to the original directory
popd

# Verify the return to the original directory
echo "Back to directory: $(pwd)"

# Verify installation
if command -v fast_tsne &> /dev/null; then
    echo "fast_tsne installed successfully"
else
    echo "fast_tsne installation failed"
fi
