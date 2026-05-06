#!/usr/bin/env bash
set -e

# Must be root
[ "$(id -u)" -eq 0 ] || { echo "Please run as root (or via sudo)." >&2; exit 1; }

# ── Detect OS ────────────────────────────────────────────────────────────────
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

OS_ID=$(detect_os)
echo "Detected OS: $OS_ID"

# ── Install based on OS type ─────────────────────────────────────────────────
if [ "$OS_ID" = "ubuntu" ] || [ "$OS_ID" = "debian" ]; then
    echo "Using APT installation method for Debian/Ubuntu..."
    
    # Install prerequisites
    echo "Installing prerequisites..."
    apt-get update
    apt-get install -y curl gnupg ca-certificates
    
    # Setup APT repository
    echo "Setting up APT repository..."
    curl -fsSL https://raw.githubusercontent.com/MiguelRodo/apt-miguelrodo/main/KEY.gpg \
    | gpg --dearmor -o /usr/share/keyrings/miguelrodo-repos.gpg
    
    echo "deb [signed-by=/usr/share/keyrings/miguelrodo-repos.gpg] https://raw.githubusercontent.com/MiguelRodo/apt-miguelrodo/main/ ./" \
      > /etc/apt/sources.list.d/miguelrodo-repos.list
    
    # Install repos package
    echo "Installing repos package..."
    apt-get update
    apt-get install -y repos
    
    # Cleanup
    echo "Cleaning up..."
    apt-get clean
    rm -rf /var/lib/apt/lists/*
else
    echo "Using source installation method for non-Debian/Ubuntu systems..."
    
    # Install dependencies based on package manager
    if command -v apk >/dev/null 2>&1; then
        echo "Installing dependencies via apk (Alpine)..."
        apk add --no-cache bash git curl jq
    elif command -v yum >/dev/null 2>&1; then
        echo "Installing dependencies via yum (RHEL/CentOS)..."
        yum install -y bash git curl jq
    elif command -v dnf >/dev/null 2>&1; then
        echo "Installing dependencies via dnf (Fedora)..."
        dnf install -y bash git curl jq
    elif command -v pacman >/dev/null 2>&1; then
        echo "Installing dependencies via pacman (Arch)..."
        pacman -Sy --noconfirm bash git curl jq
    else
        echo "Warning: Unknown package manager. Assuming dependencies are already installed."
        echo "Required dependencies: bash, git, curl, jq"
    fi
    
    # Check for required dependencies
    MISSING_DEPS=()
    for dep in bash git curl jq; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            MISSING_DEPS+=("$dep")
        fi
    done
    
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies: ${MISSING_DEPS[*]}" >&2
        echo "Please install them manually for your system." >&2
        exit 1
    fi
    
    # Clone repos from GitHub
    echo "Cloning repos from GitHub..."
    TEMP_DIR=$(mktemp -d)
    git clone https://github.com/MiguelRodo/repos.git "$TEMP_DIR/repos"
    
    # Install to system directories
    echo "Installing repos to system directories..."
    mkdir -p /usr/local/share/repos
    cp -r "$TEMP_DIR/repos/scripts" /usr/local/share/repos/
    
    # Make all shell scripts executable
    find /usr/local/share/repos/scripts -type f -name "*.sh" -exec chmod +x {} \;
    
    # Create wrapper script in /usr/local/bin
    cat > /usr/local/bin/repos << 'WRAPPER_EOF'
#!/usr/bin/env bash
# repos - Multi-repository management tool wrapper
# Dispatches subcommands to the appropriate script

set -euo pipefail

SCRIPT_DIR="/usr/local/share/repos/scripts"

usage() {
  cat <<EOF
Usage: repos <command> [options]

Commands:
  clone       Clone repositories listed in repos.list into the parent directory
  workspace   Generate (or update) the VS Code multi-root workspace file
  codespace   Configure GitHub Codespaces authentication
  codespaces  Alias for codespace
  run         Execute a script inside each cloned repository

Run 'repos <command> --help' for more information on a command.
EOF
}

if [ $# -eq 0 ]; then
  usage >&2; exit 1
fi

case "$1" in
  -h|--help)
    usage; exit 0 ;;
  clone)
    shift
    [ -f "$SCRIPT_DIR/helper/clone-repos.sh" ] || { echo "Error: clone-repos.sh not found at $SCRIPT_DIR/helper/clone-repos.sh" >&2; exit 1; }
    exec "$SCRIPT_DIR/helper/clone-repos.sh" "$@" ;;
  workspace)
    shift
    [ -f "$SCRIPT_DIR/helper/vscode-workspace-add.sh" ] || { echo "Error: vscode-workspace-add.sh not found at $SCRIPT_DIR/helper/vscode-workspace-add.sh" >&2; exit 1; }
    exec "$SCRIPT_DIR/helper/vscode-workspace-add.sh" "$@" ;;
  codespace|codespaces)
    shift
    [ -f "$SCRIPT_DIR/helper/codespaces-auth-add.sh" ] || { echo "Error: codespaces-auth-add.sh not found at $SCRIPT_DIR/helper/codespaces-auth-add.sh" >&2; exit 1; }
    exec "$SCRIPT_DIR/helper/codespaces-auth-add.sh" "$@" ;;
  run)
    shift
    [ -f "$SCRIPT_DIR/run-pipeline.sh" ] || { echo "Error: run-pipeline.sh not found at $SCRIPT_DIR/run-pipeline.sh" >&2; exit 1; }
    exec "$SCRIPT_DIR/run-pipeline.sh" "$@" ;;
  *)
    echo "Error: unknown command '$1'" >&2; echo "" >&2; usage >&2; exit 1 ;;
esac
WRAPPER_EOF
    
    chmod +x /usr/local/bin/repos
    
    # Cleanup
    echo "Cleaning up..."
    rm -rf "${TEMP_DIR:?}"
fi

# ── Configure start script ───────────────────────────────────────────────────
echo "Configuring post-start script..."
POST_START_SCRIPT="/usr/local/bin/repos-post-start"

# Check RUNONSTART environment variable (defaults to false if not set)
if [ "${RUNONSTART}" = "true" ]; then
  cat > "$POST_START_SCRIPT" << 'EOF'
#!/usr/bin/env bash
# Check if repos.list exists in the workspace
REPOS_LIST="${REPOS_LIST:-repos.list}"
if [ -f "$REPOS_LIST" ]; then
  repos clone
else
  echo "Info: No repos.list file found. Skipping repository setup."
  echo "Create a repos.list file and run 'repos clone' to clone repositories."
fi
EOF
else
  cat > "$POST_START_SCRIPT" << 'EOF'
#!/usr/bin/env bash
EOF
fi

# Make the script executable
chmod +x "$POST_START_SCRIPT"

echo "repos feature installation complete!"
