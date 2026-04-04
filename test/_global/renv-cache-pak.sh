#!/bin/bash

# Test file for renv-cache feature with pak integration
#
# Verifies that the renv global cache is correctly populated and accessible
# when pak is used as the renv installation backend (usePak=true).
#
# This test can be run with the following command (from the root of this repo)
#    devcontainer features test --global-scenarios-only . --filter renv-cache-pak

set -e

source dev-container-features-test-lib

echo "🧪 Testing renv-cache with pak backend"

# Basic availability checks
check "R is installed" bash -c "command -v R"
check "Rscript is available" bash -c "command -v Rscript"
check "renv is installed" Rscript -e "if (!requireNamespace('renv', quietly = TRUE)) quit(status = 1)"
check "renvvv is installed" Rscript -e "if (!requireNamespace('renvvv', quietly = TRUE)) quit(status = 1)"
check "pak is installed" Rscript -e "if (!requireNamespace('pak', quietly = TRUE)) quit(status = 1)"

# Check that renv cache directory exists and is writable
check "renv cache directory exists" test -d "/renv/cache"
check "renv cache directory is writable" test -w "/renv/cache"

# Print renv cache path for debugging
echo "🔍 Checking renv cache configuration..."
Rscript -e "cat('RENV_PATHS_CACHE:', renv::paths\$cache(), '\n')"

# Create a test project with a simple renv.lock file
echo "📦 Creating test project with renv.lock..."
TEST_PROJECT_DIR="/tmp/test-renv-pak-project"
mkdir -p "$TEST_PROJECT_DIR"
cd "$TEST_PROJECT_DIR"

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
    },
    "renv": {
      "Package": "renv",
      "Version": "1.0.3",
      "Source": "Repository",
      "Repository": "CRAN",
      "Requirements": [
        "utils"
      ],
      "Hash": "26d0fd4d4b4a9a9e17c7a4b7c60a57e7"
    }
  }
}
EOF

check "renv.lock file created" test -f "$TEST_PROJECT_DIR/renv.lock"

# Initialize renv project
echo "🔧 Initializing renv project..."
Rscript -e "renv::activate()"

# Restore packages using pak backend
echo "⬇️  Restoring packages with pak backend (RENV_CONFIG_PAK_ENABLED=TRUE)..."
RENV_CONFIG_PAK_ENABLED=TRUE Rscript -e "
    tryCatch(
        renv::restore(prompt = FALSE),
        error = function(e) {
            message('[WARN] restore failed: ', e)
            quit(status = 1)
        }
    )
"

# Check that jsonlite was installed
check "jsonlite installed after pak restore" Rscript -e "if (!requireNamespace('jsonlite', quietly = TRUE)) quit(status = 1)"

# Rehash the renv cache (mirrors what renv-restore does with --pak)
echo "🔄 Rehashing renv cache..."
Rscript -e "
    tryCatch(
        { renv::rehash(); message('[OK] rehash complete.') },
        error = function(e) message('[WARN] rehash failed: ', e)
    )
"

# Verify the package is in the renv cache
echo "🔍 Checking renv cache contents after pak restore..."
CACHE_DIR="/renv/cache"
check "jsonlite exists in renv cache after pak restore" bash -c "find $CACHE_DIR -type d -name 'jsonlite' | grep -q jsonlite"

echo "✅ Found jsonlite in cache:"
find "$CACHE_DIR" -type d -name 'jsonlite' | head -5

# Simulate what happens at container startup: renv looks up the cache
echo "🧹 Testing cache-based restoration (simulating container startup)..."
RENV_LIB_DIR="$TEST_PROJECT_DIR/renv/library"
if [ -d "$RENV_LIB_DIR" ]; then
    echo "Removing project library to test cache-only restoration..."
    rm -rf "$RENV_LIB_DIR"
fi

# Re-activate so renv re-establishes library paths
Rscript -e "renv::activate()"

# Restore again - should link from cache without downloading
echo "⬇️  Restoring from cache (pak backend)..."
RENV_CONFIG_PAK_ENABLED=TRUE Rscript -e "
    tryCatch(
        renv::restore(prompt = FALSE),
        error = function(e) {
            message('[WARN] restore from cache failed: ', e)
            quit(status = 1)
        }
    )
"

check "jsonlite restored from renv cache" Rscript -e "if (!requireNamespace('jsonlite', quietly = TRUE)) quit(status = 1)"

# Verify the cache has correct permissions
check "renv cache is readable and executable" bash -c "test -r $CACHE_DIR && test -x $CACHE_DIR"

# Verify we can actually use the installed package
check "jsonlite usable after pak-based restore" Rscript -e "library(jsonlite); x <- toJSON(list(a=1, b=2)); if(is.null(x)) quit(status=1)"

# Clean up
cd /
rm -rf "$TEST_PROJECT_DIR"

echo "✅ All pak cache tests passed!"

reportResults
