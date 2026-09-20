#!/bin/bash

# The 'test/_global' folder is a special test folder that is not tied to a single feature.
#
# This test file is executed against a running container constructed
# from the value of 'all' in the tests/_global/scenarios.json file.
#
# This test can be run with the following command (from the root of this repo)
#    devcontainer features test --global-scenarios-only .

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests for repos
# The 'check' command comes from the dev-container-features-test-lib.
check "repos binary is installed" bash -c "command -v repos"
check "repos help command works" bash -c "repos --help || repos -h || true"
check "repos-post-start script exists" bash -c "test -f /usr/local/bin/repos-post-start"
check "repos-post-start script is executable" bash -c "test -x /usr/local/bin/repos-post-start"

# Feature-specific tests for fit-sne
check "fast_tsne binary is installed" bash -c "command -v fast_tsne"
check "fast_tsne is executable" bash -c "test -x /usr/local/bin/fast_tsne"
check "FFTW library is installed" bash -c "ldconfig -p | grep fftw3"
check "fast_tsne processes a tiny dataset" bash -c '
set -e
tmp=$(mktemp -d)
# FIt-SNE 1.2.1 fixture: 12 deterministic 2D points, perplexity 2, two iterations.
printf "%s" "DAAAAAIAAAAAAAAAAADgPwAAAAAAAABAAgAAAAIAAAABAAAAAQAAAAAAAAAAAOA/mpmZmZmZ6T8AAAAAAABpQAAAAAAAABRA/////wAAAAAAAD7AAgAAAAIAAAAAAAAAAAAoQAAAAAABAAAABgAAAP////8AAAAAAADwvwMAAAAAAAAAAADwPwoAAAAAAAAAAAAAwAAAAAAAAADAAAAAAAAAAMAAAAAAAADwvwAAAAAAAPC/AAAAAAAAAMAAAAAAAADwvwAAAAAAAPC/AAAAAAAA8D8AAAAAAADwPwAAAAAAAPA/AAAAAAAAAEAAAAAAAAAAQAAAAAAAAPA/AAAAAAAAAEAAAAAAAAAAQAAAAAAAAADAAAAAAAAAAEAAAAAAAADwvwAAAAAAAPA/AAAAAAAA8D8AAAAAAADwvwAAAAAAAABAAAAAAAAAAMAqAAAAAAAAAAAA8D8AAAAA" | base64 -d > "$tmp/data.dat"
fast_tsne 1.2.1 "$tmp/data.dat" "$tmp/result.dat" 1
test "$(wc -c < "$tmp/result.dat")" -eq 220
read -r n d < <(od -An -N8 -t u4 "$tmp/result.dat")
test "$n" -eq 12
test "$d" -eq 2
rm -rf "$tmp"
'
# Apptainer tests
check "apptainer binary is installed" bash -c "command -v apptainer"
check "apptainer version command works" bash -c "apptainer --version"
check "timezone is configured correctly" bash -c "readlink /etc/localtime | grep -q 'America/New_York'"
check "tzdata package is installed" bash -c "dpkg -l | grep -q tzdata"

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
