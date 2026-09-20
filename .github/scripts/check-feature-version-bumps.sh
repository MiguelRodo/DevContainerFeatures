#!/usr/bin/env bash
set -euo pipefail

base=${1:?"usage: $0 BASE [HEAD]"}
head=${2:-HEAD}

git rev-parse --verify "${base}^{commit}" >/dev/null
git rev-parse --verify "${head}^{commit}" >/dev/null

failed=0
while IFS= read -r feature; do
    metadata="src/${feature}/devcontainer-feature.json"

    # New or removed features have no previous published version to compare.
    git cat-file -e "${base}:${metadata}" 2>/dev/null || continue
    git cat-file -e "${head}:${metadata}" 2>/dev/null || continue

    old_version=$(git show "${base}:${metadata}" | jq -er '.version')
    new_version=$(git show "${head}:${metadata}" | jq -er '.version')

    if [[ ${old_version} == "${new_version}" ]]; then
        echo "::error file=${metadata}::${feature} shipped files changed but version is still ${new_version}. Bump ${metadata}."
        failed=1
    fi
done < <(
    git diff --name-only "${base}" "${head}" -- src/ |
        awk -F/ '$1 == "src" && NF >= 3 && $0 !~ /\.md$/ { print $2 }' |
        sort -u
)

exit "${failed}"
