#!/bin/bash

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
check "node is installed" node --version
check "npm is installed" npm --version
check "mmdc is installed" which mmdc
check "customuser exists" id customuser
check "customuser home directory exists" test -d /home/customuser

# Report result
reportResults
