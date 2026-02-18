#!/bin/bash

# Test for fit-sne feature with default options (version=latest)
set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests for fit-sne
check "fast_tsne binary is installed" bash -c "which fast_tsne"
check "fast_tsne is executable" bash -c "test -x /usr/local/bin/fast_tsne"
check "FFTW library is installed" bash -c "ldconfig -p | grep fftw3"

# Report result
reportResults
