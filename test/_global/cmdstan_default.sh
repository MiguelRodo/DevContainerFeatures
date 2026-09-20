#!/bin/bash

# Test for the cmdstan feature on Ubuntu (default scenario).
set -e

source dev-container-features-test-lib

check "CMDSTAN env var is set" bash -c 'test -n "${CMDSTAN}"'
check "CMDSTAN directory exists" bash -c 'test -d "${CMDSTAN}"'
check "stanc compiler is present in CMDSTAN/bin" bash -c 'test -x "${CMDSTAN}/bin/stanc"'
check "stansummary is present in CMDSTAN/bin" bash -c 'test -x "${CMDSTAN}/bin/stansummary"'
check "stanc is on PATH" bash -c 'command -v stanc'
check "stanc --version works" bash -c 'stanc --version'
check "current symlink exists" bash -c 'test -L /opt/cmdstan/current'
check "profile.d script exists" bash -c 'test -f /etc/profile.d/cmdstan.sh'
check "CMDSTAN is in /etc/environment" bash -c 'grep -q "^CMDSTAN=" /etc/environment'

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
model="$work_dir/minimal"
output="$work_dir/output.csv"
cat > "${model}.stan" <<'EOF'
generated quantities {
  real smoke_value = 42;
}
EOF

check "minimal Stan model compiles" make -C "$CMDSTAN" "$model"
check "compiled Stan model executes" "$model" sample algorithm=fixed_param num_warmup=0 num_samples=1 output file="$output"
check "CmdStan output contains expected result" awk -F, '
  /^#/ { next }
  !header {
    for (i = 1; i <= NF; i++) if ($i == "smoke_value") column = i
    header = 1
    next
  }
  column && $column == 42 { found = 1; exit }
  END { exit !found }
' "$output"

reportResults
