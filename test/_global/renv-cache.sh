#!/bin/bash

# Test file for renv-cache feature with renvvv integration
#
# This test file is executed against a running container constructed
# from the value of 'renv-cache' in the tests/_global/scenarios.json file.
#
# This test can be run with the following command (from the root of this repo)
#    devcontainer features test --global-scenarios-only .

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.

# Check that R is available
check "R is installed" bash -c "command -v R"
check "Rscript is available" bash -c "command -v Rscript"

# Check that renv-cache scripts are installed
check "renv-cache-post-create exists" bash -c "test -f /usr/local/bin/renv-cache-post-create"
check "renv-cache-post-create is executable" bash -c "test -x /usr/local/bin/renv-cache-post-create"
check "renv-cache-restore exists" bash -c "test -f /usr/local/bin/renv-cache-restore"
check "renv-cache-restore is executable" bash -c "test -x /usr/local/bin/renv-cache-restore"
check "renv-cache-restore-build exists" bash -c "test -f /usr/local/bin/renv-cache-restore-build"
check "renv-cache-restore-build is executable" bash -c "test -x /usr/local/bin/renv-cache-restore-build"
check "renv-cache lockfile helper exists" bash -c "test -f /usr/local/share/renv-cache/lockfile.R"

# Verify that session-time token management scripts are NOT installed by renv-cache
# (this functionality is now provided by the separate github-tokens feature)
check "renv-cache-github-pat not installed by renv-cache" bash -c "! test -f /usr/local/bin/renv-cache-github-pat"
check "renv-cache-bashrc-d not installed by renv-cache" bash -c "! test -f /usr/local/bin/renv-cache-bashrc-d"

# Check that renvvv is installed
check "renvvv is installed" Rscript -e "if (!requireNamespace('renvvv', quietly = TRUE)) quit(status = 1)"

# Check that remotes is installed (required for installing renvvv)
check "remotes is installed" Rscript -e "if (!requireNamespace('remotes', quietly = TRUE)) quit(status = 1)"

# Check that renv is installed
check "renv is installed" Rscript -e "if (!requireNamespace('renv', quietly = TRUE)) quit(status = 1)"

cat > /tmp/renv-cache-lockfile-test.R <<'EOF'
source("/usr/local/share/renv-cache/lockfile.R")

exclude_lock <- tempfile(fileext = ".lock")
writeLines(c(
  "{",
  "  \"R\": {\"Version\": \"4.4.0\", \"Repositories\": [{\"Name\": \"CRAN\", \"URL\": \"https://cloud.r-project.org\"}]},",
  "  \"Packages\": {",
  "    \"skip\": {\"Package\": \"skip\", \"Version\": \"1.0.0\", \"Source\": \"Repository\", \"Repository\": \"CRAN\"},",
  "    \"child\": {\"Package\": \"child\", \"Version\": \"1.0.0\", \"Source\": \"Repository\", \"Repository\": \"CRAN\", \"Requirements\": [\"skip\"]},",
  "    \"grandchild\": {\"Package\": \"grandchild\", \"Version\": \"1.0.0\", \"Source\": \"Repository\", \"Repository\": \"CRAN\", \"Requirements\": [\"child\"]},",
  "    \"keep\": {\"Package\": \"keep\", \"Version\": \"1.0.0\", \"Source\": \"Repository\", \"Repository\": \"CRAN\"}",
  "  }",
  "}"
), exclude_lock)

exclude_result <- renv_cache_exclude_packages(renv::lockfile_read(exclude_lock), "skip")
stopifnot(
  setequal(exclude_result$skipped, c("skip", "child", "grandchild")),
  identical(names(exclude_result$lockfile$Packages), "keep"),
  isTRUE(exclude_result$write_lockfile)
)
renv::lockfile_write(exclude_result$lockfile, exclude_lock)
stopifnot(identical(names(renv::lockfile_read(exclude_lock)$Packages), "keep"))

force_lock <- tempfile(fileext = ".lock")
writeLines(c(
  "{",
  "  \"R\": {\"Version\": \"4.4.0\", \"Repositories\": [{\"Name\": \"CRAN\", \"URL\": \"https://cloud.r-project.org\"}]},",
  "  \"Packages\": {",
  "    \"cached\": {\"Package\": \"cached\", \"Version\": \"1.0.0\", \"Source\": \"Repository\", \"Repository\": \"CRAN\", \"Hash\": \"old\"},",
  "    \"present\": {\"Package\": \"present\", \"Version\": \"1.0.0\", \"Source\": \"CRAN\", \"Hash\": \"present-old\"},",
  "    \"githubpkg\": {\"Package\": \"githubpkg\", \"Version\": \"1.0.0\", \"Source\": \"GitHub\", \"RemoteUsername\": \"example\", \"RemoteRepo\": \"githubpkg\", \"Hash\": \"github-old\"}",
  "  }",
  "}"
), force_lock)

cache_path <- tempfile("renv-cache-")
dir.create(file.path(cache_path, "cached", "1.5.0", "hash-15"), recursive = TRUE)
dir.create(file.path(cache_path, "cached", "2.0.0", "hash-20"), recursive = TRUE)
dir.create(file.path(cache_path, "present", "1.0.0", "present-hash"), recursive = TRUE)
dir.create(file.path(cache_path, "present", "2.0.0", "present-newer"), recursive = TRUE)
dir.create(file.path(cache_path, "githubpkg", "3.0.0", "github-newer"), recursive = TRUE)

force_result <- renv_cache_force_cached_versions(renv::lockfile_read(force_lock), cache_path)
stopifnot(
  isTRUE(force_result$changed),
  identical(force_result$lockfile$Packages$cached$Version, "2.0.0"),
  identical(force_result$lockfile$Packages$cached$Hash, "hash-20"),
  identical(force_result$lockfile$Packages$present$Version, "1.0.0"),
  identical(force_result$lockfile$Packages$present$Hash, "present-old"),
  identical(force_result$lockfile$Packages$githubpkg$Version, "1.0.0"),
  identical(force_result$lockfile$Packages$githubpkg$Hash, "github-old")
)
renv::lockfile_write(force_result$lockfile, force_lock)
force_roundtrip <- renv::lockfile_read(force_lock)
stopifnot(
  identical(force_roundtrip$Packages$cached$Version, "2.0.0"),
  identical(force_roundtrip$Packages$cached$Hash, "hash-20")
)
EOF

check "lockfile transformations use public renv round-trips" Rscript /tmp/renv-cache-lockfile-test.R
rm -f /tmp/renv-cache-lockfile-test.R

# Test that renv-restore help works
check "restore help works" bash -c "/usr/local/bin/renv-cache-restore --help"

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
