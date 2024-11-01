#!/usr/bin/env bash

set -e

# Define the path to the system-wide Renviron file
if [[ -f "/etc/R/Renviron.site" ]]; then
    RENVSITE=/etc/R/Renviron.site
elif [[ -f "/usr/local/lib/R/etc/Renviron.site" ]]; then
    RENVSITE=/usr/local/lib/R/etc/Renviron.site
else
    echo "No system-wide .Renviron file found"
    exit 1
fi

# Define the workspace directory
workspace_dir="/workspaces"

# Append the environment variables to Renviron.site
cat << EOF | sudo tee -a "$RENVSITE"
# Set R library paths and renv variables
XDG_CACHE_HOME=${workspace_dir}/.cache
RENV_PATHS_ROOT=${workspace_dir}/.local/renv
R_LIBS=${workspace_dir}/.local/lib/R
EOF

mkdir -p ${workspace_dir}/.cache
mkdir -p ${workspace_dir}/.local/renv
mkdir -p ${workspace_dir}/.local/lib/R