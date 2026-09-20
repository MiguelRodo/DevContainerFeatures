#!/usr/bin/env bash

cmdstan_expected_sha256() {
    local version="$1"
    case "$version" in
        2.34.1) printf '%s\n' '9a6efc817a473768cf21f1e4bb1303be7ade2e26fc971856a7f9cf0bc3355f2b'; return ;;
        2.35.0) printf '%s\n' '5bf668994e163419123d22bb7248ef1d30cbe2e7a14d50aa1c282b961f8172cd'; return ;;
        2.36.0) printf '%s\n' '464114fe5e905f0e52b595ee799b467f9ef153983a3465deff75b1e70fb74641'; return ;;
    esac

    local tarball="cmdstan-${version}.tar.gz"
    local release_json
    release_json=$(curl -sSfL "https://api.github.com/repos/stan-dev/cmdstan/releases/tags/v${version}") || return 1

    printf '%s\n' "$release_json" | awk -v name="$tarball" '
        index($0, "\"name\": \"" name "\"") { asset = 1 }
        asset && /"digest": "sha256:/ {
            sub(/^.*"digest": "sha256:/, "")
            sub(/".*$/, "")
            print
            exit
        }
    '
}

verify_cmdstan_tarball() {
    local version="$1"
    local path="$2"
    local expected

    expected=$(cmdstan_expected_sha256 "$version") || {
        echo "Error: Could not retrieve checksum metadata for CmdStan ${version}." >&2
        return 1
    }
    if [[ ! "$expected" =~ ^[0-9a-f]{64}$ ]]; then
        echo "Error: No trusted SHA-256 checksum available for CmdStan ${version}." >&2
        return 1
    fi
    if ! printf '%s  %s\n' "$expected" "$path" | sha256sum -c - >/dev/null 2>&1; then
        echo "Error: SHA-256 checksum mismatch for CmdStan ${version}." >&2
        return 1
    fi
}
