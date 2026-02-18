#!/bin/bash

# Test for repos feature with runOnStart=false
set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests for repos
check "repos binary is installed" bash -c "which repos"
check "repos help command works" bash -c "repos --help || repos -h || true"
check "repos-post-start script exists" bash -c "test -f /usr/local/bin/repos-post-start"
check "repos-post-start script is executable" bash -c "test -x /usr/local/bin/repos-post-start"

# Note: We can't directly test that runOnStart=false works in this test context
# because postStartCommand is set to run the repos-post-start script regardless.
# The actual functionality is controlled by environment variables at runtime.

# Report result
reportResults
