#!/bin/bash

# Test file for github-tokens bashrc-d functionality
#
# This test verifies that the config_bashrc_d function works correctly:
# 1. It adds bashrc.d sourcing to .bashrc if it doesn't exist
# 2. It does not add it twice if it already exists
# 3. It works with an existing .bashrc

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

echo "🧪 Testing github-tokens bashrc-d script"

# The command we want to run inside a clean subshell so we can modify HOME safely
check "bashrc.d configuration is added to a new .bashrc" bash -c "
    export HOME=\$(mktemp -d)
    # the install script puts it at /usr/local/bin/github-tokens-bashrc-d
    # in github-tokens.sh it is run by running /usr/local/bin/github-tokens-bashrc-d directly
    /usr/local/bin/github-tokens-bashrc-d
    test -f \"\$HOME/.bashrc\" && grep -q 'bashrc.d' \"\$HOME/.bashrc\" && test -d \"\$HOME/.bashrc.d\"
"

check "bashrc.d configuration is idempotent" bash -c "
    export HOME=\$(mktemp -d)
    /usr/local/bin/github-tokens-bashrc-d
    LINES1=\$(wc -l < \"\$HOME/.bashrc\" || echo 0)
    /usr/local/bin/github-tokens-bashrc-d
    LINES2=\$(wc -l < \"\$HOME/.bashrc\" || echo 0)
    test \"\$LINES1\" -eq \"\$LINES2\"
"

check "bashrc.d configuration works with an existing .bashrc" bash -c "
    export HOME=\$(mktemp -d)
    echo '# some comment' > \"\$HOME/.bashrc\"
    /usr/local/bin/github-tokens-bashrc-d
    grep -q 'bashrc.d' \"\$HOME/.bashrc\" && grep -q '# some comment' \"\$HOME/.bashrc\"
"

echo "✅ github-tokens bashrc-d script works correctly"

# Report result
reportResults
