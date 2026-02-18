#!/bin/bash

# Test file for config-r feature with update=true
#
# This test file is executed against a running container constructed
# from the value of 'config-r_with_update' in the tests/_global/scenarios.json file.

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.

# Check that R is available
check "R is installed" bash -c "which R"
check "Rscript is available" bash -c "which Rscript"

# Check that config-r scripts are installed
check "config-r-post-create exists" bash -c "test -f /usr/local/bin/config-r-post-create"
check "config-r-post-create is executable" bash -c "test -x /usr/local/bin/config-r-post-create"
check "config-r-renv-restore exists" bash -c "test -f /usr/local/bin/config-r-renv-restore"
check "config-r-renv-restore is executable" bash -c "test -x /usr/local/bin/config-r-renv-restore"
check "config-r-renv-restore-build exists" bash -c "test -f /usr/local/bin/config-r-renv-restore-build"
check "config-r-renv-restore-build is executable" bash -c "test -x /usr/local/bin/config-r-renv-restore-build"

# Check that renvvv is installed
check "renvvv is installed" Rscript -e "if (!requireNamespace('renvvv', quietly = TRUE)) quit(status = 1)"

# Check that remotes is installed (required for installing renvvv)
check "remotes is installed" Rscript -e "if (!requireNamespace('remotes', quietly = TRUE)) quit(status = 1)"

# Check that renv is installed
check "renv is installed" Rscript -e "if (!requireNamespace('renv', quietly = TRUE)) quit(status = 1)"

# Test that renv-restore help works
check "renv-restore help works" bash -c "/usr/local/bin/config-r-renv-restore --help"

# Test that renv-restore-build help works
check "renv-restore-build help works" bash -c "/usr/local/bin/config-r-renv-restore-build --help"

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
