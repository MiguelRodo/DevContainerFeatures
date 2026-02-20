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

ELEVATE_GITHUB_TOKEN="${ELEVATEGITHUBTOKEN:-true}"
OVERRIDE_GITHUB_TOKEN="${OVERRIDEGITHUBTOKEN:-false}"

# Function to copy a script and set its execute permissions
copy_and_set_execute_bit() {
    local script_name="$1"

    if ! cp "cmd/$script_name" "/usr/local/bin/github-tokens-$script_name"; then
        echo "Failed to copy cmd/$script_name"
    fi

    if ! chmod 755 "/usr/local/bin/github-tokens-$script_name"; then
        echo "Failed to set execute bit for /usr/local/bin/github-tokens-$script_name"
    fi
}

# Function to initialize the post-create command file
initialize_post_create_command() {
    PATH_POST_CREATE_COMMAND=/usr/local/bin/github-tokens-post-create
    if [ ! -f "$PATH_POST_CREATE_COMMAND" ]; then
        printf '#!/usr/bin/env bash\n' > "$PATH_POST_CREATE_COMMAND"
    else
        if ! grep -q '^#!/usr/bin/env bash' "$PATH_POST_CREATE_COMMAND"; then
            tmp_file=$(mktemp)
            { echo '#!/usr/bin/env bash'; cat "$PATH_POST_CREATE_COMMAND"; } > "$tmp_file"
            mv "$tmp_file" "$PATH_POST_CREATE_COMMAND"
        fi
    fi
    chmod 755 "$PATH_POST_CREATE_COMMAND"
}

main() {
    initialize_post_create_command

    # Copy scripts to /usr/local/bin/
    copy_and_set_execute_bit bashrc-d
    copy_and_set_execute_bit github-pat

    # Write configuration for the github-pat script
    mkdir -p /usr/local/etc
    cat > /usr/local/etc/github-tokens-github-pat.env << EOF
ELEVATE_GITHUB_TOKEN=$ELEVATE_GITHUB_TOKEN
OVERRIDE_GITHUB_TOKEN=$OVERRIDE_GITHUB_TOKEN
EOF

    # Add post-create steps:
    # 1. Set up ~/.bashrc.d sourcing in ~/.bashrc
    echo '/usr/local/bin/github-tokens-bashrc-d || echo "[ERROR] Failed to run github-tokens-bashrc-d"' >> "$PATH_POST_CREATE_COMMAND"

    # 2. Run github-pat once to set tokens immediately
    echo 'sudo /usr/local/bin/github-tokens-github-pat || echo "[ERROR] Failed to run github-tokens-github-pat"' >> "$PATH_POST_CREATE_COMMAND"

    # 3. Copy github-pat to ~/.bashrc.d/ so it runs on every shell startup
    echo 'mkdir -p "$HOME/.bashrc.d" && cp /usr/local/bin/github-tokens-github-pat "$HOME/.bashrc.d/github-tokens-github-pat"' >> "$PATH_POST_CREATE_COMMAND"

    echo "[OK] github-tokens feature installed successfully"
}

main
