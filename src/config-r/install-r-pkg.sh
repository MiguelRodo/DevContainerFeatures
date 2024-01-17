#!/usr/bin/env bash
# Last modified: 2024 January 10

# 1. ensure that key VS Code packages are up to date.
# and does not take long to install.

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)" 

pushd "$HOME"
Rscript -e 'Sys.setenv("RENV_CONFIG_PAK_ENABLED" = "false")' \
  -e 'install.packages(c("jsonlite", "languageserver", "pak", "renv"))'
popd
