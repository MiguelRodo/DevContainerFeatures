#!/bin/bash

set -e

source dev-container-features-test-lib

check "Hugo is installed" hugo version
check "Hugo install marker exists" test -f /etc/profile.d/00-restore-env.sh
check "build-info runs after Hugo" test /usr/local/etc/container_metadata/build_info.txt -nt /etc/profile.d/00-restore-env.sh
check "container-info keeps configured version" bash -c "container-info | grep 'Version : 1.2.3'"
check "container-info keeps configured date" bash -c "container-info | grep 'Built On: 2023-10-27T10:00:00Z'"

reportResults
