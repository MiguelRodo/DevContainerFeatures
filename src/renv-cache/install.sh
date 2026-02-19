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
ENSURE_GITHUB_PAT_SET="${ENSUREGITHUBPATSET:-true}"
ELEVATE_GITHUB_TOKEN="${ELEVATEGITHUBTOKEN:-true}"
OVERRIDE_GITHUB_TOKEN="${OVERRIDEGITHUBTOKEN:-false}"
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

# Function to ensure GitHub Personal Access Token (PAT) is set
ensure_github_pat_set() {
    if [ "$ENSURE_GITHUB_PAT_SET" = "true" ]; then
        # Copy and set execute permissions for bashrc-d script
        copy_and_set_execute_bit bashrc-d

        # Append command to post-create file with error handling
        echo -e "/usr/local/bin/renv-cache-bashrc-d || \n    {echo 'Failed to run /usr/local/bin/renv-cache-bashrc-d'}\n" >> "$PATH_POST_CREATE_COMMAND"

        # Copy and set execute permissions for github-pat script
        copy_and_set_execute_bit github-pat

        # Create environment file for github-pat options
        mkdir -p /usr/local/etc
        cat > /usr/local/etc/renv-cache-github-pat.env << EOF
ELEVATE_GITHUB_TOKEN=$ELEVATE_GITHUB_TOKEN
OVERRIDE_GITHUB_TOKEN=$OVERRIDE_GITHUB_TOKEN
EOF

        # Append command to post-create file with sudo and error handling
        if ! echo -e "sudo /usr/local/bin/renv-cache-github-pat || \n    {echo 'Failed to run /usr/local/bin/renv-cache-github-pat'}" >> "$PATH_POST_CREATE_COMMAND"; then
            echo "[ERROR] Failed to add renv-cache-github-pat to post-create"
        else
            echo "[OK] Added renv-cache-github-pat to post-create"
        fi

        if ! echo -e 'mkdir -p "$HOME"/.bashrc.d; cp /usr/local/bin/renv-cache-github-pat "$HOME"/.bashrc.d/' >> "$PATH_POST_CREATE_COMMAND"; then
            echo "[ERROR] Failed to add renv-cache-github-pat to post-create"
        else
            echo "[OK] Added renv-cache-github-pat to post-create"
        fi
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
    ensure_github_pat_set
    restore
    clean_up
}

# Execute the main function
main
