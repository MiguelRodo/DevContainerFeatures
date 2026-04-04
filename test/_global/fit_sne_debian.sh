#!/bin/bash

# Test for fit-sne feature on Debian.
set -e

source dev-container-features-test-lib

check "fast_tsne binary is installed" bash -c "command -v fast_tsne"
check "fast_tsne is executable" bash -c "test -x /usr/local/bin/fast_tsne"
check "FFTW library is installed" bash -c "ldconfig -p | grep fftw3"

reportResults
