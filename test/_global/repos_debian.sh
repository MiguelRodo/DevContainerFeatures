#!/bin/bash

# Test for repos feature on Debian
set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests for repos
check "repos binary is installed" bash -c "which repos"
check "repos help command works" bash -c "repos --help || repos -h || true"
check "repos-post-start script exists" bash -c "test -f /usr/local/bin/repos-post-start"
check "repos-post-start script is executable" bash -c "test -x /usr/local/bin/repos-post-start"

# Debian uses APT installation, so repos should be in /usr/bin
check "repos is installed via APT" bash -c "dpkg -l | grep -q repos || test -x /usr/local/bin/repos"

# Report result
reportResults
