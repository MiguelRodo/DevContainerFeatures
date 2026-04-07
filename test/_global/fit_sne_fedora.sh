#!/bin/bash

# Test for fit-sne feature on Fedora.
# Fedora uses `dnf install gcc gcc-c++ make wget git ca-certificates` for build tools.
set -e

source dev-container-features-test-lib

check "fast_tsne binary is installed" bash -c "command -v fast_tsne"
check "fast_tsne is executable" bash -c "test -x /usr/local/bin/fast_tsne"
check "FFTW library is installed" bash -c "ldconfig -p | grep fftw3"

reportResults
