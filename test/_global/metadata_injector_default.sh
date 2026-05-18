#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

check "container-info script exists and is executable" test -x /usr/local/bin/container-info
check "build_info.txt exists" test -f /usr/local/etc/container_metadata/build_info.txt

# Run the command and check output
check "container-info outputs correct version" bash -c "container-info | grep 'Version : 1.2.3'"
check "container-info outputs correct date" bash -c "container-info | grep 'Built On: 2023-10-27T10:00:00Z'"

# Report result
reportResults