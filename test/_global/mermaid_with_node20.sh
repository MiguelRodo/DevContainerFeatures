#!/bin/bash

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
check "node is installed" node --version
check "node version starts with v20" bash -c "node --version | grep -q '^v20'"
check "npm is installed" npm --version
check "mmdc is installed" which mmdc
check "mermaid-mmdc wrapper exists" test -f /usr/local/bin/mermaid-mmdc
check "mermaiduser exists" id mermaiduser

# Report result
reportResults
