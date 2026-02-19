#!/bin/bash

# Test file for config-r feature with elevateGitHubToken option
#
# This test verifies that when elevateGitHubToken is enabled and a more
# permissive token (GH_TOKEN or GITHUB_PAT) is available, GITHUB_TOKEN
# is overridden to match it.

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

echo "🧪 Testing config-r elevateGitHubToken functionality"

# Check that the github-pat script exists and is executable
check "config-r-github-pat exists" test -f /usr/local/bin/config-r-github-pat
check "config-r-github-pat is executable" test -x /usr/local/bin/config-r-github-pat

# Check that bashrc.d is configured
check "bashrc.d directory exists" test -d "$HOME/.bashrc.d"
check "github-pat in bashrc.d" test -f "$HOME/.bashrc.d/config-r-github-pat"

# Source the github-pat script to set environment variables
echo "🔧 Running github-pat script..."
source /usr/local/bin/config-r-github-pat

# Verify that GITHUB_PAT is set (should be set from GH_TOKEN since it has priority)
echo "🔍 Checking GITHUB_PAT: ${GITHUB_PAT:0:20}..."
check "GITHUB_PAT is set" test -n "$GITHUB_PAT"
check "GITHUB_PAT equals GH_TOKEN" test "$GITHUB_PAT" = "ghp_permissive_token"

# Verify that GITHUB_TOKEN was elevated to match GH_TOKEN
echo "🔍 Checking GITHUB_TOKEN: ${GITHUB_TOKEN:0:20}..."
check "GITHUB_TOKEN is set" test -n "$GITHUB_TOKEN"
check "GITHUB_TOKEN was elevated to GH_TOKEN" test "$GITHUB_TOKEN" = "ghp_permissive_token"

echo "✅ elevateGitHubToken works correctly - GITHUB_TOKEN was elevated to use GH_TOKEN"

# Report result
reportResults
