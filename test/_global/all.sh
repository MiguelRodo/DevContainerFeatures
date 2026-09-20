#!/bin/bash

# The 'test/_global' folder is a special test folder that is not tied to a single feature.
#
# This test file is executed against a running container constructed
# from the value of 'all' in the tests/_global/scenarios.json file.
#
# This test can be run with the following command (from the root of this repo)
#    devcontainer features test --global-scenarios-only .

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific smoke tests for utils
check "repos help command works" repos --help
check "setupmjr help command works" setupmjr --help

# Feature-specific tests for fit-sne
check "fast_tsne binary is installed" bash -c "command -v fast_tsne"
check "fast_tsne is executable" bash -c "test -x /usr/local/bin/fast_tsne"
check "FFTW library is installed" bash -c "ldconfig -p | grep fftw3"
# Apptainer tests
check "apptainer binary is installed" bash -c "command -v apptainer"
check "apptainer version command works" bash -c "apptainer --version"
check "timezone is configured correctly" bash -c "readlink /etc/localtime | grep -q 'America/New_York'"
check "tzdata package is installed" bash -c "dpkg -l | grep -q tzdata"

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
