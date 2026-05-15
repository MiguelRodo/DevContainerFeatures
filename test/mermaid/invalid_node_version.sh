#!/usr/bin/env bash
set -e

# Test standalone bash script to verify invalid NODE_VERSION error

echo "Running test: Invalid NODE_VERSION rejected correctly"
OUTPUT=$(NODEVERSION="20; rm -rf /" bash src/mermaid/install.sh 2>&1 || true)

if echo "$OUTPUT" | grep -q "Error: Invalid NODE_VERSION."; then
    echo "Test passed: Invalid NODE_VERSION rejected correctly."
else
    echo "Test failed: Expected 'Error: Invalid NODE_VERSION.' not found."
    echo "Output: $OUTPUT"
    false
fi
