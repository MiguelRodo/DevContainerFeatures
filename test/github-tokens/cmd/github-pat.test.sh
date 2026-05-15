#!/bin/bash

set -e

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)/src/github-tokens/cmd/github-pat"

echo "🧪 Running tests for get_best_token"

fails=0

# Helper to run tests in a subshell
run_test() {
    local test_name="$1"
    local expected="$2"
    shift 2
    local result

    # Run in a subshell to isolate environment variables
    # We use a subshell to prevent the sourced script's side effects
    # from affecting the parent shell.
    result=$(
        # Unset variables to ensure clean state
        unset GITHUB_PAT GH_TOKEN GITHUB_TOKEN

        # Set environment variables passed to the function
        eval "$*"

        # Source the script
        source "$SCRIPT_PATH" >/dev/null 2>&1

        # Call the function
        get_best_token
    )

    if [ "$result" = "$expected" ]; then
        echo "✅ PASS: $test_name"
    else
        echo "❌ FAIL: $test_name (Expected: '$expected', Got: '$result')"
        fails=$((fails + 1))
    fi
}

run_test "GITHUB_PAT has highest priority" "pat_token" \
    'export GITHUB_PAT="pat_token" GH_TOKEN="gh_token" GITHUB_TOKEN="github_token"'

run_test "GH_TOKEN is used if GITHUB_PAT is missing" "gh_token" \
    'export GH_TOKEN="gh_token" GITHUB_TOKEN="github_token"'

run_test "GITHUB_TOKEN is used if others are missing" "github_token" \
    'export GITHUB_TOKEN="github_token"'

run_test "Empty string returned if no tokens are set" "" \
    'true'

if [ "$fails" -gt 0 ]; then
    echo "❌ $fails tests failed!"
    exit 1
fi

echo "🎉 All tests passed!"
