#!/bin/sh
# POSIX-compatible bootstrap: ensure bash is available before proceeding
set -e

# Install bash if not present (e.g. Alpine Linux)
if ! command -v bash >/dev/null 2>&1; then
    echo "[INFO] bash not found, attempting to install..."
    if command -v apk >/dev/null 2>&1; then
        apk add --no-cache bash
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y --no-install-recommends bash && rm -rf /var/lib/apt/lists/*
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y bash
    elif command -v yum >/dev/null 2>&1; then
        yum install -y bash
    else
        echo "[ERROR] Could not install bash: no supported package manager found"
        exit 1
    fi
fi

# Re-exec under bash if not already running under bash
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi
# --- Everything below runs under bash ---
set -e

# Configuration variables with default values
SET_R_LIB_PATHS="${SETRLIBPATHS:-true}"
OVERRIDE_TOKENS_AT_INSTALL="${OVERRIDETOKENSATINSTALL:-true}"
RESTORE="${RESTORE:-true}"
UPDATE="${UPDATE:-false}"
PKG_EXCLUDE="${PKGEXCLUDE:-}"
DEBUG="${DEBUG:-false}"
USE_PAK="${USEPAK:-false}"
RENV_DIR="${RENVDIR:-"/usr/local/share/renv-cache/renv"}"
DEBUG_RENV="${DEBUGRENV:-false}"


# Function to log debug messages if enabled
debug() {
    if [ "$DEBUG" = true ]; then
        echo "DEBUG: $1"
    fi
}

# Function to create the post-create command path and initialize the command file
create_path_post_create_command() {
    PATH_POST_CREATE_COMMAND=/usr/local/bin/renv-cache-post-create
    initialize_command_file "$PATH_POST_CREATE_COMMAND"
}

# Function to initialize a command file with a shebang
initialize_command_file() {
    local file_path="$1"
    if [ ! -f "$file_path" ]; then
        # Create the file with shebang if it does not exist
        printf '#!/usr/bin/env bash\n' > "$file_path"
    else
        # Check if shebang exists; add if missing (POSIX-safe, no GNU sed)
        if ! grep -q '^#!/usr/bin/env bash' "$file_path"; then
            tmp_file=$(mktemp)
            { echo '#!/usr/bin/env bash'; cat "$file_path"; } > "$tmp_file"
            mv "$tmp_file" "$file_path"
        fi
    fi
    # Set execute permissions
    chmod 755 "$file_path"
}

# Function to copy a script and set its execute permissions
copy_and_set_execute_bit() {
    local script_name="$1"

    # Copy the script to /usr/local/bin with a prefixed name
    if ! cp "cmd/$script_name" "/usr/local/bin/renv-cache-$script_name"; then
        echo "Failed to copy cmd/$script_name"
    fi

    # Set execute permissions on the copied script
    if ! chmod 755 "/usr/local/bin/renv-cache-$script_name"; then
        echo "Failed to set execute bit for /usr/local/bin/renv-cache-$script_name"
    fi
}

# Function to empty a directory by removing all its contents
empty_dir() {
    local directory="$1"

    if [ -d "$directory" ]; then
        # Remove all contents including hidden files (POSIX-safe)
        find "$directory" -mindepth 1 -delete 2>/dev/null || rm -rf "$directory"/* 
    else
        echo "Directory '$directory' does not exist."
    fi
}

# Function to remove specified directories
rm_dirs() {
    if [ -z "$1" ]; then
        return
    fi

    for dir in "$@"; do
        if [ -d "$dir" ]; then
            rm -rf "$dir"
            echo "Removed directory: $dir"
        else
            echo "Directory '$dir' does not exist."
        fi
    done
}

# Function to set R library paths if enabled
set_r_libs() {
    if [ "$SET_R_LIB_PATHS" = "true" ]; then
        # Ensure the R library script is executable
        chmod 755 scripts/r-lib.sh

        # Execute the R library script
        if ! bash scripts/r-lib.sh; then
            echo "Failed to define R library environment variables"
        fi
    fi
}

# Function to install renvvv
install_renvvv() {
    echo "Installing renvvv..."
    # Ensure remotes is installed
    Rscript -e "if (!requireNamespace('remotes', quietly = TRUE)) install.packages('remotes', repos = 'https://cloud.r-project.org')"
    
    # Install renvvv
    Rscript -e "remotes::install_github('MiguelRodo/renvvv', upgrade = 'never')"
}

update_renv_cache() {
    if [ "$SET_R_LIB_PATHS" = "true" ]; then
        # Ensure the R library script is executable
        chmod 755 scripts/r-lib-update.sh

        # Execute the R library script
        if ! bash scripts/r-lib-update.sh; then
            echo "Failed to update R library environment variables"
        fi
    fi
    
}

# Save original token values (used for restoring after install)
_ORIG_GITHUB_TOKEN=""
_ORIG_GITHUB_PAT=""

# Function to temporarily set tokens for the install phase only.
# Saves original values, then sets GITHUB_PAT and GITHUB_TOKEN to the
# best available token so renv package installation can authenticate.
# Call reset_tokens_after_install() after restore completes.
set_tokens_for_install() {
    if [ "$OVERRIDE_TOKENS_AT_INSTALL" != "true" ]; then
        return
    fi

    # Save originals so we can restore them afterwards
    _ORIG_GITHUB_TOKEN="${GITHUB_TOKEN:-}"
    _ORIG_GITHUB_PAT="${GITHUB_PAT:-}"

    # Set GITHUB_PAT from the best available token if not already set
    # Priority: GITHUB_PAT (keep if set) > GH_TOKEN > GITHUB_TOKEN
    if [ -z "$GITHUB_PAT" ]; then
        if [ -n "$GH_TOKEN" ]; then
            export GITHUB_PAT="$GH_TOKEN"
        elif [ -n "$GITHUB_TOKEN" ]; then
            export GITHUB_PAT="$GITHUB_TOKEN"
        fi
    fi

    # Override GITHUB_TOKEN with the most permissive non-GITHUB_TOKEN token
    # Priority: GITHUB_PAT > GH_TOKEN
    if [ -n "$GITHUB_PAT" ]; then
        export GITHUB_TOKEN="$GITHUB_PAT"
    elif [ -n "$GH_TOKEN" ]; then
        export GITHUB_TOKEN="$GH_TOKEN"
    fi
}

# Function to restore token environment variables to their pre-install values.
# Must be called after restore() to avoid leaking elevated tokens.
reset_tokens_after_install() {
    if [ "$OVERRIDE_TOKENS_AT_INSTALL" != "true" ]; then
        return
    fi

    if [ -n "$_ORIG_GITHUB_TOKEN" ]; then
        export GITHUB_TOKEN="$_ORIG_GITHUB_TOKEN"
    else
        unset GITHUB_TOKEN
    fi

    if [ -n "$_ORIG_GITHUB_PAT" ]; then
        export GITHUB_PAT="$_ORIG_GITHUB_PAT"
    else
        unset GITHUB_PAT
    fi
}

# Function to restore R environment using renv
restore() {
    # Copy and set execute permissions for renv restore scripts
    copy_and_set_execute_bit renv-restore
    copy_and_set_execute_bit renv-restore-build

    # set renv cache mode and user
    debug "USERNAME: $USERNAME"
    debug "USER: $USER"
    debug "REMOTE_USER: $_REMOTE_USER"
    debug "CONTAINER_USER: $_CONTAINER_USER"

    export RENV_CACHE_MODE="0755"
    debug "RENV_CACHE_MODE: $RENV_CACHE_MODE"
    if [ -n "$_REMOTE_USER" ]; then
        export RENV_CACHE_USER="$_REMOTE_USER"
        debug "RENV_CACHE_USER: $_REMOTE_USER"
    fi

    # Construct the command as an array
    local command=(/usr/local/bin/renv-cache-renv-restore-build)

    # Append options based on conditions
    if [ "$RESTORE" = "true" ]; then
        command+=("--restore")
    fi

    if [ "$UPDATE" = "true" ]; then
        command+=("--update")
    fi

    if [ "$DEBUG" = "true" ]; then
        command+=("--debug")
    fi

    if [ "$DEBUG_RENV" = "true" ]; then
        command+=("--debug-renv")
    fi

    if [ "$USE_PAK" = "true" ]; then
        command+=("--pak")
    fi

    if [ -n "$PKG_EXCLUDE" ]; then
        command+=("--exclude")
        command+=("$PKG_EXCLUDE")
    fi

    if [ -n "$RENV_DIR" ]; then
        command+=("--directory")
        command+=("$RENV_DIR")
    fi

    # Log the command for debugging purposes
    echo "Executing command: ${command[*]}"

    # Execute the command with error handling
    if ! "${command[@]}"; then
        echo "[ERROR] renv-cache-renv-restore-build failed with command: ${command[*]}"
        exit 0
    fi
}

# Function to perform cleanup tasks
clean_up() {
    # Remove specified temporary directories
    rm_dirs /tmp/Rtmp* /tmp/rig

    # Empty the apt lists directory
    empty_dir /var/lib/apt/lists
}

# Main function to orchestrate the execution of all tasks
main() {
    install_renvvv
    create_path_post_create_command
    set_r_libs
    set_tokens_for_install
    restore
    reset_tokens_after_install
    clean_up
}

# Execute the main function
main
