#!/usr/bin/env bash

# Exit immediately if an error occurs
set -e

# Determine the path to the system-wide Renviron.site using R itself
if command -v Rscript >/dev/null 2>&1; then
    RENVSITE=$(Rscript -e "cat(file.path(R.home(), 'etc', 'Renviron.site'))")
else
    echo "R is not installed or not found in PATH"
    exit 1
fi

# Define the workspace directory
workspace_dir="/workspaces"

# Append the environment variables to Renviron.site
cat << EOF | tee -a "$RENVSITE"
# Set R library paths and renv variables
RENV_PATHS_ROOT=${workspace_dir}/.local/renv
RENV_PATHS_LIBRARY_ROOT=${workspace_dir}/.local/lib/R/library
RENV_PATHS_CACHE=${workspace_dir}/.cache/renv:/renv/cache
R_LIBS=${workspace_dir}/.local/lib/R
EOF

# Create the necessary directories
mkdir -p "/renv/cache"
mkdir -p "${workspace_dir}/.cache/R/pkgcache/pkg" # pak cache directory
mkdir -p ${workspace_dir}/.local/lib/R/library
mkdir -p "${workspace_dir}/.local/renv"
mkdir -p "${workspace_dir}/.cache/renv"

# Note: Set permissive permissions to allow access regardless of UID changes
# The updateUID step may change the remote user's UID after this script runs
chmod -R 777 "/renv/cache" "${workspace_dir}/.cache" "${workspace_dir}/.local"

echo "[OK] R library paths and renv variables have been set in $RENVSITE"
