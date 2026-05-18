#!/bin/bash
set -e

# Load the devcontainer test library IF running in the container
source dev-container-features-test-lib

echo "🧪 Testing ensure_jq with mocked package managers..."

sed -n '/ensure_jq() {/,/^}/p' /usr/local/bin/renv-cache-renv-restore-build > /tmp/ensure_jq.sh

test_apt_get() {
  (
    command() { if [ "$1" = "-v" ] && [ "$2" = "jq" ]; then return 1; elif [ "$1" = "-v" ] && [ "$2" = "apt-get" ]; then return 0; else return 1; fi; }
    export JQ_INSTALLED=0
    apt-get() { if [ "$1" = "install" ]; then export JQ_INSTALLED=1; fi; return 0; }
    rm() { return 0; }

    source /tmp/ensure_jq.sh
    ensure_jq >/dev/null 2>&1

    [ "$JQ_INSTALLED" = "1" ]
  )
}

test_apk() {
  (
    command() { if [ "$1" = "-v" ] && [ "$2" = "jq" ]; then return 1; elif [ "$1" = "-v" ] && [ "$2" = "apk" ]; then return 0; else return 1; fi; }
    export JQ_INSTALLED=0
    apk() { if [ "$1" = "add" ]; then export JQ_INSTALLED=1; fi; return 0; }

    source /tmp/ensure_jq.sh
    ensure_jq >/dev/null 2>&1

    [ "$JQ_INSTALLED" = "1" ]
  )
}

test_dnf() {
  (
    command() { if [ "$1" = "-v" ] && [ "$2" = "jq" ]; then return 1; elif [ "$1" = "-v" ] && [ "$2" = "dnf" ]; then return 0; else return 1; fi; }
    export JQ_INSTALLED=0
    dnf() { if [ "$1" = "install" ]; then export JQ_INSTALLED=1; fi; return 0; }

    source /tmp/ensure_jq.sh
    ensure_jq >/dev/null 2>&1

    [ "$JQ_INSTALLED" = "1" ]
  )
}

test_yum() {
  (
    command() { if [ "$1" = "-v" ] && [ "$2" = "jq" ]; then return 1; elif [ "$1" = "-v" ] && [ "$2" = "yum" ]; then return 0; else return 1; fi; }
    export JQ_INSTALLED=0
    yum() { if [ "$1" = "install" ]; then export JQ_INSTALLED=1; fi; return 0; }

    source /tmp/ensure_jq.sh
    ensure_jq >/dev/null 2>&1

    [ "$JQ_INSTALLED" = "1" ]
  )
}

check "apt-get fallback works" test_apt_get
check "apk fallback works" test_apk
check "dnf fallback works" test_dnf
check "yum fallback works" test_yum

rm /tmp/ensure_jq.sh
reportResults
