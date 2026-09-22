#!/bin/bash
set -e

source dev-container-features-test-lib

make_fixture_repo() {
    local root=$1
    git init -q "$root/source"
    git -C "$root/source" config user.email test@example.com
    git -C "$root/source" config user.name "Dev Container test"
    printf 'fixture\n' > "$root/source/probe.txt"
    git -C "$root/source" add probe.txt
    git -C "$root/source" commit -qm fixture
    git clone -q --bare "$root/source" "$root/fixture.git"
}

test_versions() {
    test "$(repos --version)" = "repos version 2.7.1"
    test "$(setupmjr --version)" = "setupmjr version 0.7.5"
}

test_repos_clone() (
    set -e
    local tmp
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    make_fixture_repo "$tmp"
    mkdir "$tmp/workspace"
    printf 'file://%s fixture\n' "$tmp/fixture.git" > "$tmp/workspace/repos.list"
    cd "$tmp/workspace"
    repos clone
    test "$(cat fixture/probe.txt)" = fixture
)

test_setupmjr() (
    set -e
    local tmp
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    mkdir "$tmp/home"
    HOME="$tmp/home" setupmjr bash rc.d
    test -d "$tmp/home/.bashrc.d"
    grep -Fq '.bashrc.d' "$tmp/home/.bashrc"
)

test_run_on_start() (
    set -e
    local tmp
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    make_fixture_repo "$tmp"
    mkdir "$tmp/workspace"
    printf 'file://%s fixture\n' "$tmp/fixture.git" > "$tmp/workspace/repos.list"
    cd "$tmp/workspace"
    /usr/local/bin/utils-post-start
    test "$(cat fixture/probe.txt)" = fixture
)

check "default versions are pinned" test_versions
check "repos clones a local repository" test_repos_clone
check "setupmjr configures bash rc.d" test_setupmjr
check "runOnStart clones repos.list" test_run_on_start

reportResults
