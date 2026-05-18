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

REPOSITORIES="${REPOSITORIES:-""}"
PACKAGES="${PACKAGES:-""}"
SKIP_PACKAGES="${SKIPPACKAGES:-""}"
INSTALL_SYSREQS="${INSTALLSYSTEMREQUIREMENTS:-"false"}"
CRAN_MIRROR="${CRANMIRROR:-"https://cloud.r-project.org"}"

if [ -n "$PACKAGES" ] || [ -n "$REPOSITORIES" ] || [ -d "$RENV_DIR" ]; then
    if ! command -v Rscript >/dev/null 2>&1; then
        echo "(!) Cannot run Rscript. Please ensure R is installed before running the renv-cache feature."
        exit 1
    fi
fi

# Resolve target user
USERNAME=${USERNAME:-${_REMOTE_USER:-"automatic"}}
if [ "$USERNAME" = "auto" ] || [ "$USERNAME" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u "${CURRENT_USER}" > /dev/null 2>&1; then
            USERNAME="${CURRENT_USER}"
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME="root"
    fi
elif [ "$USERNAME" = "none" ] || ! id -u "${USERNAME}" > /dev/null 2>&1; then
    USERNAME="root"
fi

export USERNAME
export INSTALL_SYSREQS
export CRAN_MIRROR

apt-get update -y && apt-get install -y --no-install-recommends jq git curl lsb-release

if [ -n "$GITHUB_PAT" ]; then
export GITHUB_TOKEN="$GITHUB_PAT"
elif [ -n "$GITHUB_TOKEN" ]; then
export GITHUB_PAT="$GITHUB_TOKEN"
fi

# CORE FUNCTION: Process a directory containing an renv lockfile

process_renv_dir() {
local TARGET_DIR=$1
local PROFILE=$2

if [ -n "$PROFILE" ]; then
    export RENV_PROFILE="$PROFILE"
    local LOCK_PATH="renv/profiles/$PROFILE/renv.lock"
else
    unset RENV_PROFILE
    local LOCK_PATH="renv.lock"
fi

if [ ! -f "$TARGET_DIR/$LOCK_PATH" ]; then
    echo "No lockfile found at $TARGET_DIR/$LOCK_PATH. Skipping."
    return 0
fi

echo "Processing lockfile $LOCK_PATH in $TARGET_DIR..."
pushd "$TARGET_DIR" > /dev/null
chown -R "${USERNAME}:${USERNAME}" .

# System Requirements Check via Posit API
if [ "${INSTALL_SYSREQS}" = "true" ]; then
    echo "Resolving system requirements..."
    PKGS=$(jq -r '.Packages | keys[]' "$LOCK_PATH" | paste -sd, -)
    OS_DIST=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    OS_RELEASE=$(lsb_release -cs)
    SYSREQ_URL="https://packagemanager.posit.co/__api__/repos/1/sysreqs?all=false&pkgname=${PKGS}&distribution=${OS_DIST}&release=${OS_RELEASE}"
    APT_PKGS=$(curl -sL "$SYSREQ_URL" | jq -r '.requirements[]?.requirements?.packages[]?' | sort -u | paste -sd" " -)
    if [ -n "$APT_PKGS" ]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get install -y --no-install-recommends $APT_PKGS
    fi
fi

# Recursive Strip & Purge (Security)
if [ -n "$SKIP_PACKAGES" ]; then
    echo "Recursively stripping skipped packages and purging cache..."
    export SKIP_PACKAGES="$SKIP_PACKAGES"
    export RENV_LOCK_PATH="$LOCK_PATH"

    su "${USERNAME}" -c "Rscript -e \"
        skip_list <- trimws(unlist(strsplit(Sys.getenv('SKIP_PACKAGES'), ',')))
        lock_path <- Sys.getenv('RENV_LOCK_PATH')
        lock_data <- renv:::renv_json_read(lock_path)

        if (!is.null(lock_data\\\$Packages)) {
            changed <- TRUE
            while (changed) {
                changed <- FALSE
                for (pkg_name in names(lock_data\\\$Packages)) {
                    reqs <- lock_data\\\$Packages[[pkg_name]]\\\$Requirements
                    if (!is.null(reqs) && any(reqs %in% skip_list)) {
                        if (!(pkg_name %in% skip_list)) {
                            skip_list <- c(skip_list, pkg_name)
                            changed <- TRUE
                        }
                    }
                }
            }
            for (pkg in skip_list) lock_data\\\$Packages[[pkg]] <- NULL
            renv:::renv_json_write(lock_data, file = lock_path)
        }

        for (pkg in skip_list) {
            tryCatch({
                renv::purge(pkg, prompt = FALSE)
                message('Purged ', pkg, ' from global cache.')
            }, error = function(e) NULL)
        }
    \""
fi

echo "Warming cache from $TARGET_DIR (Profile: ${PROFILE:-default})..."
su "${USERNAME}" -c "Rscript -e \"options(repos = c(CRAN = '${CRAN_MIRROR}')); renv::restore()\""
popd > /dev/null
}


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

    # 🛡️ Sentinel: Security fix to prevent accidental rm -rf /*
    if [[ -z "$directory" ]] || [[ "$directory" != /* ]]; then
        echo "[ERROR] Refusing to empty directory: '$directory' (not an absolute path)"
        return 1
    fi

    # Block path traversal and root-equivalent segments ( . and .. )
    if [[ "$directory" =~ (/\.($|/)|/\.\.($|/)) ]]; then
        echo "[ERROR] Refusing to empty directory: '$directory' (unsafe segment: . or ..)"
        return 1
    fi

    # Block root aliases (/, //, etc.)
    local normalized="${directory}"
    while [[ "$normalized" != "/" && "$normalized" == */ ]]; do
        normalized="${normalized%/}"
    done
    if [[ "$normalized" == "/" ]] || [[ "$normalized" == "//" ]] || [[ -z "$normalized" ]]; then
        echo "[ERROR] Refusing to empty directory: '$directory' (resolves to root)"
        return 1
    fi

    if [ -d "$directory" ]; then
        # Remove all contents including hidden files (POSIX-safe)
        find "$directory" -mindepth 1 -delete 2>/dev/null || rm -rf "${directory:?}"/*
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
        # 🛡️ Sentinel: Security fix to prevent accidental rm -rf /*
        if [[ -z "$dir" ]] || [[ "$dir" != /* ]]; then
            echo "[ERROR] Refusing to remove directory: '$dir' (not an absolute path)"
            continue
        fi

        # Block path traversal and root-equivalent segments ( . and .. )
        if [[ "$dir" =~ (/\.($|/)|/\.\.($|/)) ]]; then
            echo "[ERROR] Refusing to remove directory: '$dir' (unsafe segment: . or ..)"
            continue
        fi

        # Block root aliases (/, //, etc.)
        local normalized="${dir}"
        while [[ "$normalized" != "/" && "$normalized" == */ ]]; do
            normalized="${normalized%/}"
        done
        if [[ "$normalized" == "/" ]] || [[ "$normalized" == "//" ]] || [[ -z "$normalized" ]]; then
            echo "[ERROR] Refusing to remove directory: '$dir' (resolves to root)"
            continue
        fi

        if [ -d "$dir" ]; then
            rm -rf "${dir:?}"
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
    su "${USERNAME}" -c "Rscript -e \"if (!requireNamespace('remotes', quietly = TRUE)) install.packages('remotes', repos = '${CRAN_MIRROR}')\""
    
    # Install renvvv
    su "${USERNAME}" -c "Rscript -e \"remotes::install_github('MiguelRodo/renvvv', upgrade = 'never')\""
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

# Function to perform cleanup tasks
clean_up() {
    # Remove specified temporary directories
    rm_dirs /tmp/Rtmp* /tmp/rig

    # Empty the apt lists directory
    empty_dir /var/lib/apt/lists
}

# EXECUTION WORKFLOW
install_renvvv
create_path_post_create_command
set_r_libs
set_tokens_for_install

# 1. Process Local Lockfile (Backward Compatibility)
if [ -n "$RENV_DIR" ] && [ -d "$RENV_DIR" ]; then
    # We must look for renv.lock in subdirectories of RENV_DIR
    for dir in $(find "$RENV_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null); do
        process_renv_dir "$dir" ""
    done
fi

# 2. Process Dynamic Repositories
if [ -n "$REPOSITORIES" ]; then
    TMP_REPO_DIR=$(mktemp -d)
    IFS=',' read -ra REPO_ARRAY <<< "$REPOSITORIES"

    for REPO_SPEC in "${REPO_ARRAY[@]}"; do
        REPO_SPEC=$(echo "$REPO_SPEC" | xargs)

        # Extract Profile (everything after the colon)
        if [[ "$REPO_SPEC" == *":"* ]]; then
            PROFILE="${REPO_SPEC##*:}"
            REPO_SPEC="${REPO_SPEC%:*}"
        else
            PROFILE=""
        fi

        # Extract Branch (everything after the @)
        if [[ "$REPO_SPEC" == *"@"* ]]; then
            REPO_PATH="${REPO_SPEC%%@*}"
            BRANCH="${REPO_SPEC##*@}"
        else
            REPO_PATH="$REPO_SPEC"
            BRANCH=""
        fi

        TARGET_DIR="${TMP_REPO_DIR}/${REPO_PATH##*/}"
        CLONE_URL="https://${GITHUB_PAT:-}@github.com/${REPO_PATH}.git"

        echo "Cloning ${REPO_PATH}..."
        if [ -n "$BRANCH" ]; then
            git clone --branch "$BRANCH" --single-branch "$CLONE_URL" "$TARGET_DIR"
        else
            git clone "$CLONE_URL" "$TARGET_DIR"
        fi

        process_renv_dir "$TARGET_DIR" "$PROFILE"
    done
    rm -rf "$TMP_REPO_DIR"
fi

# 3. Process Explicit Packages (No Lockfile)
if [ -n "$PACKAGES" ]; then
    TMP_PKG_DIR=$(mktemp -d)
    chown "${USERNAME}:${USERNAME}" "$TMP_PKG_DIR"
    pushd "$TMP_PKG_DIR" > /dev/null

    echo "Warming cache with explicit packages: ${PACKAGES}..."
    su "${USERNAME}" -c "Rscript -e \"
        options(repos = c(CRAN = '${CRAN_MIRROR}'))
        renv::init(bare = TRUE, restart = FALSE)
        pkgs <- trimws(unlist(strsplit('${PACKAGES}', ',')))
        renv::install(pkgs)
    \""
    popd > /dev/null
    rm -rf "$TMP_PKG_DIR"
fi

echo "renv-cache installation complete!"
reset_tokens_after_install
clean_up
