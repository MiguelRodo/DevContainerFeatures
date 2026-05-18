#!/bin/bash

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

echo "🧪 Testing github-tokens internal functions (get_best_token, get_elevated_token)"

# Path to the script we are testing
GITHUB_PAT_SCRIPT="/usr/local/bin/github-tokens-github-pat"

# Function to run a test case in a subshell
run_test() {
    local label="$1"
    local env_setup="$2"
    local func_to_test="$3"
    local expected_output="$4"

    # We use a subshell to isolate the test case and prevent environment leakage
    check "$label" bash -c "
        $env_setup
        source $GITHUB_PAT_SCRIPT > /dev/null 2>&1
        result=\$($func_to_test)
        if [ \"\$result\" = \"$expected_output\" ]; then
            exit 0
        else
            echo \"Expected '$expected_output' but got '\$result'\"
            exit 1
        fi
    "
}

# --- Tests for get_best_token ---
# Priority: GITHUB_PAT > GH_TOKEN > GITHUB_TOKEN

run_test "get_best_token: GITHUB_PAT has highest priority" \
    "export GITHUB_PAT=pat_val; export GH_TOKEN=gh_val; export GITHUB_TOKEN=gt_val" \
    "get_best_token" "pat_val"

run_test "get_best_token: GH_TOKEN fallback" \
    "unset GITHUB_PAT; export GH_TOKEN=gh_val; export GITHUB_TOKEN=gt_val" \
    "get_best_token" "gh_val"

run_test "get_best_token: GITHUB_TOKEN fallback" \
    "unset GITHUB_PAT; unset GH_TOKEN; export GITHUB_TOKEN=gt_val" \
    "get_best_token" "gt_val"

run_test "get_best_token: empty if none set" \
    "unset GITHUB_PAT; unset GH_TOKEN; unset GITHUB_TOKEN" \
    "get_best_token" ""

# --- Tests for get_elevated_token ---
# Priority: GITHUB_PAT > GH_TOKEN (excludes GITHUB_TOKEN)

run_test "get_elevated_token: GITHUB_PAT priority" \
    "export GITHUB_PAT=pat_val; export GH_TOKEN=gh_val; export GITHUB_TOKEN=gt_val" \
    "get_elevated_token" "pat_val"

run_test "get_elevated_token: GH_TOKEN priority" \
    "unset GITHUB_PAT; export GH_TOKEN=gh_val; export GITHUB_TOKEN=gt_val" \
    "get_elevated_token" "gh_val"

run_test "get_elevated_token: empty if GITHUB_TOKEN is the only one set" \
    "unset GITHUB_PAT; unset GH_TOKEN; export GITHUB_TOKEN=gt_val" \
    "get_elevated_token" ""

# Report result
reportResults
