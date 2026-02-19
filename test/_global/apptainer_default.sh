#!/bin/bash

# Test for apptainer feature with default options (timezone=UTC)
set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests for apptainer
check "apptainer binary is installed" bash -c "which apptainer"
check "apptainer version command works" bash -c "apptainer --version"
check "timezone is configured as UTC" bash -c "readlink /etc/localtime | grep -q 'UTC'"
check "tzdata package is installed" bash -c "dpkg -l | grep -q tzdata"

# Report result
reportResults
