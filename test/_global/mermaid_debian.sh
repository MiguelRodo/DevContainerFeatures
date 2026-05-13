#!/bin/bash

# Test for mermaid feature on Debian.
set -e

source dev-container-features-test-lib

check "node is installed" node --version
check "npm is installed" npm --version
check "mmdc is installed" command -v mmdc
check "mermaid-mmdc wrapper exists" test -f /usr/local/bin/mermaid-mmdc
check "mermaid-mmdc wrapper is executable" test -x /usr/local/bin/mermaid-mmdc
check "mermaid-mmdc wrapper executes securely as root via su" su root -c "mermaid-mmdc -- --version"
check "mermaiduser exists" id mermaiduser
check "puppeteer config exists" test -f /usr/local/share/mermaid-config/puppeteer-config.json
check "puppeteer config is readable" test -r /usr/local/share/mermaid-config/puppeteer-config.json

check "mmdc version command works" mmdc --version

reportResults
