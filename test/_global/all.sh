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

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.
check "repos binary is installed" bash -c "which repos"
check "repos help command works" bash -c "repos --help || repos -h || true"
check "repos-post-start script exists" bash -c "test -f /usr/local/bin/repos-post-start"
check "repos-post-start script is executable" bash -c "test -x /usr/local/bin/repos-post-start"

# Apptainer tests
check "apptainer binary is installed" bash -c "which apptainer"
check "apptainer version command works" bash -c "apptainer --version"
check "timezone is configured correctly" bash -c "readlink /etc/localtime | grep -q 'America/New_York'"
check "tzdata package is installed" bash -c "dpkg -l | grep -q tzdata"

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
