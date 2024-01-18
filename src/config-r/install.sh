#!/usr/bin/env bash

set -e

# ------------------------
# Configure R
# ------------------------

cat > /usr/local/bin/config-r \
<< 'EOF'
#!/usr/bin/env bash

# Script for configuring the R environment in GitHub Codespaces or GitPod
# - Ensures GH_TOKEN, GITHUB_TOKEN and GITHUB_PAT are all set
#   for GitHub API access.
# - In GitPod/Codespace, stores R packages in a workspace directory to
#   persist them across sessions. Only really necessary for GitPod
# - Ensures radian works in GitPod/Codespace (without 
#   turning off auto_match, multiline interactive code does not run
#   correctly)
# - Configures R_LIBS directory for package installations
#   outside of container environments.
# - Making linting less aggressive
#   - Ignore object length and snake/camel case
# - Ensure key R packages up to date

# github token
if [ -n "$GH_TOKEN" ]; then 
  export GITHUB_PAT="${GITHUB_PAT:-"$GH_TOKEN"}"
  export GITHUB_TOKEN="${GITHUB_PAT:-"$GH_TOKEN"}"
elif [ -n "$GITHUB_PAT" ]; then 
  export GH_TOKEN="${GH_TOKEN:-"$GITHUB_PAT"}"
  export GITHUB_TOKEN="${GITHUB_TOKEN:-"$GITHUB_PAT"}"
elif [ -n "$GITHUB_TOKEN" ]; then 
  export GH_TOKEN="${GH_TOKEN:-"$GITHUB_TOKEN"}"
  export GITHUB_PAT="${GITHUB_PAT:-"$GITHUB_TOKEN"}"
fi

# save all R packages to /workspace directories.
# Especially important on GitPod to avoid having to
# reinstall upon container restarts
if [ -n "$(env | grep -E "^GITPOD|^CODESPACE")" ]; then
    if [ -n "$(env | grep -E "^GITPOD")" ]; then
      workspace_dir="/workspace"
    else
      workspace_dir="/workspaces"
    fi
    export R_LIBS=${R_LIBS:="$workspace_dir/.local/lib/R"}
    export RENV_PATHS_CACHE=${RENV_PATHS_CACHE:="$workspace_dir/.local/R/lib/renv"}
    export RENV_PATHS_LIBRARY_ROOT=${RENV_PATHS_LIBRARY_ROOT:="$workspace_dir/.local/.cache/R/renv"}
    export RENV_PATHS_LIBRARY=${RENV_PATHS_LIBRARY:="$workspace_dir/.local/.cache/R/renv"}
    export RENV_PREFIX_AUTO=${RENV_PREFIX_AUTO:=TRUE}
    export RENV_CONFIG_PAK_ENABLED=${RENV_CONFIG_PAK_ENABLED:=TRUE}
else
    export R_LIBS=${R_LIBS:="$HOME/.local/lib/R"}
fi

# ensure R_LIBS is created (so
# that one never tries to install packages
# into a singularity/apptainer container)
mkdir -p "$R_LIBS"

# ensure that radian works (at least on ephemeral dev
# environments)
if [ -n "$(env | grep -E "^GITPOD|^CODESPACE")" ]; then
  if ! [ -e "$HOME/.radian_profile" ]; then touch "$HOME/.radian_profile"; fi
  if [ "$GITHUB_USER" = "MiguelRodo" ] || [ "$GITPOD_GIT_USER_NAME" = "Miguel Rodo" ]; then 
    if [ -z "$(cat "$HOME/.radian_profile" | grep -E 'options\(\s*radian\.editing_mode')" ]; then 
      echo 'options(radian.editing_mode = "vi")' >> "$HOME/.radian_profile"
    fi
  fi
  if [ -z "$(cat "$HOME/.radian_profile" | grep -E 'options\(\s*radian\.auto_match')" ]; then 
    echo 'options(radian.auto_match = FALSE)' >> "$HOME/.radian_profile"
  fi
fi

# set linting settings
# light: just don't warn about snake case / camel case
# (which it often gets wrong) and object name
# length (which I often want to make very long)
if [ ! -f "$HOME/.lintr" ]; then
  echo "linters: with_defaults(
  object_length_linter = NULL,
  object_name_linter = NULL)
" > "$HOME/.lintr"
fi

EOF

chmod +x /usr/local/bin/config-r

echo "source /usr/local/bin/config-r" >> "$HOME/.bashrc"

/usr/local/bin/config-r

# ------------------------
# Config R for VS Code
# ------------------------

cat > /usr/local/bin/config-r-vscode \
<< 'EOF'
#!/usr/bin/env bash
# Last modified: 2023 Nov 30

# This script is used to configure R settings in Visual Studio Code (VSCode) for GitPod or Codespace environments.
# It sets the `r.libPaths` VS Code settings to the default `.libPaths()` output
# when not using `renv`, as this is where the R packages
# that the VS Code extensions depend on (e.g. languageserver) are installed.
# If you do not do this, then you might get many warnings about these packages
# not being installed, even though you know the are.
# It checks if the script is running in a GitPod or Codespace environment and defines the path to the JSON file accordingly.
# Then, it defines a new key and value to be added to the JSON file.
# If the key already exists in the JSON file, the script exits.
# Otherwise, it adds the key-value pair to the JSON file using the 'jq' command.

# exit if not on GitPod or Codespace
if [ -z "$(env | grep -E "^GITPOD|^CODESPACE")" ]; then
    exit 0
fi

# Define the path to your JSON file
path_rel=".vscode-remote/data/Machine/settings.json"
if [ -n "$(env | grep -E "^GITPOD")" ]; then
    path_file_json="/workspace/$path_rel"
else 
    path_file_json="/home/$USER/$path_rel"
fi

# Create the JSON file if it does not exist
if [ ! -f "$path_file_json" ]; then
    echo "{}" > "$path_file_json"
fi

# Get the current R version prepended with a forward slash
r_version=$(R --version | grep 'R version' | awk '{print $3}' | sed 's/^/\//')

# Define the new key and value you want to add
new_key="r.libPaths"

# Define a regular expression for matching version strings
version_regex="[0-9]+\.[0-9]+\.[0-9]+"

# Function to process and check the JSON file
update_json_if_needed() {
    local has_version_path=false
    local paths=( $(jq -r ".\"$new_key\"[]?" "$path_file_json") )

    for path in "${paths[@]}"; do
        if [[ "$path" =~ $version_regex ]]; then
            has_version_path=true
            if [[ "$path" =~ $r_version ]]; then
                # The current version is already in the paths, no need to update
                return 0
            fi
            break
        fi
    done

    if [[ "$has_version_path" == true ]]; then
        echo "Update r.libPaths key"
        update_json
    fi
}

update_json() {
    local new_array=$(Rscript --vanilla -e "cat(.libPaths(), sep = '\n')" | sed ':a;N;$!ba;s/\n/", "/g' | sed 's/^/["/' | sed 's/$/"]/')
    jq --arg key "$new_key" --argjson value "$new_array" '. + {($key): $value}' $path_file_json > temp.json && mv temp.json $path_file_json
}

# Check if r.libPaths exists and if the current R version is not in its values
if jq -e ". | has(\"$new_key\")" "$path_file_json" > /dev/null; then
    update_json_if_needed
else
    echo "Add r.libPaths key"
    # r.libPaths key doesn't exist, so proceed to add it
    update_json
fi

EOF

chmod +x /usr/local/bin/config-r-vscode

/usr/local/bin/config-r-vscode

# ------------------------
# Ensure typically-required R packages are updated
# ------------------------

cat > /usr/local/bin/config-r-pkg \
<< 'EOF'
#!/usr/bin/env bash
# Last modified: 2024 January 10

# 1. ensure that key VS Code packages are up to date.
# and does not take long to install.

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)" 

pushd "$HOME"
Rscript -e 'Sys.setenv("RENV_CONFIG_PAK_ENABLED" = "false")' \
  -e 'install.packages(c("jsonlite", "languageserver", "pak", "renv"))'
popd

EOF

chmod +x /usr/local/bin/config-r-pkg

/usr/local/bin/config-r-pkg


