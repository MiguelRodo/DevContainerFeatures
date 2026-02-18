#!/bin/bash

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
check "node is installed" node --version
check "npm is installed" npm --version
check "mmdc is installed" which mmdc
check "mermaid-mmdc wrapper exists" test -f /usr/local/bin/mermaid-mmdc
check "mermaid-mmdc wrapper is executable" test -x /usr/local/bin/mermaid-mmdc
check "mermaiduser exists" id mermaiduser
check "puppeteer config exists" test -f /usr/local/share/mermaid-config/puppeteer-config.json
check "puppeteer config is readable" test -r /usr/local/share/mermaid-config/puppeteer-config.json

# Test mmdc command works
check "mmdc version command works" mmdc --version

# Report result
reportResults
