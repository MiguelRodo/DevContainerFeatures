#!/bin/bash
set -e

# SCRIPT_DIR is the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../../src/mermaid/install.sh"

echo "Testing invalid USERNAME..."
output=$(USERNAME="-invalid" bash "$INSTALL_SCRIPT" 2>&1 || true)

if echo "$output" | grep -q "Error: Invalid USERNAME"; then
    echo "✅ Success: Caught invalid username"
    exit 0
else
    echo "❌ Fail: Did not catch invalid username"
    echo "Output was: $output"
    exit 1
fi
