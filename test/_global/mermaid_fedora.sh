#!/bin/bash

# Test for mermaid feature on Fedora.
# Fedora uses dnf to install dependencies and Node.js.
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

check "mmdc version command works" mmdc --version

# Verify the packaged browser actually renders a diagram.
MERMAID_TEST_DIR=/tmp/mermaid-fedora-render-test
mkdir -p "$MERMAID_TEST_DIR"
chown mermaiduser:mermaiduser "$MERMAID_TEST_DIR"
printf 'flowchart TD\n    A --> B\n' > "$MERMAID_TEST_DIR/input.mmd"
check "mermaid-mmdc renders SVG" mermaid-mmdc -- -i "$MERMAID_TEST_DIR/input.mmd" -o "$MERMAID_TEST_DIR/output.svg"
check "rendered SVG is non-empty" test -s "$MERMAID_TEST_DIR/output.svg"
check "rendered output contains an SVG element" grep -q '<svg' "$MERMAID_TEST_DIR/output.svg"

reportResults
