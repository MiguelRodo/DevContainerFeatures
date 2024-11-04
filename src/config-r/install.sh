#!/usr/bin/env bash

set -e

PATH_POST_CREATE_COMMAND=/usr/local/bin/config-r-post-create-command
if [ ! -f "$PATH_POST_CREATE_COMMAND" ]; then
    touch "$PATH_POST_CREATE_COMMAND"
fi
echo '#!/usr/bin/env bash' >> "$PATH_POST_CREATE_COMMAND"
chmod 755 "$PATH_POST_CREATE_COMMAND"

SET_R_LIB_PATHS="${SETRLIBPATHS:-true}"
ENSURE_GITHUB_PAT_SET="${ENSUREGITHUBPATSET:-true}"
RESTORE="${RESTORE:-true}"
PKG_EXCLUDE="${PKGEXCLUDE:-}"
DEBUG="${DEBUG:-false}"
USE_PAK="${USEPAK:-true}"

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

if [ "$SET_R_LIB_PATHS" = "true" ]; then
    chmod 755 scripts/r-lib.sh
    if ! bash scripts/r-lib.sh; then
      echo "Failed to define R library environment variables"
    fi
fi

if [ "$ENSURE_GITHUB_PAT_SET" = "true" ]; then
    copy_and_set_execute_bit bashrc-d
    echo "/usr/local/bin/config-r-bashrc-d" >> "$PATH_POST_CREATE_COMMAND"
    copy_and_set_execute_bit github-pat
    if ! echo "/usr/local/bin/config-r-github-pat" >> "$PATH_POST_CREATE_COMMAND"; then
        echo "❌ Failed to add config-r-github-pat to post-create-command"
    else
        echo "✅ Added config-r-github-pat to post-create-command"
    fi
fi

copy_and_set_execute_bit renv-restore
copy_and_set_execute_bit renv-restore-build
if [ "$DEBUG" = "true" ]; then
    if [ "$USE_PAK" = "true" ]; then
        /usr/local/bin/config-r-renv-restore -r "$RESTORE" -e "$PKG_EXCLUDE" --debug
    else 
        /usr/local/bin/config-r-renv-restore -r "$RESTORE" -e "$PKG_EXCLUDE" --debug --no-pak
    fi
else
    if [ "$USE_PAK" = "true" ]; then
        /usr/local/bin/config-r-renv-restore -r "$RESTORE" -e "$PKG_EXCLUDE"
    else 
        /usr/local/bin/config-r-renv-restore -r "$RESTORE" -e "$PKG_EXCLUDE" --no-pak
    fi
fi

echo " " >> "$PATH_POST_CREATE_COMMAND" 

empty_dir /var/lib/apt/lists
rm_dirs /tmp/Rtmp* /tmp/rig