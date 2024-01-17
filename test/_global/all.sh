#!/bin/bash

# The 'test/_global' folder is a special test folder that is not tied to a single feature.
#
# This test file is executed against a running container constructed
# from the value of 'color_and_hello' in the tests/_global/scenarios.json file.
#
# The value of a scenarios element is any properties available in the 'devcontainer.json'.
# Scenarios are useful for testing specific options in a feature, or to test a combination of features.
# 
# This test can be run with the following command (from the root of this repo)
#    devcontainer features test --global-scenarios-only .

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.
check "that git xet --version works" bash -c "git xet --version"
check "that apptainer --version works" bash -c "apptainer --version"
check "that repos_clone_github is found" bash -c "repos_clone_github"
check "that repos_clone_xethub is found" bash -c "repos_clone_xethub"
check "that repos_add_workspace is found" bash -c "repos_add_workspace"
check "that repos_add_workspace creates the workspace file" bash -c "test -f EntireProject.code-workspace"

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
