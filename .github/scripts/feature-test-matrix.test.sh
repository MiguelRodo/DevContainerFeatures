#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
selector="$script_dir/feature-test-matrix.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/src"/{apptainer,fit-sne,utils,mermaid,repos,build-info,cmdstan,github-tokens,renv-cache} \
    "$fixture/test/_global"
for feature in apptainer fit-sne utils mermaid repos build-info cmdstan github-tokens renv-cache; do
    printf '{"id":"%s"}\n' "$feature" > "$fixture/src/$feature/devcontainer-feature.json"
done
printf '%s\n' '{
  "all": {"features": {"apptainer": {}, "fit-sne": {}, "utils": {}}},
  "apptainer_debian": {"features": {"apptainer": {}}},
  "fit_sne_debian": {"features": {"fit-sne": {}}},
  "utils_debian": {"features": {"utils": {}}},
  "build_info_default": {"features": {"build-info": {}}},
  "cmdstan_default": {"features": {"cmdstan": {}}},
  "github-tokens": {"features": {"github-tokens": {}}},
  "github-tokens-functions": {"features": {"github-tokens": {}}},
  "renv-cache": {"features": {"renv-cache": {}}},
  "renv-cache-restore": {"features": {"renv-cache": {}}},
  "renv-cache-pak": {"features": {"renv-cache": {}}},
  "mermaid_default": {"features": {"mermaid": {}}},
  "mermaid_custom_user": {"features": {"mermaid": {}}}
}' > "$fixture/test/_global/scenarios.json"

result=$(printf 'src/mermaid/install.sh\0' | bash "$selector" full changed "$fixture")
jq -e '.include | map(.feature) | sort == ["mermaid"]' <<< "$result" >/dev/null
jq -e '.include[] | select(.feature == "mermaid") | .filters == ["mermaid"]' \
    <<< "$result" >/dev/null

result=$(printf 'src/apptainer/install.sh\0' | bash "$selector" full changed "$fixture")
jq -e '.include | map(.feature) | sort == ["apptainer", "shared integration"]' \
    <<< "$result" >/dev/null
jq -e '.include[] | select(.feature == "shared integration") | .filters == ["all"]' \
    <<< "$result" >/dev/null

result=$(bash "$selector" light mermaid "$fixture" </dev/null)
jq -e '.include | length == 1 and .[0].feature == "mermaid" and .[0].filters == ["mermaid_default"]' \
    <<< "$result" >/dev/null

result=$(bash "$selector" light all "$fixture" </dev/null)
jq -e '.include | map(.feature) | sort == ["apptainer", "build-info", "cmdstan", "fit-sne", "github-tokens", "mermaid", "renv-cache", "utils"]' \
    <<< "$result" >/dev/null
jq -e '.include[] | select(.feature == "renv-cache") | .filters == ["renv-cache"]' \
    <<< "$result" >/dev/null

result=$(printf 'test/_global/build_info_default.sh\0' | bash "$selector" full changed "$fixture")
jq -e '.include | map(.feature) == ["build-info"]' <<< "$result" >/dev/null

result=$(printf 'docs/mermaid.qmd\0' | bash "$selector" full changed "$fixture")
jq -e '.include | length == 1 and .[0].feature == "none"' <<< "$result" >/dev/null

result=$(printf 'src/mermaid/README.md\0' | bash "$selector" full changed "$fixture")
jq -e '.include | length == 1 and .[0].feature == "none"' <<< "$result" >/dev/null

result=$(printf 'test/unmapped/helper.sh\0' | bash "$selector" full changed "$fixture")
jq -e '.include | map(.feature) | sort == ["apptainer", "build-info", "cmdstan", "fit-sne", "github-tokens", "mermaid", "renv-cache", "shared integration", "utils"]' \
    <<< "$result" >/dev/null

result=$(printf 'test/_global/mermaid_invalid_user.sh\0' | bash "$selector" full changed "$fixture")
jq -e '.include | map(.feature) == ["mermaid"]' <<< "$result" >/dev/null

echo "Feature test matrix checks passed."
