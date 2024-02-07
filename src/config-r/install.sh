#!/usr/bin/env bash

set -e

# set up .bashrc.d script for
# specifying R library paths
# -------------------------------

mkdir -p "/bashrc-d-config-r"

cat > "/bashrc-d-config-r/config-r-env-lib" \
<< 'EOF'
# save all R packages to /workspace directories.
# Avoids having to reinstall R packages after 
# every container start for GitPod, and
# after image rebuilds for VS Code.
if [ "$SET_LIB_PATHS" = "true" ]; then
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

source /bashrc-d-config-r/config-r-env-lib

test -f /bashrc-d-config-r/config-r-env-lib && \
  echo "config-r-env-lib exists" || \
  echo "config-r-env-lib does not exit"

# update typically-required R packages
update_r_pkg() {
  mkdir -p "/tmp/r-packages"
  pushd "/tmp/r-packages"
  echo "Updating R packages"
  Rscript -e "print(c('R_LIBS' = Sys.getenv('R_LIBS')))" \
  -e "print(c('RENV_PATHS_CACHE' = Sys.getenv('RENV_PATHS_CACHE')))" \
  -e "print(c('RENV_PATHS_LIBRARY_ROOT' = Sys.getenv('RENV_PATHS_LIBRARY_ROOT')))" \
  -e "print(c('RENV_PATHS_LIBRARY' = Sys.getenv('RENV_PATHS_LIBRARY')))" \
  -e "print(c('RENV_PREFIX_AUTO' = Sys.getenv('RENV_PREFIX_AUTO')))" \
  -e "print(c('RENV_CONFIG_PAK_ENABLED' = Sys.getenv('RENV_CONFIG_PAK_ENABLED')))" \
  -e "print(c('USER' = Sys.getenv('USER')))" \
  -e "print(c('wd' = getwd()))" \
  -e "print(c('.libPaths' = .libPaths()))"
  Rscript -e 'Sys.setenv("RENV_CONFIG_PAK_ENABLED" = "false")' \
    -e 'try(install.packages(c("jsonlite", "languageserver", "pak", "renv", "BiocManager", "yaml")))'
  popd
  echo "Completed updating R packages"

  rm -rf "/tmp/r-packages"
}

# ensure packages available for renc
install_pkg_for_renv() {
  # installs packages needed by renv
  # with pak to try avoid subprocess error
  echo "Installing pak and BiocManager into renv cache"

  # install pak and BiocManager into renv cache
  echo "Installing pak and BiocManager into renv cache"
  mkdir -p "/tmp/renv"
  pushd "/tmp/renv"
  Rscript -e "print(c('.libPaths' = .libPaths()))" \
    -e 'Sys.setenv("RENV_CONFIG_PAK_ENABLED" = "false"); renv::init(bioconductor = TRUE)' \
    -e 'try(renv::install("pak"))' \
    -e 'try(renv::install("BiocManager"))'
  Rscript -e "Sys.setenv('RENV_CONFIG_PAK_ENABLED' = 'true'); try(renv::install('tinytest'))"
  Rscript -e "Sys.setenv('RENV_CONFIG_PAK_ENABLED' = 'true'); try(renv::install('tinytest'))"
  popd
  echo "Completed installing pak and BiocManager into renv cache"

  rm -rf "/tmp/renv"
}

update_r_pkg
install_pkg_for_renv

cat > /usr/local/bin/config-r \
<< 'EOF'
#!/usr/bin/env bash

# Script for configuring the R environment in GitHub Codespaces or GitPod
# - Ensures that scripts in ~/.bashrc.d are sourced:
#   - Previously, we have saved scripts to set up environmnent
#     variables for GitHub and R library paths
# - Ensures radian works in GitPod/Codespace (without 
#   turning off auto_match, multiline interactive code does not run
#   correctly)
# - Making linting less aggressive
#   - Ignore object length and snake/camel case
# - Ensure key R packages up to date

# set up bashrc_d
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

# copy across any settings from config-r
# to ~/.bashrc.d
add_to_bashrc_d() {
  echo "Adding files from /bashrc-d-$1 to ~/.bashrc.d"
  if [ -d "/bashrc-d-$1" ]; then
    for file in $(ls "/bashrc-d-$1"); do
      echo "Adding $file"
      cp "/bashrc-d-$1/$file" "$HOME/.bashrc.d/$file"
    done
    echo "Completed adding files from /bashrc-d-$1 to ~/.bashrc.d"
    sudo rm -rf "/bashrc-d-$1"
  else
    echo "No /bashrc-d-$1 directory found"
  fi 
}

# ensure key radian setting is set on Codespaces and Git
echo "---------------------"
echo "---------------------"
echo " "
echo " "
echo "printing all environment variables"
printenv
echo " "
echo " "
echo "---------------------"
echo "---------------------"

echo "done printing all environment variables"
config_radian() {
  echo "Configuring radian"
  # ensure that radian works (at least on ephemeral dev
  # environments)
  if [ "$CONFIG_RADIAN" = "true" ]; then
    if ! [ -e "$HOME/.radian_profile" ]; then touch "$HOME/.radian_profile"; fi
    if [ -z "$(cat "$HOME/.radian_profile" | grep -E 'options\(\s*radian\.auto_match')" ]; then 
      echo 'options(radian.auto_match = FALSE)' >> "$HOME/.radian_profile"
    fi
    echo "Completed configuring radian"
  fi
}

config_linting() {
  echo "Configuring linting"
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
  echo "Completed configuring linting"
}

get_path_file_json() {
  echo "Getting path to settings.json"
  # Define the path to your JSON file
  path_rel=".vscode-remote/data/Machine/settings.json"
  path_file_json="/home/$USER/$path_rel"
  if [ ! -f "$path_file_json" ]; then
      echo "No R settings file found, creating it"
      mkdir -p "$(dirname "$path_file_json")"
      echo "{}" > "$path_file_json"
  fi
  echo "Completed getting path to settings.json"
}

config_vscode_r_ext() {
  echo "Configuring VS Code R extension"
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
  # Create the JSON file if it does not exist
  if [ ! -f "$path_file_json" ]; then
      echo "No R settings file found, creating it"
      mkdir -p "$(dirname "$path_file_json")"
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
      echo "Running update_json_if_needed"
      local has_version_path=false
      local paths=( $(jq -r ".\"$new_key\"[]?" "$path_file_json") )
      echo "$paths"

      for path in "${paths[@]}"; do
          echo "path"
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
      echo "Updating settings JSON file"
      local new_array=$(Rscript --vanilla -e "cat(.libPaths(), sep = '\n')" | sed ':a;N;$!ba;s/\n/", "/g' | sed 's/^/["/' | sed 's/$/"]/')
      echo "$new_array"
      echo "$new_key"
      echo "$path_file_json"
      test -f "$path_file_json" && echo "file exists" || echo "file does not exist"
      jq --arg key "$new_key" --argjson value "$new_array" '. + {($key): $value}' $path_file_json > temp.json && mv temp.json $path_file_json
  }

  # Check if r.libPaths exists and if the current R version is not in its values
  echo "Check if the key exists"
  if jq -e ". | has(\"$new_key\")" "$path_file_json" > /dev/null; then
      echo "key exists"
      update_json_if_needed
  else
      echo "key does not exist"
      echo "Add r.libPaths key"
      # r.libPaths key doesn't exist, so proceed to add it
      update_json
  fi
  echo "Completed configuring VS Code R extension"
}

config_bashrc_d
add_to_bashrc_d config-r
config_radian
config_linting
get_path_file_json
if [ -n $path_file_json ]; then
  config_vscode_r_ext
fi

EOF

chmod +x /usr/local/bin/config-r
