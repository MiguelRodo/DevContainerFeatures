#!/bin/bash

# Test file for github-tokens feature with overrideGitHubToken option
#
# This test verifies that when overrideGitHubToken is enabled,
# GITHUB_TOKEN is forced to use GH_TOKEN or GITHUB_PAT regardless
# of its current value.

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

echo "🧪 Testing github-tokens overrideGitHubToken functionality"

# Check that the github-pat script exists and is executable
check "github-tokens-github-pat exists" test -f /usr/local/bin/github-tokens-github-pat
check "github-tokens-github-pat is executable" test -x /usr/local/bin/github-tokens-github-pat

# Source the github-pat script to set environment variables
echo "🔧 Running github-tokens-github-pat script..."
source /usr/local/bin/github-tokens-github-pat

# Verify that GITHUB_PAT is set (should be the GITHUB_PAT value since it has highest priority)
echo "🔍 Checking GITHUB_PAT: ${GITHUB_PAT:0:20}..."
check "GITHUB_PAT is set" test -n "$GITHUB_PAT"
check "GITHUB_PAT has expected value" test "$GITHUB_PAT" = "ghp_pat_token"

# Verify that GITHUB_TOKEN was overridden to match GITHUB_PAT
echo "🔍 Checking GITHUB_TOKEN: ${GITHUB_TOKEN:0:20}..."
check "GITHUB_TOKEN is set" test -n "$GITHUB_TOKEN"
check "GITHUB_TOKEN was overridden to GITHUB_PAT" test "$GITHUB_TOKEN" = "ghp_pat_token"

echo "✅ overrideGitHubToken works correctly - GITHUB_TOKEN was forced to use GITHUB_PAT"

# Report result
reportResults
