#!/usr/bin/env bash
set -e

# Must be root
[ "$(id -u)" -eq 0 ] || { echo "Please run as root (or via sudo)." >&2; exit 1; }

# Options
INSTALL_REPOS=${INSTALLREPOS:-true}
INSTALL_SETUPMJR=${INSTALLSETUPMJR:-true}
RUN_ON_START=${RUNONSTART:-false}

if [ "${INSTALL_REPOS}" = "false" ] && [ "${INSTALL_SETUPMJR}" = "false" ]; then
    echo "Both installRepos and installSetupmjr are false. Nothing to do."
    exit 0
fi

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

# ── Install dependencies ───────────────────────────────────────────────────
echo "Installing dependencies based on package manager..."
if [ "$OS_ID" = "ubuntu" ] || [ "$OS_ID" = "debian" ]; then
    apt-get update
    apt-get install -y curl gnupg ca-certificates wget git
elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache bash curl git jq github-cli
elif command -v yum >/dev/null 2>&1; then
    yum install -y bash curl git jq gh
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y bash curl git jq gh
elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm bash curl git jq github-cli
else
    echo "Warning: Unknown package manager. Assuming dependencies are already installed."
    echo "Required dependencies: bash, curl, git, jq, gh"
fi

# ── Setup APT Repositories for Debian/Ubuntu (if needed) ───────────────────
if [ "$OS_ID" = "ubuntu" ] || [ "$OS_ID" = "debian" ]; then
    if [ "${INSTALL_REPOS}" = "true" ]; then
        echo "Setting up Miguel Rodo APT repository..."
        curl -fsSL https://miguelrodo.github.io/apt-miguelrodo/KEY.gpg \
          | gpg --dearmor -o /usr/share/keyrings/apt-miguelrodo.gpg

        echo "deb [signed-by=/usr/share/keyrings/apt-miguelrodo.gpg] https://miguelrodo.github.io/apt-miguelrodo stable main" \
          > /etc/apt/sources.list.d/apt-miguelrodo.list

        echo "Setting up GitHub CLI repository..."
        mkdir -p -m 755 /etc/apt/keyrings
        wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
        chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null

        apt-get update
    fi
fi

# ── Install repos ─────────────────────────────────────────────────────────
if [ "${INSTALL_REPOS}" = "true" ]; then
    echo "Installing repos..."
    if [ "$OS_ID" = "ubuntu" ] || [ "$OS_ID" = "debian" ]; then
        echo "Using APT installation method for repos..."
        apt-get install -y repos gh jq
    else
        echo "Using Local Release Installer for repos..."
        MISSING_DEPS=()
        if ! hash bash git curl jq gh 2>/dev/null; then
            for dep in bash git curl jq gh; do
                if ! command -v "$dep" >/dev/null 2>&1; then
                    MISSING_DEPS+=("$dep")
                fi
            done
        fi

        if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
            echo "Error: Missing required dependencies: ${MISSING_DEPS[*]}" >&2
            echo "Please install them manually for your system." >&2
            exit 1
        fi

        TEMP_DIR=$(mktemp -d)
        git clone https://github.com/MiguelRodo/repos.git "$TEMP_DIR/repos"

        cd "$TEMP_DIR/repos"
        bash install-local.sh
        cd - >/dev/null

        rm -rf "${TEMP_DIR:?}"
    fi
fi

# ── Install setupmjr ──────────────────────────────────────────────────────
if [ "${INSTALL_SETUPMJR}" = "true" ]; then
    echo "Installing setupmjr..."
    MISSING_DEPS=()
    if ! hash bash git curl 2>/dev/null; then
        for dep in bash git curl; do
            if ! command -v "$dep" >/dev/null 2>&1; then
                MISSING_DEPS+=("$dep")
            fi
        done
    fi

    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies: ${MISSING_DEPS[*]}" >&2
        echo "Please install them manually for your system." >&2
        exit 1
    fi

    echo "Using Local Release Installer for setupmjr..."
    TEMP_DIR=$(mktemp -d)
    git clone https://github.com/MiguelRodo/setupmjr.git "$TEMP_DIR/setupmjr"

    cd "$TEMP_DIR/setupmjr"
    bash install-local.sh
    cd - >/dev/null

    rm -rf "${TEMP_DIR:?}"
fi

# ── Cleanup Debian/Ubuntu ─────────────────────────────────────────────────
if [ "$OS_ID" = "ubuntu" ] || [ "$OS_ID" = "debian" ]; then
    echo "Cleaning up APT..."
    apt-get clean
    rm -rf /var/lib/apt/lists/*
fi

# ── Configure start script ───────────────────────────────────────────────────
echo "Configuring post-start script..."
POST_START_SCRIPT="/usr/local/bin/utils-post-start"

cat > "$POST_START_SCRIPT" << 'EOF'
#!/usr/bin/env bash
EOF

if [ "${INSTALL_REPOS}" = "true" ] && [ "${RUN_ON_START}" = "true" ]; then
  cat >> "$POST_START_SCRIPT" << 'EOF'
# Check if repos.list exists in the workspace
REPOS_LIST="${REPOS_LIST:-repos.list}"
if [ -f "$REPOS_LIST" ]; then
  repos clone
else
  echo "Info: No repos.list file found. Skipping repository setup."
  echo "Create a repos.list file and run 'repos clone' to clone repositories."
fi
EOF
fi

chmod +x "$POST_START_SCRIPT"

echo "MiguelRodo Utils feature installation complete!"