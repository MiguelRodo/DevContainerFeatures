#!/bin/bash
set -e
source dev-container-features-test-lib

check "repos is installed and accessible" repos --help
check "setupmjr is installed and accessible" setupmjr --help
reportResults
