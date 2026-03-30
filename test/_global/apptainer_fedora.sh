#!/bin/bash

# Test for apptainer feature on Fedora.
# Fedora uses `dnf install apptainer tzdata` (distinct from Ubuntu PPA and Debian .deb paths).
set -e

source dev-container-features-test-lib

check "apptainer binary is installed" bash -c "which apptainer"
check "apptainer version command works" bash -c "apptainer --version"
check "apptainer is installed via dnf" bash -c "rpm -q apptainer"
check "timezone is configured correctly" bash -c "readlink /etc/localtime | grep -q 'America/New_York'"
check "tzdata package is installed" bash -c "rpm -q tzdata"

reportResults
