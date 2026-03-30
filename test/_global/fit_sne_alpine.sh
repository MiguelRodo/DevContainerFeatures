#!/bin/bash

# Test for fit-sne feature on Alpine Linux.
# Alpine uses build-base (musl libc) instead of build-essential.
# ldconfig is not available on Alpine; check for library files directly.
set -e

source dev-container-features-test-lib

check "fast_tsne binary is installed" bash -c "which fast_tsne"
check "fast_tsne is executable" bash -c "test -x /usr/local/bin/fast_tsne"
check "FFTW library is installed" bash -c "test -f /usr/local/lib/libfftw3.so || ls /usr/local/lib/libfftw3*.a"

reportResults
