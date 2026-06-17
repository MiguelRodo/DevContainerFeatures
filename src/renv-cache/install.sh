#!/bin/sh
# POSIX-compatible bootstrap: ensure bash is available before proceeding
set -e

install_packages() {
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y && apt-get install -y --no-install-recommends "$@"
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y "$@"
    elif command -v yum >/dev/null 2>&1; then
        yum install -y "$@"
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache "$@"
    elif command -v zypper >/dev/null 2>&1; then
        zypper install -y "$@"
    else
        echo "[ERROR] No supported package manager found to install: $*"
        exit 1
    fi
}

# Install bash if not present (e.g. Alpine Linux)
if ! command -v bash >/dev/null 2>&1; then
    echo "[INFO] bash not found, attempting to install..."
    install_packages bash
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
USE_PAK="${USEPAK:-false}"
LOCKFILE_DIR="${LOCKFILEDIR:-"/usr/local/share/renv-cache/lockfiles"}"
DEBUG_RENV="${DEBUGRENV:-false}"
CREATE_UNIFIED_LOCKFILE="${CREATEUNIFIEDLOCKFILE:-auto}"
PURGE_POST_UNIFICATION="${PURGEPOSTUNIFICATION:-none}"

# Validate LOCKFILE_DIR for security
if [ -n "$LOCKFILE_DIR" ]; then
    if [[ "$LOCKFILE_DIR" != /* ]]; then
        echo "[ERROR] LOCKFILE_DIR must be an absolute path: '$LOCKFILE_DIR'"
        exit 1
    fi
    if [[ "$LOCKFILE_DIR" =~ (^|/)\.\.($|/) ]]; then
        echo "[ERROR] LOCKFILE_DIR contains invalid path traversal segments: '$LOCKFILE_DIR'"
        exit 1
    fi
    UNSAFE_REGEX='[[:space:];|&><$()`]'
    if [[ "$LOCKFILE_DIR" =~ $UNSAFE_REGEX ]]; then
        echo "[ERROR] LOCKFILE_DIR contains unsafe characters: '$LOCKFILE_DIR'"
        exit 1
    fi
    if [[ "$LOCKFILE_DIR" == "/" ]]; then
        echo "[ERROR] LOCKFILE_DIR cannot be the root directory."
        exit 1
    fi
fi

if [ ! "$RESTORE" = "true" ] && [ ! "$RESTORE" = "false" ]; then
    echo "[ERROR] Invalid value for restore: '$RESTORE'. Must be 'true' or 'false'."
    exit 1
fi
if [ ! "$UPDATE" = "true" ] && [ ! "$UPDATE" = "false" ]; then
    echo "[ERROR] Invalid value for update: '$UPDATE'. Must be 'true' or 'false'."
    exit 1
fi
if [ ! "$USE_PAK" = "true" ] && [ ! "$USE_PAK" = "false" ]; then
    echo "[ERROR] Invalid value for usePak: '$USE_PAK'. Must be 'true' or 'false'."
    exit 1
fi
if [ ! "$SET_R_LIB_PATHS" = "true" ] && [ ! "$SET_R_LIB_PATHS" = "false" ]; then
    echo "[ERROR] Invalid value for setRLibPaths: '$SET_R_LIB_PATHS'. Must be 'true' or 'false'."
    exit 1
fi
if [ ! "$OVERRIDE_TOKENS_AT_INSTALL" = "true" ] && [ ! "$OVERRIDE_TOKENS_AT_INSTALL" = "false" ]; then
    echo "[ERROR] Invalid value for overrideTokensAtInstall: '$OVERRIDE_TOKENS_AT_INSTALL'. Must be 'true' or 'false'."
    exit 1
fi
if [ ! "$DEBUG_RENV" = "true" ] && [ ! "$DEBUG_RENV" = "false" ]; then
    echo "[ERROR] Invalid value for debugRenv: '$DEBUG_RENV'. Must be 'true' or 'false'."
    exit 1
fi
if [ ! "$CREATE_UNIFIED_LOCKFILE" = "auto" ] && [ "$CREATE_UNIFIED_LOCKFILE" != "true" ] && [ "$CREATE_UNIFIED_LOCKFILE" != "false" ]; then
    echo "[ERROR] Invalid value for createUnifiedLockfile: '$CREATE_UNIFIED_LOCKFILE'. Must be one of: 'auto', 'true', 'false'."
    exit 1
fi
if [ ! "$PURGE_POST_UNIFICATION" = "none" ] && [ ! "$PURGE_POST_UNIFICATION" = "keep-one" ] && [ ! "$PURGE_POST_UNIFICATION" = "keep-both" ]; then
    echo "[ERROR] Invalid value for purgePostUnification: '$PURGE_POST_UNIFICATION'. Must be one of: 'none', 'keep-one', 'keep-both'."
    exit 1
fi

REPOSITORIES="${REPOSITORIES:-""}"
PKG="${PKG:-""}"
PKG_EXCLUDE="${PKGEXCLUDE:-""}"
INSTALL_SYSREQS="${INSTALLSYSTEMREQUIREMENTS:-"true"}"
CRAN_MIRROR="${CRANMIRROR:-"https://cloud.r-project.org"}"

if [ -n "$PKG" ] || [ -n "$REPOSITORIES" ] || { [ -n "$LOCKFILE_DIR" ] && [ -d "$LOCKFILE_DIR" ]; }; then
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

if [ "$DEBUG_RENV" = "true" ]; then
    echo "[INFO] Enabling renv verbose debugging..."
    export RENV_VERBOSE=TRUE
    export RENV_CONFIG_INSTALL_VERBOSE=TRUE
fi

install_packages jq git curl
if command -v apt-get >/dev/null 2>&1; then
    install_packages lsb-release
fi

if [ -n "$GITHUB_PAT" ]; then
    export GITHUB_TOKEN="$GITHUB_PAT"
elif [ -n "$GITHUB_TOKEN" ]; then
    export GITHUB_PAT="$GITHUB_TOKEN"
fi

# ==============================================================================
# BASH R-EXECUTION HELPERS (DRY Abstractions)
# ==============================================================================

# CORE RUNNER: Executes arbitrary R code securely as the target user.
# Automatically injects CRAN mirrors and passes GITHUB_PAT through the su boundary.
run_rscript() {
    local r_code="$1"
    su "${USERNAME}" -c "GITHUB_PAT=\"${GITHUB_PAT}\" Rscript -e \"options(repos = c(CRAN = '${CRAN_MIRROR}')); ${r_code}\""
}

init_bare_renv() {
    run_rscript "renv::init(bare = TRUE, restart = FALSE)"
}

install_gitcreds() {
    run_rscript "
        if (!requireNamespace('gitcreds', quietly = TRUE)) {
            message('[INFO] Installing gitcreds for authentication...')
            tryCatch(
                renv::install('gitcreds'),
                error = function(e) message('[WARN] Failed to install gitcreds: ', e\\\$message)
            )
        }
    "
}

install_renvvv_local() {
    run_rscript "
        if (!requireNamespace('renvvv', quietly = TRUE)) {
            message('[INFO] Installing renvvv...')
            tryCatch(
                renv::install('renvvv', repos = c(miguelrodo = 'https://miguelrodo.r-universe.dev', CRAN = 'https://cloud.r-project.org')),
                error = function(e) message('[WARN] Failed to install renvvv: ', e\\\$message)
            )
        }
    "
}

setup_pak() {
    if [ "$USE_PAK" = "true" ]; then
        echo "[INFO] Installing pak package manager..."
        
        for i in 1 2 3; do
            run_rscript "
                if (!requireNamespace('pak', quietly = TRUE)) {
                    message('[INFO] Attempt $i to install pak...')
                    tryCatch(
                        renvvv::renvvv_install('pak'),
                        error = function(e) message('[WARN] Failed to install pak: ', e\\\$message)
                    )
                }
            "
            sleep 1
        done
        
        echo "RENV_CONFIG_PAK_ENABLED=TRUE" >> ".Renviron"

        for i in 1 2; do
            run_rscript "
                if (!requireNamespace('pak', quietly = TRUE)) {
                    message('[INFO] Attempt $i to install pak...')
                    tryCatch(
                        renvvv::renvvv_install('pak'),
                        error = function(e) message('[WARN] Failed to install pak: ', e\\\$message)
                    )
                }
                try(renvvv::renvvv_install('tinytest', args_install = list(rebuild = TRUE)))
            "
            sleep 1
        done
    fi
}

# Function to install renvvv globally (Bootstrapping phase)
install_renvvv_global() {
    echo "[INFO] Installing renvvv globally..."
    run_rscript "if (!requireNamespace('remotes', quietly = TRUE)) install.packages('remotes')"
    run_rscript "remotes::install_github('MiguelRodo/renvvv@*release')"
}

# ==============================================================================
# MAIN WORKFLOW FUNCTIONS
# ==============================================================================

# Process a directory containing an renv lockfile
process_lockfile_dir() {
    local TARGET_DIR=$1
    local LOCK_PATH="renv.lock"

    if [ ! -f "$TARGET_DIR/$LOCK_PATH" ]; then
        echo "No lockfile found at $TARGET_DIR/$LOCK_PATH. Skipping."
        return 0
    fi

    echo "Processing lockfile $LOCK_PATH in $TARGET_DIR..."
    pushd "$TARGET_DIR" > /dev/null
    chown -R "${USERNAME}:${USERNAME}" .
    
    if [ "$CREATE_UNIFIED_LOCKFILE" = "true" ]; then
        echo "$(pwd)/$LOCK_PATH" >> /tmp/renv_lockfiles_to_combine.txt
    fi

    if [ "${INSTALL_SYSREQS}" = "true" ]; then
        if command -v apt-get >/dev/null 2>&1; then
            echo "Resolving system requirements..."
            PKGS=$(jq -r '.Packages | keys[]' "$LOCK_PATH" | paste -sd, -)
            OS_DIST=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
            OS_RELEASE=$(lsb_release -cs)
            SYSREQ_URL="https://packagemanager.posit.co/__api__/repos/1/sysreqs?all=false&pkgname=${PKGS}&distribution=${OS_DIST}&release=${OS_RELEASE}"
            APT_PKGS=$(curl -sL "$SYSREQ_URL" | jq -r '.requirements[]?.requirements?.packages[]?' | sort -u | paste -sd" " -)
            if [ -n "$APT_PKGS" ]; then
                export DEBIAN_FRONTEND=noninteractive
                read -ra pkgs <<< "$APT_PKGS"
                apt-get install -y --no-install-recommends "${pkgs[@]}"
            fi
        else
            echo "[INFO] System requirements auto-install only supported on Debian/Ubuntu; skipping on this OS."
        fi
    fi

    # Recursive Strip & Purge (Security)
    if [ -n "$PKG_EXCLUDE" ]; then
        echo "Recursively stripping skipped packages and purging cache..."
        run_rscript "
            skip_list <- trimws(unlist(strsplit('${PKG_EXCLUDE}', ',')))
            lock_path <- '${LOCK_PATH}'
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
        "
    fi

    echo "Warming cache from $TARGET_DIR..."

    install_gitcreds
    install_renvvv_local
    setup_pak

    # Construct the robust renvvv command based on feature options
    if [ "$RESTORE" = "true" ] && [ "$UPDATE" = "true" ]; then
        R_CMD="renvvv::renvvv_restore_and_update()"
    elif [ "$UPDATE" = "true" ]; then
        R_CMD="renvvv::renvvv_update()"
    elif [ "$RESTORE" = "true" ]; then
        R_CMD="renvvv::renvvv_restore()"
    else
        R_CMD="message('Neither restore nor update selected; skipping.')"
    fi

    run_rscript "${R_CMD}"
    popd > /dev/null
}

create_path_post_create_command() {
    PATH_POST_CREATE_COMMAND=/usr/local/bin/renv-cache-post-create
    initialize_command_file "$PATH_POST_CREATE_COMMAND"
}

initialize_command_file() {
    local file_path="$1"
    if [ ! -f "$file_path" ]; then
        printf '#!/usr/bin/env bash\n' > "$file_path"
    else
        if ! grep -q '^#!/usr/bin/env bash' "$file_path"; then
            local tmp_file
            tmp_file=$(mktemp)
            { echo '#!/usr/bin/env bash'; cat "$file_path"; } > "$tmp_file"
            mv "$tmp_file" "$file_path"
        fi
    fi
    chmod 755 "$file_path"
}

copy_and_set_execute_bit() {
    local script_name="$1"
    if ! cp "cmd/$script_name" "/usr/local/bin/renv-cache-$script_name"; then
        echo "Failed to copy cmd/$script_name"
    fi
    if ! chmod 755 "/usr/local/bin/renv-cache-$script_name"; then
        echo "Failed to set execute bit for /usr/local/bin/renv-cache-$script_name"
    fi
}

empty_dir() {
    local directory="$1"
    if [[ -z "$directory" ]] || [[ "$directory" != /* ]]; then
        echo "[ERROR] Refusing to empty directory: '$directory' (not an absolute path)"
        return 1
    fi
    if [[ "$directory" =~ (/\.($|/)|/\.\.($|/)) ]]; then
        echo "[ERROR] Refusing to empty directory: '$directory' (unsafe segment: . or ..)"
        return 1
    fi
    local normalized="${directory}"
    while [[ "$normalized" != "/" && "$normalized" == */ ]]; do
        normalized="${normalized%/}"
    done
    if [[ "$normalized" == "/" ]] || [[ "$normalized" == "//" ]] || [[ -z "$normalized" ]]; then
        echo "[ERROR] Refusing to empty directory: '$directory' (resolves to root)"
        return 1
    fi

    if [ -d "$directory" ]; then
        if ! find "$directory" -mindepth 1 -delete 2>/dev/null; then
            shopt -s dotglob nullglob
            rm -rf -- "${directory:?}"/*
            shopt -u dotglob nullglob
        fi
    else
        echo "Directory '$directory' does not exist."
    fi
}

rm_dirs() {
    if [ -z "$1" ]; then
        return
    fi
    for dir in "$@"; do
        if [[ -z "$dir" ]] || [[ "$dir" != /* ]]; then
            echo "[ERROR] Refusing to remove directory: '$dir' (not an absolute path)"
            continue
        fi
        if [[ "$dir" =~ (/\.($|/)|/\.\.($|/)) ]]; then
            echo "[ERROR] Refusing to remove directory: '$dir' (unsafe segment: . or ..)"
            continue
        fi
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

set_r_libs() {
    if [ "$SET_R_LIB_PATHS" = "true" ]; then
        chmod 755 scripts/r-lib.sh
        if ! bash scripts/r-lib.sh; then
            echo "Failed to define R library environment variables"
        fi
    fi
}

update_renv_cache() {
    if [ "$SET_R_LIB_PATHS" = "true" ]; then
        chmod 755 scripts/r-lib-update.sh
        if ! bash scripts/r-lib-update.sh; then
            echo "Failed to update R library environment variables"
        fi
    fi
}

_ORIG_GITHUB_TOKEN=""
_ORIG_GITHUB_PAT=""

set_tokens_for_install() {
    if [ "$OVERRIDE_TOKENS_AT_INSTALL" != "true" ]; then
        return
    fi
    _ORIG_GITHUB_TOKEN="${GITHUB_TOKEN:-}"
    _ORIG_GITHUB_PAT="${GITHUB_PAT:-}"

    if [ -z "$GITHUB_PAT" ]; then
        if [ -n "$GH_TOKEN" ]; then
            export GITHUB_PAT="$GH_TOKEN"
        elif [ -n "$GITHUB_TOKEN" ]; then
            export GITHUB_PAT="$GITHUB_TOKEN"
        fi
    fi

    if [ -n "$GITHUB_PAT" ]; then
        export GITHUB_TOKEN="$GITHUB_PAT"
    elif [ -n "$GH_TOKEN" ]; then
        export GITHUB_TOKEN="$GH_TOKEN"
    fi
}

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

clean_up() {
    rm_dirs /tmp/Rtmp* /tmp/rig
    if command -v apt-get >/dev/null 2>&1; then
        empty_dir /var/lib/apt/lists
    fi
}

# ==============================================================================
# EXECUTION WORKFLOW
# ==============================================================================

install_renvvv_global
create_path_post_create_command
set_r_libs
set_tokens_for_install

copy_and_set_execute_bit copy-lockfile
copy_and_set_execute_bit restore
copy_and_set_execute_bit init

# 1. Fetch Dynamic Repositories (Downloads renv.lock directly via GitHub API)
if [ -n "$REPOSITORIES" ]; then
    echo "[INFO] Fetching remote lockfiles..."
    mkdir -p "$LOCKFILE_DIR"
    IFS=',' read -ra REPO_ARRAY <<< "$REPOSITORIES"

    for REPO_SPEC in "${REPO_ARRAY[@]}"; do
        REPO_SPEC="${REPO_SPEC#"${REPO_SPEC%%[![:space:]]*}"}"
        REPO_SPEC="${REPO_SPEC%"${REPO_SPEC##*[![:space:]]}"}"
        if [[ "$REPO_SPEC" == *":"* ]]; then
            PROFILE="${REPO_SPEC##*:}"
            REPO_SPEC="${REPO_SPEC%:*}"
        else
            PROFILE=""
        fi
        if [[ "$REPO_SPEC" == *"@"* ]]; then
            REPO_PATH="${REPO_SPEC%%@*}"
            BRANCH="${REPO_SPEC##*@}"
        else
            REPO_PATH="$REPO_SPEC"
            BRANCH=""
        fi

        if [ -n "$PROFILE" ]; then
            FILE_PATH="renv/profiles/$PROFILE/renv.lock"
        else
            FILE_PATH="renv.lock"
        fi

        API_URL="https://api.github.com/repos/${REPO_PATH}/contents/${FILE_PATH}"
        if [ -n "$BRANCH" ]; then
            API_URL="${API_URL}?ref=${BRANCH}"
        fi

        echo "[INFO] Downloading ${FILE_PATH} from ${REPO_PATH}..."
        
        SAFE_NAME=$(echo "${REPO_PATH}_${BRANCH}_${PROFILE}" | sed 's/[^a-zA-Z0-9]/_/g')
        DEST_DIR="${LOCKFILE_DIR}/remote_${SAFE_NAME}"
        mkdir -p "$DEST_DIR"

        CURL_OPTS=(-s -L -w "%{http_code}" -H "Accept: application/vnd.github.v3.raw" -o "$DEST_DIR/renv.lock")
        if [ -n "$GITHUB_PAT" ]; then
            CURL_OPTS+=(-H "Authorization: Bearer $GITHUB_PAT")
        fi

        if HTTP_CODE=$(curl "${CURL_OPTS[@]}" "$API_URL"); then
            if [ "$HTTP_CODE" = "200" ]; then
                echo "[INFO] Successfully downloaded remote lockfile into $DEST_DIR"
            else
                echo "[WARN] Failed to download lockfile for ${REPO_PATH} (HTTP $HTTP_CODE). Skipping."
                rm -rf "$DEST_DIR"
            fi
        else
            echo "[WARN] curl failed while downloading lockfile for ${REPO_PATH}. Skipping."
            rm -rf "$DEST_DIR"
        fi
    done
fi

dir_array=()
if [ -n "$LOCKFILE_DIR" ] && [ -d "$LOCKFILE_DIR" ]; then
    mapfile -t dir_array < <(find "$LOCKFILE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -u)
    N_LOCKFILE=${#dir_array[@]} 
    echo "Found ${#dir_array[@]} directories."
else
    N_LOCKFILE=0
    echo "[INFO] No valid local lockfile directory specified or found at $LOCKFILE_DIR. Skipping local lockfile processing."
fi

if [ "$CREATE_UNIFIED_LOCKFILE" = "auto" ]; then
    if [ "$N_LOCKFILE" -gt 1 ] || [ -n "$PKG" ]; then
        CREATE_UNIFIED_LOCKFILE=true
    else
        CREATE_UNIFIED_LOCKFILE=false
    fi
fi

# 2. Process All Cached Lockfiles (Local + Remote)
if [ "${#dir_array[@]}" -gt 0 ]; then
    for dir in "${dir_array[@]}"; do
        process_lockfile_dir "$dir"
    done
fi

# 3. Process Explicit Packages (No Lockfile)
if [ -n "$PKG" ]; then
    TMP_PKG_DIR=$(mktemp -d)
    chown "${USERNAME}:${USERNAME}" "$TMP_PKG_DIR"
    pushd "$TMP_PKG_DIR" > /dev/null

    echo "Warming cache with explicit packages: ${PKG}..."
    init_bare_renv
    install_gitcreds
    install_renvvv_local
    setup_pak

    run_rscript "
        pkgs <- trimws(unlist(strsplit('${PKG}', ',')))
        try(renvvv::renvvv_install(pkgs))
    "

    popd > /dev/null
    rm -rf "$TMP_PKG_DIR"
fi

# 4. Generate Single Unified Lockfile
if [ "$CREATE_UNIFIED_LOCKFILE" = "true" ]; then
    echo "=========================================================="
    echo "[INFO] Building unified renv.lock file..."
    UNIFIED_DIR="/usr/local/share/renv-cache/unified_project"
    mkdir -p "$UNIFIED_DIR"
    chown -R "${USERNAME}:${USERNAME}" "$UNIFIED_DIR"
    pushd "$UNIFIED_DIR" > /dev/null
    
    init_bare_renv
    install_gitcreds
    install_renvvv_local
    setup_pak

    # 4a. Extract all dependency packages (from both lockfiles and explicit PKG) and generate _dependencies.R
    run_rscript "
        lockfiles <- if (file.exists('/tmp/renv_lockfiles_to_combine.txt')) readLines('/tmp/renv_lockfiles_to_combine.txt') else character()
        all_pkgs <- character()
        
        for (lf in lockfiles) {
            tryCatch({
                json_data <- renv:::renv_json_read(lf)
                if (!is.null(json_data\\\$Packages)) {
                    all_pkgs <- c(all_pkgs, names(json_data\\\$Packages))
                }
            }, error = function(e) message('[WARN] Could not read package names from ', lf))
        }
        
        pkg_env <- '${PKG}'
        if (nchar(pkg_env) > 0) {
            explicit_pkgs <- trimws(unlist(strsplit(pkg_env, ',')))
            all_pkgs <- c(all_pkgs, explicit_pkgs)
        }

        all_pkgs <- unique(all_pkgs)
        if (length(all_pkgs) > 0) {
            writeLines(paste0('library(', all_pkgs, ')'), '_dependencies.R')
        }
    "

    # 4b. Iteratively copy lockfiles and safely accumulate their packages (clean = FALSE)
    if [ -f /tmp/renv_lockfiles_to_combine.txt ]; then
        while IFS= read -r lf; do
            if [ -f "$lf" ]; then
                echo "[INFO] Accumulating dependencies from $lf..."
                cp "$lf" renv.lock
                chown "${USERNAME}:${USERNAME}" renv.lock
                run_rscript "renvvv::renvvv_restore(args_restore = list(clean = FALSE))"
            fi
        done < /tmp/renv_lockfiles_to_combine.txt
    fi

    # 4c. Install explicit packages into the unified project
    if [ -n "$PKG" ]; then
        echo "[INFO] Accumulating explicit packages ($PKG) into unified project..."
        run_rscript "
            pkgs <- trimws(unlist(strsplit('${PKG}', ',')))
            try(renvvv::renvvv_install(pkgs))
        "
    fi

    # 4d. Take snapshot of unified original restores
    echo "[INFO] Taking unified RESTORE snapshot..."
    DIR_UNIFIED_LOCKFILE_RESTORE="/usr/local/share/renv-cache/unified-lockfiles/restore"
    mkdir -p "$DIR_UNIFIED_LOCKFILE_RESTORE"
    chown -R "${USERNAME}:${USERNAME}" "$DIR_UNIFIED_LOCKFILE_RESTORE"
    run_rscript "renv::snapshot(lockfile = '${DIR_UNIFIED_LOCKFILE_RESTORE}/renv.lock', type = 'all', force = TRUE, prompt = FALSE)"
    
    # Revert ownership to root and set file to read-only for non-root users
    chown -R root:root "$DIR_UNIFIED_LOCKFILE_RESTORE"
    chmod 755 "$DIR_UNIFIED_LOCKFILE_RESTORE"
    chmod 644 "$DIR_UNIFIED_LOCKFILE_RESTORE/renv.lock"

    # 4e. Apply updates and take updated snapshot
    if [ "$UPDATE" = "true" ]; then
        echo "[INFO] Updating unified project..."
        run_rscript "renvvv::renvvv_update()"
        
        echo "[INFO] Taking unified UPDATE snapshot..."
        DIR_UNIFIED_LOCKFILE_UPDATE="/usr/local/share/renv-cache/unified-lockfiles/update"
        mkdir -p "$DIR_UNIFIED_LOCKFILE_UPDATE"
        chown -R "${USERNAME}:${USERNAME}" "${DIR_UNIFIED_LOCKFILE_UPDATE}"
        run_rscript "renv::snapshot(lockfile = '${DIR_UNIFIED_LOCKFILE_UPDATE}/renv.lock', type = 'all', force = TRUE, prompt = FALSE)"
        
        # Revert ownership to root and set file to read-only for non-root users
        chown -R root:root "$DIR_UNIFIED_LOCKFILE_UPDATE"
        chmod 755 "$DIR_UNIFIED_LOCKFILE_UPDATE"
        chmod 644 "$DIR_UNIFIED_LOCKFILE_UPDATE/renv.lock"
    fi

    # 4f. Purge orphaned packages and old versions from the global cache
    if [ "$PURGE_POST_UNIFICATION" != "none" ]; then
        echo "[INFO] Purging global cache using strategy: ${PURGE_POST_UNIFICATION}..."
        run_rscript "
            cache_path <- renv::paths\\\$cache()
            if (!dir.exists(cache_path)) {
                message('[INFO] No renv cache found at ', cache_path, '; skipping purge.')
                quit(status = 0)
            }

            keep_pkgs <- list()
            add_to_keep <- function(lf) {
                if (file.exists(lf)) {
                    lf_data <- tryCatch(renv:::renv_json_read(lf), error = function(e) NULL)
                    if (!is.null(lf_data\\\$Packages)) {
                        for (pkg in names(lf_data\\\$Packages)) {
                            ver <- lf_data\\\$Packages[[pkg]]\\\$Version
                            keep_pkgs[[pkg]] <<- unique(c(keep_pkgs[[pkg]], ver))
                        }
                    }
                }
            }

            purge_strategy <- '${PURGE_POST_UNIFICATION}'
            update <- '${UPDATE}'

            if (purge_strategy == 'keep-both') {
                if (update == 'true') {
                    message('[INFO] Purging, keeping both the restore- and update-based unified lockfile packages.')
                    add_to_keep('/usr/local/share/renv-cache/unified-lockfiles/restore/renv.lock')
                    add_to_keep('/usr/local/share/renv-cache/unified-lockfiles/update/renv.lock')
                } else {
                    message('[INFO] Purging, keeping the restore-based unified lockfile packages only (update is false).')
                    add_to_keep('/usr/local/share/renv-cache/unified-lockfiles/restore/renv.lock')
                }
            }
            if (purge_strategy == 'keep-one') {
                if (update == 'true') {
                    message('[INFO] Purging, keeping the update-based unified lockfile packages only.')
                    add_to_keep('/usr/local/share/renv-cache/unified-lockfiles/update/renv.lock')
                } else {
                    message('[INFO] Purging, keeping the restore-based unified lockfile packages only (update is false).')
                    add_to_keep('/usr/local/share/renv-cache/unified-lockfiles/restore/renv.lock')
                }
            }

            core_tools <- c('renv', 'renvvv', 'remotes', 'cli', 'jsonlite', 'yaml', 'pak')
            desc_files <- list.files(cache_path, pattern = '^DESCRIPTION$', recursive = TRUE, full.names = TRUE)

            pkg_id_purged  <- character()
            pkg_id_kept_core     <- character()
            pkg_id_kept_lockfile <- character()
            pkg_id_failed  <- character()
            pkg_id_invalid <- list()

            for (desc in desc_files) {
                result_purge <- tryCatch({
                    dcf        <- try(read.dcf(desc))
                    pkg_name   <- try(as.character(dcf[1, 'Package']))
                    pkg_version <- try(as.character(dcf[1, 'Version']))

                    is_valid_pkg     <- tryCatch(!is.null(pkg_name)    && length(pkg_name) == 1L    && nzchar(pkg_name)    && !is.na(pkg_name),    error = function(e) FALSE)
                    is_valid_version <- tryCatch(!is.null(pkg_version) && length(pkg_version) == 1L && nzchar(pkg_version) && !is.na(pkg_version), error = function(e) FALSE)

                    if (!is_valid_pkg || !is_valid_version) {
                        pkg_id_invalid <<- append(pkg_id_invalid, list(list(
                            desc_path   = desc,
                            pkg_name    = if (is_valid_pkg)      pkg_name    else NA_character_,
                            pkg_version = if (is_valid_version) pkg_version else NA_character_
                        )))
                        return(NULL)
                    }

                    pkg_id <- paste0(pkg_name, '@', pkg_version)

                    if (pkg_id %in% pkg_id_purged) {
                        return(NULL)
                    } 

                    if (pkg_name %in% core_tools) {
                        pkg_id_kept_core <<- c(pkg_id_kept_core, pkg_id)
                        return(NULL)
                    } else if (pkg_name %in% names(keep_pkgs)) {
                        target_versions <- keep_pkgs[[pkg_name]]
                        if (!is.null(target_versions) && length(target_versions) > 0L && pkg_version %in% target_versions) {
                            pkg_id_kept_lockfile <<- c(pkg_id_kept_lockfile, pkg_id)
                            return(NULL)
                        }
                    }

                    err_msg <- NULL
                    purged <- tryCatch(
                        { renv::purge(pkg_name, version = pkg_version, prompt = FALSE); TRUE },
                        error = function(e) { err_msg <<- e\\\$message; FALSE }
                    )

                    if (!purged) {
                        pkg_id_failed <<- c(pkg_id_failed, paste0(pkg_id, if (!is.null(err_msg)) paste0(' (', err_msg, ')') else ''))
                        return(NULL)
                    }

                    pkg_id
                }, error = function(e) NULL)

                if (!is.null(result_purge) && length(result_purge) == 1L && is.character(result_purge) && nzchar(result_purge)) {
                    pkg_id_purged <- c(pkg_id_purged, result_purge)
                }
            }

            message('==========================================================')
            message('PURGE SUMMARY (strategy: ', purge_strategy, ')')
            message('==========================================================')
            message('Total DESCRIPTION files scanned : ', length(desc_files))
            message('Kept (core tools)               : ', length(pkg_id_kept_core))
            message('Kept (in unified lockfile)      : ', length(pkg_id_kept_lockfile))
            message('Purged                          : ', length(pkg_id_purged))
            message('Failed to purge                 : ', length(pkg_id_failed))
            message('Invalid / skipped               : ', length(pkg_id_invalid))

            if (length(pkg_id_purged) > 0) {
                message('')
                message('--- Purged packages ---')
                for (p in sort(pkg_id_purged)) message('  - ', p)
            }

            pkg_id_kept <- c(pkg_id_kept_core, pkg_id_kept_lockfile)
            if (length(pkg_id_kept) > 0) {
                message('')
                message('--- Kept packages ---')
                for (p in sort(pkg_id_kept)) message('  + ', p)
            }

            if (length(pkg_id_failed) > 0) {
                message('')
                message('--- Failed to purge ---')
                for (p in pkg_id_failed) message('  ! ', p)
            }

            if (length(pkg_id_invalid) > 0) {
                message('')
                message('--- Invalid cache entries ---')
                for (entry in pkg_id_invalid) {
                    message('  ? ', entry\\\$desc_path,
                            ' (name: ', if (is.na(entry\\\$pkg_name)) '<missing>' else entry\\\$pkg_name,
                            ', version: ', if (is.na(entry\\\$pkg_version)) '<missing>' else entry\\\$pkg_version, ')')
                }
            }
            message('==========================================================')
        "
    fi

    popd > /dev/null
    rm -rf "$UNIFIED_DIR"
    echo "=========================================================="
else
    echo "[INFO] createUnifiedLockfile is false; skipping unified lockfile generation."
fi

# 5. Final Purge of Excluded Packages
if [ -n "$PKG_EXCLUDE" ]; then
    echo "[INFO] Performing final sweep to purge excluded packages from the global cache..."
    run_rscript "
        skip_list <- trimws(unlist(strsplit('${PKG_EXCLUDE}', ',')))
        for (pkg in skip_list) {
            if (nzchar(pkg)) {
                tryCatch({
                    renv::purge(pkg, prompt = FALSE)
                    message('  - Purged ', pkg, ' from global cache.')
                }, error = function(e) NULL)
            }
        }
    "
fi

if [ -f /tmp/renv_lockfiles_to_combine.txt ]; then
    rm -f /tmp/renv_lockfiles_to_combine.txt
fi

echo "renv-cache installation complete!"
reset_tokens_after_install
clean_up
