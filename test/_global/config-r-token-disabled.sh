#!/bin/bash

# Test file for config-r feature with token management disabled
#
# This test verifies that when all token management options are disabled,
# the github-pat script doesn't modify any environment variables.

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

echo "🧪 Testing config-r with token management disabled"

# When ensureGitHubPatSet is false, the github-pat script should not be installed
check "config-r-github-pat should not exist" bash -c "! test -f /usr/local/bin/config-r-github-pat"

# The bashrc.d directory should still not have the github-pat script
check "github-pat should not be in bashrc.d" bash -c "! test -f $HOME/.bashrc.d/config-r-github-pat"

# Verify that GH_TOKEN is still set (from remoteEnv)
echo "🔍 Checking GH_TOKEN: ${GH_TOKEN:0:20}..."
check "GH_TOKEN is set from environment" test -n "$GH_TOKEN"
check "GH_TOKEN has expected value" test "$GH_TOKEN" = "ghp_permissive_token"

# Verify that GITHUB_PAT is NOT set (since ensureGitHubPatSet is false)
echo "🔍 Checking GITHUB_PAT..."
check "GITHUB_PAT is not set" test -z "$GITHUB_PAT"

# Verify that GITHUB_TOKEN is NOT set (not provided in environment)
echo "🔍 Checking GITHUB_TOKEN..."
check "GITHUB_TOKEN is not set" test -z "$GITHUB_TOKEN"

echo "✅ Token management correctly disabled - no automatic token setting occurred"

# Report result
reportResults
