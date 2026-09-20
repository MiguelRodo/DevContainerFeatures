#!/usr/bin/env bash
set -euo pipefail

guard_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
guard="${guard_dir}/check-feature-version-bumps.sh"
tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
cd "${tmp}"

git init -q
git config user.email test@example.com
git config user.name test
mkdir -p src/a/docs src/b
printf '%s\n' '{"version":"1.0.0"}' > src/a/devcontainer-feature.json
printf '%s\n' '{"version":"1.0.0"}' > src/b/devcontainer-feature.json
printf '%s\n' 'echo a' > src/a/install.sh
printf '%s\n' 'echo b' > src/b/install.sh
git add . && git commit -qm initial
initial=$(git rev-parse HEAD)

printf '%s\n' '# docs' > src/a/docs/README.md
git add . && git commit -qm docs
docs=$(git rev-parse HEAD)
bash "${guard}" "${initial}" "${docs}"

printf '%s\n' 'echo changed' >> src/a/install.sh
git add . && git commit -qm no-bump
no_bump=$(git rev-parse HEAD)
if bash "${guard}" "${docs}" "${no_bump}" >output 2>&1; then
    echo 'expected behaviour change without a version bump to fail'
    exit 1
fi
grep -q 'a shipped files changed' output

printf '%s\n' '{"version":"1.0.1"}' > src/a/devcontainer-feature.json
git add . && git commit -qm bumped
bumped=$(git rev-parse HEAD)
bash "${guard}" "${docs}" "${bumped}"

printf '%s\n' 'echo changed-again' >> src/a/install.sh
printf '%s\n' 'echo changed' >> src/b/install.sh
printf '%s\n' '{"version":"1.0.2"}' > src/a/devcontainer-feature.json
git add . && git commit -qm multi-feature
multi=$(git rev-parse HEAD)
if bash "${guard}" "${bumped}" "${multi}" >output 2>&1; then
    echo 'expected an unbumped feature in a multi-feature change to fail'
    exit 1
fi
grep -q 'b shipped files changed' output
