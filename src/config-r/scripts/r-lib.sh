#!/usr/bin/env bash

# Exit immediately if an error occurs
set -e

# Determine the path to the R executable
R_PATH=$(which R)

# Define the path to the system-wide Renviron file based on the R installation path
if [[ -n "$R_PATH" ]]; then
    R_BASE_DIR=$(dirname $(dirname "$R_PATH"))
    RENVSITE="$R_BASE_DIR/lib/R/etc/Renviron.site"
else
    echo "R is not installed or not found in PATH"
    exit 1
fi

# Create the Renviron.site file if it doesn't exist
if [[ ! -f "$RENVSITE" ]]; then
    echo "Creating system-wide Renviron.site file at $RENVSITE"
    mkdir -p "$(dirname "$RENVSITE")"
    touch "$RENVSITE"
fi

# Define the workspace directory
workspace_dir="/workspaces"

# Append the environment variables to Renviron.site
cat << EOF | tee -a "$RENVSITE"
# Set R library paths and renv variables
RENV_PATHS_ROOT=/renv/local
RENV_PATHS_LIBRARY_ROOT=${workspace_dir}/.local/lib/R/library
RENV_PATHS_CACHE=/renv/cache
R_LIBS=${workspace_dir}/.local/lib/R
EOF

# Create the necessary directories
mkdir -p "/renv/local"
mkdir -p "/renv/cache"
mkdir -p "${workspace_dir}/.cache/R/pkgcache/pkg" # pak cache directory
mkdir -p ${workspace_dir}/.local/lib/R/library

echo "✅ R library paths and renv variables have been set in $RENVSITE"
