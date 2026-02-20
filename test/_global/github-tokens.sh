#!/bin/bash

# Test file for github-tokens feature (basic installation)
#
# This test verifies that the github-tokens feature installs correctly
# with default options.

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

echo "🧪 Testing github-tokens feature basic installation"

# Check that the post-create script exists and is executable
check "github-tokens-post-create exists" test -f /usr/local/bin/github-tokens-post-create
check "github-tokens-post-create is executable" test -x /usr/local/bin/github-tokens-post-create

# Check that the github-pat script exists and is executable
check "github-tokens-github-pat exists" test -f /usr/local/bin/github-tokens-github-pat
check "github-tokens-github-pat is executable" test -x /usr/local/bin/github-tokens-github-pat

# Check that the bashrc-d script exists and is executable
check "github-tokens-bashrc-d exists" test -f /usr/local/bin/github-tokens-bashrc-d
check "github-tokens-bashrc-d is executable" test -x /usr/local/bin/github-tokens-bashrc-d

# Check that the config file was created
check "github-tokens config file exists" test -f /usr/local/etc/github-tokens-github-pat.env

echo "✅ github-tokens feature installed correctly"

# Report result
reportResults
