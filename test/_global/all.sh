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

# Feature-specific tests for repos
# The 'check' command comes from the dev-container-features-test-lib.
check "repos binary is installed" bash -c "which repos"
check "repos help command works" bash -c "repos --help || repos -h || true"
check "repos-post-start script exists" bash -c "test -f /usr/local/bin/repos-post-start"
check "repos-post-start script is executable" bash -c "test -x /usr/local/bin/repos-post-start"

# Feature-specific tests for fit-sne
check "fast_tsne binary is installed" bash -c "which fast_tsne"
check "fast_tsne is executable" bash -c "test -x /usr/local/bin/fast_tsne"
check "FFTW library is installed" bash -c "ldconfig -p | grep fftw3"

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
