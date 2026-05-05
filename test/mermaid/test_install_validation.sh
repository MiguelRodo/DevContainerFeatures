#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "🧪 Running Mermaid install.sh validation tests..."

# Function to run a test case
# Usage: run_test <test_name> <env_var_name> <env_var_value> <expected_error_substring>
run_test() {
    local test_name="$1"
    local env_var="$2"
    local value="$3"
    local expected_error="$4"

    echo -n "Test: $test_name... "

    # Run the script with the specific environment variable
    local output
    output=$(export "$env_var"="$value"; bash src/mermaid/install.sh 2>&1) || true

    if echo "$output" | grep -q "$expected_error"; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Expected error containing: '$expected_error'"
        echo "  Actual output: '$output'"
        exit 1
    fi
}

# --- Invalid NODE_VERSION Tests ---

run_test "NODE_VERSION with spaces" "NODEVERSION" "lts 20" "Error: Invalid NODE_VERSION."
run_test "NODE_VERSION with semicolon" "NODEVERSION" "20; echo vulnerable" "Error: Invalid NODE_VERSION."
run_test "NODE_VERSION with backticks" "NODEVERSION" "\`whoami\`" "Error: Invalid NODE_VERSION."
run_test "NODE_VERSION with special characters" "NODEVERSION" "20.x!" "Error: Invalid NODE_VERSION."

# --- Invalid USERNAME Tests ---

run_test "USERNAME starting with dash" "USERNAME" "-invaliduser" "Error: Invalid USERNAME"
run_test "USERNAME with spaces" "USERNAME" "user name" "Error: Invalid USERNAME"
run_test "USERNAME with special characters" "USERNAME" "user@name" "Error: Invalid USERNAME"

# --- Valid Inputs Test (should pass initial validation and reach root check) ---

echo -n "Test: Valid inputs pass initial validation... "
output=$(export NODEVERSION="20" USERNAME="validuser"; bash src/mermaid/install.sh 2>&1) || true
if echo "$output" | grep -q "Error: install.sh must be run as root."; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "  Expected it to reach the root check."
    echo "  Actual output: '$output'"
    exit 1
fi

echo -e "\n${GREEN}✅ All validation tests passed!${NC}"
