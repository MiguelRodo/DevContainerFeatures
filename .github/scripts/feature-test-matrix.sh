#!/usr/bin/env bash
set -euo pipefail

mode=${1:-full}
selection=${2:-changed}
repo_root=${3:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"}
scenario_file="$repo_root/test/_global/scenarios.json"

if [[ "$mode" != full && "$mode" != light ]]; then
    echo "mode must be 'full' or 'light'" >&2
    exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to select feature test lanes" >&2
    exit 2
fi

features=()
for manifest in "$repo_root"/src/*/devcontainer-feature.json; do
    [[ -f "$manifest" ]] || continue
    features+=("$(jq -er '.id' "$manifest")")
done

if ((${#features[@]} == 0)); then
    echo "No feature manifests found under $repo_root/src" >&2
    exit 2
fi

declare -A selected=()

has_feature() {
    local candidate=$1
    local feature
    for feature in "${features[@]}"; do
        [[ "$feature" == "$candidate" ]] && return 0
    done
    return 1
}

add_feature() {
    local feature=$1
    if has_feature "$feature"; then
        selected["$feature"]=1
    else
        echo "Unknown feature '$feature' in scenario or changed path" >&2
        exit 2
    fi
}

add_all_features() {
    local feature
    for feature in "${features[@]}"; do
        # `repos` remains available for backwards compatibility, but its tests
        # are covered by the maintained `utils` scenarios.
        [[ "$feature" == repos ]] || selected["$feature"]=1
    done
}

add_scenario_features() {
    local scenario=$1
    local scenario_features
    scenario_features=$(jq -er --arg scenario "$scenario" \
        '.[$scenario].features | keys[]' "$scenario_file") || {
        echo "Scenario '$scenario' has no feature mapping" >&2
        exit 2
    }
    while IFS= read -r feature; do
        add_feature "$feature"
    done <<< "$scenario_features"
}

covered_by_filter() {
    local scenario=$1
    local filter
    for filter in "${filters_array[@]}"; do
        [[ "$scenario" == *"$filter"* ]] && return 0
    done
    return 1
}

feature_for_test_path() {
    local stem=$1
    local feature alias
    for feature in "${features[@]}"; do
        alias=${feature//-/_}
        if [[ "$stem" == "$feature" || "$stem" == "$alias" || \
              "$stem" == "$feature"_* || "$stem" == "$alias"_* || \
              "$stem" == "$feature"-* || "$stem" == "$alias"-* ]]; then
            add_feature "$feature"
            return 0
        fi
    done
    return 1
}

case "$selection" in
    all)
        add_all_features
        ;;
    changed)
        while IFS= read -r -d '' path; do
            case "$path" in
                docs/*|.agents/*|*.md|*.qmd|LICENSE)
                    ;;
                src/*/*)
                    feature=${path#src/}
                    feature=${feature%%/*}
                    if has_feature "$feature"; then
                        add_feature "$feature"
                    else
                        add_all_features
                    fi
                    ;;
                test/_global/scenarios.json|.github/workflows/*|.github/scripts/feature-test-matrix*)
                    add_all_features
                    ;;
                test/_global/*.sh)
                    scenario=${path##*/}
                    scenario=${scenario%.sh}
                    if jq -e --arg scenario "$scenario" 'has($scenario)' "$scenario_file" >/dev/null; then
                        add_scenario_features "$scenario"
                    elif ! feature_for_test_path "$scenario"; then
                        add_all_features
                    fi
                    ;;
                test/*/*)
                    test_dir=${path#test/}
                    test_dir=${test_dir%%/*}
                    if has_feature "$test_dir"; then
                        add_feature "$test_dir"
                    elif ! feature_for_test_path "$test_dir"; then
                        add_all_features
                    fi
                    ;;
                *)
                    # Unknown test or source changes are conservatively broad.
                    add_all_features
                    ;;
            esac
        done
        ;;
    *)
        if has_feature "$selection"; then
            selected["$selection"]=1
        else
            echo "selection must be 'changed', 'all', or a feature id" >&2
            exit 2
        fi
        ;;
esac

light_scenario() {
    case "$1" in
        apptainer) printf '%s' apptainer_debian ;;
        build-info) printf '%s' build_info_default ;;
        cmdstan) printf '%s' cmdstan_default ;;
        fit-sne) printf '%s' fit_sne_debian ;;
        github-tokens) printf '%s' github-tokens-functions ;;
        mermaid) printf '%s' mermaid_default ;;
        renv-cache) printf '%s' renv-cache ;;
        utils|repos) printf '%s' utils_debian ;;
        *) return 1 ;;
    esac
}

rows=()
integration_filters=()
for feature in "${features[@]}"; do
    [[ -n "${selected[$feature]:-}" ]] || continue
    scenario_feature=$feature
    [[ "$feature" == repos ]] && scenario_feature=utils

    if [[ "$mode" == light ]]; then
        filter=$(light_scenario "$feature") || {
            echo "No light scenario configured for '$feature'" >&2
            exit 2
        }
        if ! jq -e --arg scenario "$filter" --arg feature "$scenario_feature" \
            '.[$scenario].features | has($feature)' "$scenario_file" >/dev/null; then
            echo "Light scenario '$filter' does not test '$scenario_feature'" >&2
            exit 2
        fi
        filters=$(jq -cn --arg filter "$filter" '[$filter]')
    else
        scenarios=$(jq -er --arg feature "$scenario_feature" \
            '[to_entries[] | select(.value.features | has($feature)) | .key][]' "$scenario_file") || {
            echo "No scenarios configured for '$feature'" >&2
            exit 2
        }
        filters_array=()
        prefix=${scenario_feature//-/_}
        if [[ "$prefix" == "$scenario_feature" ]]; then
            prefix=$scenario_feature
        fi
        if grep -Fq "$prefix" <<< "$scenarios"; then
            filters_array+=("$prefix")
        fi
        while IFS= read -r scenario; do
            if jq -e --arg scenario "$scenario" \
                '.[$scenario].features | length > 1' "$scenario_file" >/dev/null; then
                if ! printf '%s\n' "${integration_filters[@]}" | grep -Fqx -- "$scenario"; then
                    integration_filters+=("$scenario")
                fi
            elif ! covered_by_filter "$scenario"; then
                filters_array+=("$scenario")
            fi
        done <<< "$scenarios"

        if ((${#filters_array[@]} == 0)) && [[ "$feature" != repos ]]; then
            echo "No full test filters resolved for '$feature'" >&2
            exit 2
        fi
        filters=$(printf '%s\n' "${filters_array[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
    fi

    row=$(jq -cn --arg feature "$feature" --arg mode "$mode" --argjson filters "$filters" \
        '{feature:$feature, mode:$mode, filters:$filters}')
    rows+=("$row")
done

if [[ "$mode" == full && ${#integration_filters[@]} -gt 0 ]]; then
    filters=$(printf '%s\n' "${integration_filters[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
    rows+=("$(jq -cn --arg mode "$mode" --argjson filters "$filters" \
        '{feature:"shared integration", mode:$mode, filters:$filters}')")
fi

if ((${#rows[@]} == 0)); then
    printf '%s\n' '{"include":[{"feature":"none","mode":"light","filters":[]}]}'
else
    printf '%s\n' "${rows[@]}" | jq -sc '{include:.}'
fi
