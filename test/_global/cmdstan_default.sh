#!/bin/bash

# Test for the cmdstan feature on Ubuntu (default scenario).
set -e

source dev-container-features-test-lib

check "CMDSTAN env var is set" bash -c 'test -n "${CMDSTAN}"'
check "CMDSTAN directory exists" bash -c 'test -d "${CMDSTAN}"'
check "stanc compiler is present in CMDSTAN/bin" bash -c 'test -x "${CMDSTAN}/bin/stanc"'
check "stansummary is present in CMDSTAN/bin" bash -c 'test -x "${CMDSTAN}/bin/stansummary"'
check "stanc is on PATH" bash -c 'command -v stanc'
check "stanc --version works" bash -c 'stanc --version'
check "current symlink exists" bash -c 'test -L /opt/cmdstan/current'
check "profile.d script exists" bash -c 'test -f /etc/profile.d/cmdstan.sh'
check "CMDSTAN is in /etc/environment" bash -c 'grep -q "^CMDSTAN=" /etc/environment'

reportResults
