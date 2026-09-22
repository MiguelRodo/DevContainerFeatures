#!/bin/bash

# Test for apptainer feature on Debian.
# Debian uses a .deb download from GitHub releases (distinct from Ubuntu's PPA path).
set -e

source dev-container-features-test-lib

check "apptainer binary is installed" bash -c "command -v apptainer"
check "apptainer default fallback version is pinned" bash -c "apptainer --version | grep -Fq '1.5.3'"
check "apptainer executes an Alpine container" apptainer exec docker://alpine:3.22 cat /etc/alpine-release
check "apptainer is installed via dpkg" bash -c "dpkg -l | grep -q apptainer"
check "timezone is configured correctly" bash -c "readlink /etc/localtime | grep -q 'America/New_York'"
check "tzdata package is installed" bash -c "dpkg -l | grep -q tzdata"

reportResults
