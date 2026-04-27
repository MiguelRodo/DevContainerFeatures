#!/bin/bash

# Test for the cmdstan feature with Python (cmdstanpy) integration.
set -e

source dev-container-features-test-lib

check "CMDSTAN env var is set" bash -c 'test -n "${CMDSTAN}"'
check "CMDSTAN directory exists" bash -c 'test -d "${CMDSTAN}"'
check "stanc is on PATH" bash -c 'command -v stanc'
check "cmdstanpy is importable" python3 -c "import cmdstanpy"
check "cmdstanpy reports correct path" python3 -c "
import cmdstanpy, os
expected = os.environ.get('CMDSTAN', '')
actual = cmdstanpy.cmdstan_path()
assert actual == expected, f'Expected {expected!r}, got {actual!r}'
"

reportResults
