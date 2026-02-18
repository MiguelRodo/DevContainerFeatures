#!/bin/bash

# Test file for config-r feature with renv cache verification
#
# This test file is executed against a running container constructed
# from the value of 'config-r-cache' in the tests/_global/scenarios.json file.
#
# This test can be run with the following command (from the root of this repo)
#    devcontainer features test --global-scenarios-only .

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.

echo "🧪 Testing config-r renv cache functionality"

# Check that R is available
check "R is installed" bash -c "which R"
check "Rscript is available" bash -c "which Rscript"

# Check that renv is installed
check "renv is installed" Rscript -e "if (!requireNamespace('renv', quietly = TRUE)) quit(status = 1)"

# Check that renvvv is installed
check "renvvv is installed" Rscript -e "if (!requireNamespace('renvvv', quietly = TRUE)) quit(status = 1)"

# Check that renv cache directory exists and is configured
check "renv cache directory exists" test -d "/renv/cache"

# Print renv cache path for debugging
echo "🔍 Checking renv cache configuration..."
Rscript -e "cat('RENV_PATHS_CACHE:', renv::paths\$cache(), '\n')"

# Create a test project with renv.lock file
echo "📦 Creating test project with renv.lock..."
TEST_PROJECT_DIR="/tmp/test-renv-project"
mkdir -p "$TEST_PROJECT_DIR"
cd "$TEST_PROJECT_DIR"

# Create a simple renv.lock file with a small package (jsonlite)
cat > renv.lock << 'EOF'
{
  "R": {
    "Version": "4.4.0",
    "Repositories": [
      {
        "Name": "CRAN",
        "URL": "https://cloud.r-project.org"
      }
    ]
  },
  "Packages": {
    "jsonlite": {
      "Package": "jsonlite",
      "Version": "1.8.8",
      "Source": "Repository",
      "Repository": "CRAN",
      "Requirements": [
        "R"
      ],
      "Hash": "e1b9c55281c5adc4dd113652d9e26768"
    }
  }
}
EOF

check "renv.lock file created" test -f "$TEST_PROJECT_DIR/renv.lock"

# Initialize renv project
echo "🔧 Initializing renv project..."
Rscript -e "renv::activate()"

# Restore packages using renv (this should populate the cache)
echo "⬇️  Restoring packages from renv.lock..."
Rscript -e "renv::restore(prompt = FALSE)"

# Check that jsonlite was installed
check "jsonlite installed after restore" Rscript -e "if (!requireNamespace('jsonlite', quietly = TRUE)) quit(status = 1)"

# Verify that the package exists in the renv cache
echo "🔍 Checking renv cache contents..."
CACHE_DIR="/renv/cache"

# The cache should contain the jsonlite package
# renv cache structure is typically: /renv/cache/v5/R-4.4/<platform>/jsonlite/1.8.8/<hash>
# We'll check if jsonlite appears anywhere in the cache
check "jsonlite exists in renv cache" bash -c "find $CACHE_DIR -type d -name 'jsonlite*' | grep -q jsonlite"

echo "✅ Found jsonlite in cache:"
find $CACHE_DIR -type d -name 'jsonlite*' | head -5

# Test cache restoration by removing the project library and restoring from cache
echo "🧹 Testing cache restoration..."
RENV_LIB_DIR="$TEST_PROJECT_DIR/renv/library"
if [ -d "$RENV_LIB_DIR" ]; then
    echo "Removing project library to test cache restoration..."
    rm -rf "$RENV_LIB_DIR"
fi

# Restore again - this time it should use the cache
echo "⬇️  Restoring from cache..."
Rscript -e "renv::restore(prompt = FALSE)"

# Verify jsonlite is available again (restored from cache)
check "jsonlite restored from cache" Rscript -e "if (!requireNamespace('jsonlite', quietly = TRUE)) quit(status = 1)"

# Verify the cache directory has appropriate permissions
check "renv cache has correct permissions" bash -c "test -r $CACHE_DIR && test -w $CACHE_DIR && test -x $CACHE_DIR"

# Test that we can use the installed package
echo "🧪 Testing installed package functionality..."
check "jsonlite can be loaded and used" Rscript -e "library(jsonlite); x <- toJSON(list(a=1, b=2)); if(is.null(x)) quit(status=1)"

# Clean up
cd /
rm -rf "$TEST_PROJECT_DIR"

echo "✅ All renv cache tests passed!"

# Report result
reportResults
