#!/bin/bash

# Test for fit-sne feature on Debian.
set -e

source dev-container-features-test-lib

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

reportResults
