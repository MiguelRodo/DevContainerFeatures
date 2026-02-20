#!/bin/bash

# Test file for github-tokens feature with token management disabled
#
# This test verifies that when all token management options are disabled,
# the github-pat script does not modify any environment variables.

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

echo "🧪 Testing github-tokens with token management disabled"

# The github-tokens feature is still installed (scripts exist), but token
# elevation/override is disabled via options
check "github-tokens-github-pat exists" test -f /usr/local/bin/github-tokens-github-pat
check "github-tokens-github-pat is executable" test -x /usr/local/bin/github-tokens-github-pat

# Verify that GH_TOKEN is still set (from remoteEnv)
echo "🔍 Checking GH_TOKEN: ${GH_TOKEN:0:20}..."
check "GH_TOKEN is set from environment" test -n "$GH_TOKEN"
check "GH_TOKEN has expected value" test "$GH_TOKEN" = "ghp_permissive_token"

# Source the github-pat script - it should set GITHUB_PAT but NOT change GITHUB_TOKEN
# (since both elevateGitHubToken and overrideGitHubToken are false)
echo "🔧 Running github-tokens-github-pat script..."
source /usr/local/bin/github-tokens-github-pat

# GITHUB_PAT should be set from GH_TOKEN (the script always sets GITHUB_PAT from best available token)
echo "🔍 Checking GITHUB_PAT..."
check "GITHUB_PAT is set from GH_TOKEN" test -n "$GITHUB_PAT"
check "GITHUB_PAT equals GH_TOKEN" test "$GITHUB_PAT" = "ghp_permissive_token"

# GITHUB_TOKEN should NOT be changed (it was not set in remoteEnv, and elevation is disabled)
echo "🔍 Checking GITHUB_TOKEN..."
check "GITHUB_TOKEN is not set" test -z "$GITHUB_TOKEN"

echo "✅ Token management correctly disabled - GITHUB_TOKEN not modified"

# Report result
reportResults
