#!/usr/bin/env bash

set -e

SET_R_LIB_PATHS="${SETRLIBPATHS:-true}"
ENSURE_GITHUB_PAT_SET="${ENSUREGITHUBPATSET:-true}"
RESTORE="${RESTORE:-true}"
PKG_EXCLUDE="${PKGEXCLUDE:-}"
DEBUG="${DEBUG:-false}"
USE_PAK="${USEPAK:-false}"

create_path_post_create_command() {
  PATH_POST_CREATE_COMMAND=/usr/local/bin/repos-post-create-command
  initialize_command_file "$PATH_POST_CREATE_COMMAND"
}

initialize_command_file() {
    local file_path="$1"
    if [ ! -f "$file_path" ]; then
        printf '#!/usr/bin/env bash\n' > "$file_path"
    else
        # Check if shebang exists; add if missing
        if ! grep -q '^#!/usr/bin/env bash' "$file_path"; then
            sed -i '1i#!/usr/bin/env bash' "$file_path"
        fi
    fi
    chmod 755 "$file_path"
}

copy_and_set_execute_bit() {
  if ! cp cmd/"$1" /usr/local/bin/config-r-"$1"; then
      echo "Failed to copy cmd/$1"
  fi
  if ! chmod 755 /usr/local/bin/config-r-"$1"; then
      echo "Failed to set execute bit for /usr/local/bin/config-r-$1"
  fi
}

# Function to empty a directory (remove all contents)
empty_dir() {
  if [ -d "$1" ]; then
    # Remove all visible files and directories
    rm -rf "$1"/*

    # Remove hidden files and directories
    rm -rf "$1"/.[!.]* "$1"/..?*
  else
    echo "🔍 Directory '$1' does not exist."
  fi
}
# Function to remove directories
rm_dirs() {
  if [ -z "$1" ]; then
    return
  fi
  for dir in "$@"; do
    if [ -d "$dir" ]; then
      rm -rf "$dir"
      echo "🗑️ Removed directory: $dir"
    else
      echo "🔍 Directory '$dir' does not exist."
    fi
  done
}

set_r_libs() {
  if [ "$SET_R_LIB_PATHS" = "true" ]; then
      chmod 755 scripts/r-lib.sh
      if ! bash scripts/r-lib.sh; then
        echo "Failed to define R library environment variables"
      fi
  fi
}

ensure_github_pat_set() {
  if [ "$ENSURE_GITHUB_PAT_SET" = "true" ]; then
      copy_and_set_execute_bit bashrc-d
      echo -e "/usr/local/bin/config-r-bashrc-d || \n    {echo 'Failed to run /usr/local/bin/config-r-bashrc-d}\n" >> "$PATH_POST_CREATE_COMMAND"
      copy_and_set_execute_bit github-pat
      if ! echo -e "sudo /usr/local/bin/config-r-github-pat || \n    {echo 'Failed to run /usr/local/bin/config-r-github-pat'}" >> "$PATH_POST_CREATE_COMMAND"; then
          echo "❌ Failed to add config-r-github-pat to post-create-command"
      else
          echo "✅ Added config-r-github-pat to post-create-command"
      fi
  fi
}



restore() {
  copy_and_set_execute_bit renv-restore
  copy_and_set_execute_bit renv-restore-build

  # Construct the base command
  command="/usr/local/bin/config-r-renv-restore-build -r \"$RESTORE\" -e \"$PKG_EXCLUDE\""

  # Append options based on conditions
  [ "$DEBUG" = "true" ] && command="$command --debug"
  [ "$USE_PAK" = "false" ] && command="$command --no-pak"
  
  # Execute the command with error handling
  eval $command || {
    echo "❌ config-r-renv-restore-build failed"
    exit 1
  }
}

clean_up() {
  rm_dirs /tmp/Rtmp* /tmp/rig
  empty_dir /var/lib/apt/lists
}

main() {
  create_path_post_create_command
  set_r_libs
  ensure_github_pat_set
  restore
  clean_up
}

main

