#!/bin/bash
set -e

source dev-container-features-test-lib

test_versions() {
    test "$(repos --version)" = "repos version 2.7.0"
    test "$(setupmjr --version)" = "setupmjr version 0.7.4"
}

test_setupmjr() (
    set -e
    local tmp
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    mkdir "$tmp/home"
    HOME="$tmp/home" setupmjr bash rc.d
    test -d "$tmp/home/.bashrc.d"
)

check "requested versions are installed" test_versions
check "repos requested version runs" repos --help
check "setupmjr requested version runs" test_setupmjr

reportResults
