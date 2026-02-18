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
      -o /usr/share/keyrings/miguelrodo-repos.gpg
    
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
set -euo pipefail

SCRIPT_DIR="/usr/local/share/repos/scripts"
SETUP_SCRIPT="$SCRIPT_DIR/setup-repos.sh"

if [ ! -f "$SETUP_SCRIPT" ]; then
  echo "Error: setup-repos.sh not found at $SETUP_SCRIPT" >&2
  echo "The repos package may not be installed correctly." >&2
  exit 1
fi

# Execute setup-repos.sh with all passed arguments
exec "$SETUP_SCRIPT" "$@"
WRAPPER_EOF
    
    chmod +x /usr/local/bin/repos
    
    # Cleanup
    echo "Cleaning up..."
    rm -rf "$TEMP_DIR"
fi

# ── Configure start script ───────────────────────────────────────────────────
echo "Configuring post-start script..."
POST_START_SCRIPT="/usr/local/bin/repos-post-start"

# Check RUNONSTART environment variable (defaults to true if not set)
if [ "${RUNONSTART}" = "false" ]; then
  cat > "$POST_START_SCRIPT" << 'EOF'
#!/usr/bin/env bash
echo "repos start-up skipped"
EOF
else
  cat > "$POST_START_SCRIPT" << 'EOF'
#!/usr/bin/env bash
repos setup
EOF
fi

# Make the script executable
chmod +x "$POST_START_SCRIPT"

echo "repos feature installation complete!"
