#!/bin/bash
set -e

source dev-container-features-test-lib

# Test that r-lib paths are accessible
check "check r-lib paths accessible" bash -c "ls -la /renv/local && ls -la /renv/cache"

reportResults
