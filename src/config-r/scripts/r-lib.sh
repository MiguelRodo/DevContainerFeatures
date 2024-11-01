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
R_LIBS_USER=${workspace_dir}/.local/lib/R
RENV_PATHS_CACHE=${workspace_dir}/.local/R/lib/renv
RENV_PATHS_LIBRARY_ROOT=${workspace_dir}/.local/.cache/R/renv
RENV_PATHS_LIBRARY=${workspace_dir}/.local/.cache/R/renv
RENV_PREFIX_AUTO=TRUE
EOF
