#!/bin/bash

# Test for mermaid feature on Alpine Linux.
# Alpine uses system Chromium instead of downloading Chrome via Puppeteer.
set -e

source dev-container-features-test-lib

check "node is installed" node --version
check "npm is installed" npm --version
check "mmdc is installed" command -v mmdc
check "mermaid-mmdc wrapper exists" test -f /usr/local/bin/mermaid-mmdc
check "mermaid-mmdc wrapper is executable" test -x /usr/local/bin/mermaid-mmdc
check "mermaid-mmdc wrapper executes securely as root via su" su -s /bin/sh root -c "mermaid-mmdc -- --version"
check "mermaiduser exists" id mermaiduser
check "puppeteer config exists" test -f /usr/local/share/mermaid-config/puppeteer-config.json
check "puppeteer config is readable" test -r /usr/local/share/mermaid-config/puppeteer-config.json
check "system chromium is installed" bash -c "command -v chromium-browser || command -v chromium"
check "puppeteer config uses system chromium" bash -c "grep -q '\"executablePath\".*chromium' /usr/local/share/mermaid-config/puppeteer-config.json"

reportResults
