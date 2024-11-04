#!/usr/bin/env bash

set -e

PATH_POST_CREATE_COMMAND=/usr/local/lib/config-r-post-create-command
cp cmd/post-create-command "$PATH_POST_CREATE_COMMAND"
chmod 755 "$PATH_POST_CREATE_COMMAND"

SET_R_LIB_PATHS="${SETRLIBPATHS:-true}"
ENSURE_GITHUB_PAT_SET="${ENSUREGITHUBPATSET:-true}"
RESTORE="${RESTORE:-true}"
PKG_EXCLUDE="${PKGEXCLUDE:-}"
DEBUG="${DEBUG:-false}"

copy_and_set_execute_bit() {
    cp cmd/"$1" /usr/local/lib/config-r-"$1" || {
      echo "Failed to copy cmd/$1"
    }
    chmod 755 /usr/local/lib/config-r-"$1" || {
      echo "Failed to set execute bit for /usr/local/lib/config-r-$1"
    }
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
    bash scripts/r-lib.sh || {
      echo "Failed to define R library environment variables"
    }
fi

if [ "$ENSURE_GITHUB_PAT_SET" = "true" ]; then
    copy_and_set_execute_bit bashrc-d
    echo "/usr/local/lib/config-r-bashrc-d" >> "$PATH_POST_CREATE_COMMAND"
    copy_and_set_execute_bit github-pat
    /usr/local/lib/config-r-github-pat || {
      echo "Failed to run config-r-github-pat"
    }
    echo "/usr/local/lib/config-r-github-pat" >> "$PATH_POST_CREATE_COMMAND" || {
      echo "Failed to add config-r-github-pat to post-create-command"
    }
fi

copy_and_set_execute_bit renv-restore
copy_and_set_execute_bit renv-restore-build
if [ "$DEBUG" = "true" ]; then
    /usr/local/lib/config-r-renv-restore-build -r "$RESTORE" -e "$PKG_EXCLUDE" --debug || {
        echo "Failed to restore R packages"
    }
else
    /usr/local/lib/config-r-renv-restore-build -r "$RESTORE" -e "$PKG_EXCLUDE" || {
        echo "Failed to restore R packages"
    }
fi

echo " " >> "$PATH_POST_CREATE_COMMAND" 

empty_dir /var/lib/apt/lists
rm_dirs /tmp/Rtmp* /tmp/rig