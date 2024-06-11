#!/usr/bin/env bash

set -e

path_config_r_bashrc="/usr/local/bin/config-r-bashrc-d"
cat > "$path_config_r_bashrc" \
<< 'EOF'
#!/usr/bin/env bash

# set up bashrc_d:
# - ensure it exists
# - ensure it is sourced once by `~/.bashrc`
config_bashrc_d() {
  echo "Configuring bashrc.d"
  # ensure that `.bashrc.d` files are sourced in
  if [ -e "$HOME/.bashrc" ]; then 
    # we assume that if `.bashrc.d` is mentioned
    # in `$HOME/.bashrc`, then it's sourced in
    if [ -z "$(cat "$HOME/.bashrc" | grep -F bashrc.d)" ]; then 
      # if it can't pick up `.bashrc.d`, tell it to
      # source all files inside `.bashrc.d`
      echo 'for i in $(ls -A $HOME/.bashrc.d/); do source $HOME/.bashrc.d/$i; done' \
        >> "$HOME/.bashrc"
    fi
  else
    # create bashrc if it doesn't exist, and tell it to source
    # all files in `.bashrc.d`
    touch "$HOME/.bashrc"
    echo 'for i in $(ls -A $HOME/.bashrc.d/); do source $HOME/.bashrc.d/$i; done' \
      > "$HOME/.bashrc"
  fi
  mkdir -p "$HOME/.bashrc.d"
  echo "Completed configuring bashrc.d"
}

# copy files from inside `/var/tmp/<folder>` to `~/.bashrc.d`
add_to_bashrc_d() {
    local source_dir="/var/tmp/$1"
    local dest_dir="$HOME/.bashrc.d"

    # Check if the source directory exists
    if [[ ! -d "$source_dir" ]]; then
        echo "Error: Directory '$source_dir' not found."
        return 1  # Exit with an error code
    fi

    # Check if the destination directory exists, create it if not
    mkdir -p "$dest_dir"

    # Find files in the source directory and copy them to the destination
    for file in "$source_dir"/*; do
        if [[ -f "$file" ]]; then    # Check if it's a regular file
            echo "Adding $(basename "$file")"
            cp "$file" "$dest_dir/" 
        fi
    done

    echo "Completed adding files from '$source_dir' to '$dest_dir'"

    # Optionally, remove the source directory and its contents:
    sudo rm -rf "$source_dir" 
}

config_bashrc_d
add_to_bashrc_d devcontainer-feature/bashrc-d

EOF

chmod +x "$path_config_r_bashrc"

# =======================================================
# add files to /var/tmp/devcontainer-feature/bashrc-d to be copied to `~/.bashrc.d`
# =======================================================

# directory for files to be added to
path_dir_tmp_bashrc_d="/var/tmp/devcontainer-feature/bashrc-d"
mkdir -p "$path_dir_tmp_bashrc_d"

# set R libraries
# -------------------------

path_r_env_lib="$path_dir_tmp_bashrc_d/config-r-env-lib"
cat > "$path_r_env_lib" \
<< 'EOF'
SET_R_LIB_PATHS="${SET_R_LIB_PATHS:-true}"
# save all R packages to /workspace directories.
# Avoids having to reinstall R packages after 
# every container start for GitPod, and
# after image rebuilds for VS Code.
if [ "$SET_R_LIB_PATHS" = "true" ]; then
    workspace_dir="/workspaces"
    export R_LIBS=${R_LIBS:="$workspace_dir/.local/lib/R"}
    export RENV_PATHS_CACHE=${RENV_PATHS_CACHE:="$workspace_dir/.local/R/lib/renv"}
    export RENV_PATHS_LIBRARY_ROOT=${RENV_PATHS_LIBRARY_ROOT:="$workspace_dir/.local/.cache/R/renv"}
    export RENV_PATHS_LIBRARY=${RENV_PATHS_LIBRARY:="$workspace_dir/.local/.cache/R/renv"}
    export RENV_PREFIX_AUTO=${RENV_PREFIX_AUTO:=TRUE}
    export RENV_CONFIG_PAK_ENABLED=${RENV_CONFIG_PAK_ENABLED:=TRUE}
    # ensure R_LIBS is created (so
    # that one never tries to install packages
    # into a singularity/apptainer container)
    mkdir -p "$R_LIBS"
fi
EOF

chmod +x "$path_r_env_lib"

source "$path_r_env_lib"

test -f "$path_r_env_lib" && \
  echo "path_r_env_lib exists" || \
  echo "path_r_env_lib does not exist"

# =======================================================
# add scripts that are merely sourced
# =======================================================

path_config_r_bashrc_non="/usr/local/bin/config-r-bashrc-d-non"

cat > "$path_config_r_bashrc_non" \
<< 'EOF'
#!/usr/bin/env bash
EOF

# radian settings
# ---------------------
if [ "$RADIAN_AUTO_MATCH" = "true" ]; then

cat >> "$path_config_r_bashrc_non" \
<< 'EOF'

# ensure that radian works (at least on ephemeral dev
# environments)
if ! [ -e "$HOME/.radian_profile" ]; then touch "$HOME/.radian_profile"; fi
if [ -z "$(cat "$HOME/.radian_profile" | grep -E 'options\(\s*radian\.auto_match')" ]; then 
  echo "Setting `auto_match` to `FALSE` for radian"
  echo 'options(radian.auto_match = FALSE)' >> "$HOME/.radian_profile"
fi

EOF

fi

# linting settings
# ---------------------
if [ "$LIGHTEN_LINTING" = "true" ]; then

cat >> "$path_config_r_bashrc_non" \
<< 'EOF'

if [ ! -f "$HOME/.lintr" ]; then
  echo "linters: linters_with_defaults(
  object_length_linter = NULL,
  object_name_linter = NULL)
" > "$HOME/.lintr"
echo "Made linting not check for camel/snake case and object name length"
fi

EOF

fi

chmod +x "$path_config_r_bashrc_non"

# =======================================================
# add script that sources both above scripts
# =======================================================

path_config_r=/usr/local/bin/config-r
cat > "$path_config_r" \
<< 'EOF'
#!/usr/bin/env bash
config-r-bashrc-d
config-r-bashrc-d-non
EOF

chmod +x "$path_config_r"
