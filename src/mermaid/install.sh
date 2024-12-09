#!/usr/bin/env bash
set -e

# Set non-interactive frontend to avoid debconf prompts
export DEBIAN_FRONTEND=noninteractive

# Configurable variables (can be overridden by feature options in devcontainer-feature.json)
USERNAME="${USERNAME:-"mermaiduser"}"
CONFIG_DIR="${PUPPETEERCONFIGDIR:-"/usr/local/share/mermaid-config"}"
PUPPETEER_CONFIG="$CONFIG_DIR/puppeteer-config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_SCRIPT="$SCRIPT_DIR/cmd/mmdc"
INSTALL_DIR="/usr/local/bin"
INSTALL_PATH="$INSTALL_DIR/mermaid-mmdc"


message_starting() {
    echo "=============================================="
    echo "Starting Mermaid DevContainer Feature Installation"
    echo "=============================================="
}

get_ubuntu_codename() {
    if command -v lsb_release &>/dev/null; then
        lsb_release -sc
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$VERSION_CODENAME"
    else
        echo "unknown"
    fi
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Error: install.sh must be run as root."
        exit 1
    fi
    echo "[INFO] Verified script is running as root."
}

create_non_root_user() {
    if ! id "$USERNAME" &>/dev/null; then
        echo "[INFO] Creating non-root user: $USERNAME"
        useradd --system --shell /bin/bash "$USERNAME"
    else
        echo "[INFO] User '$USERNAME' already exists. Skipping user creation."
    fi

    if [ ! -d "/home/$USERNAME" ]; then
        echo "[INFO] Creating home directory for user '$USERNAME'..."
        mkdir -p "/home/$USERNAME"
    fi

    chown "$USERNAME":"$USERNAME" "/home/$USERNAME"
    usermod -d "/home/$USERNAME" "$USERNAME"
    echo "[INFO] User '$USERNAME' setup complete."
}

install_dependencies() {
    echo "[INFO] Updating package lists..."
    apt-get update -y

    echo "[INFO] Installing necessary dependencies..."
    apt-get install -y curl gnupg ca-certificates build-essential libssl-dev \
        libx11-xcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 \
        libxi6 libxrandr2 libxrender1 libxss1 libxtst6 libnss3 libgbm1 \
        fonts-liberation libappindicator3-1 libatk-bridge2.0-0 libgtk-3-0 sudo

    if apt-cache show libasound2t64 &>/dev/null; then
        apt-get install -y libasound2t64
    elif apt-cache show liboss4-salsa-asound2 &>/dev/null; then
        apt-get install -y liboss4-salsa-asound2
    else
        echo "[ERROR] No compatible libasound2 package found."
        exit 1
    fi

    # Verify installations
    for cmd in curl gnupg node npm npx sudo; do
        if ! command -v $cmd &>/dev/null; then
            echo "[WARNING] Command '$cmd' not found after installation. Check dependency installation."
        fi
    done

    echo "[INFO] Cleaning up APT cache..."
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    echo "[INFO] Dependencies installation complete."
}

install_nodejs() {
    # Before installing Node.js, remove any conflicts
    remove_nodejs_conflicts
    detect_ubuntu_codename
    install_nodejs_actual
    verify_nodejs_installation
}

remove_nodejs_conflicts() {
    echo "[INFO] Removing conflicting Node.js packages if any..."
    pkg_array=(libnode-dev nodejs npm)
    for pkg in "${pkg_array[@]}"; do
        if dpkg -l | grep -q $pkg; then
            apt-get purge -y "$pkg"
        fi
    done
    apt-get autoremove -y
    echo "[INFO] Conflicting packages removed."
}

detect_ubuntu_codename() {
    UBUNTU_CODENAME=$(get_ubuntu_codename)
    if [ "$UBUNTU_CODENAME" = "unknown" ]; then
        echo "[ERROR] Unable to detect Ubuntu codename."
        exit 1
    fi
    echo "[INFO] Detected Ubuntu codename: $UBUNTU_CODENAME"
}

install_nodejs_actual() {
    echo "[INFO] Attempting Node.js 18.x LTS installation via NodeSource..."
    if curl -fsSL https://deb.nodesource.com/setup_18.x | bash -; then
        echo "[INFO] Installing Node.js 18.x from NodeSource..."
        apt-get install -y nodejs
    else
        echo "[WARNING] NodeSource installation failed. Falling back to nvm..."
        # If NodeSource fails, use nvm
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
        nvm install --lts
        nvm use --lts
        export PATH="$NVM_DIR/versions/node/$(nvm version)/bin:$PATH"
    fi
}

verify_nodejs_installation() {
    if ! command -v node &>/dev/null; then
        echo "[ERROR] Node.js installation failed."
        exit 1
    fi
    echo "[INFO] Node.js installed: $(node -v)"

    if ! command -v npm &>/dev/null; then
        echo "[ERROR] npm installation failed."
        exit 1
    fi
    echo "[INFO] npm installed: $(npm -v)"
}

setup_mermaid() {
    # Check if mmdc is already installed
    if command -v mmdc &>/dev/null; then
        echo "[INFO] Mermaid CLI (mmdc) already installed. Skipping re-installation."
    else
        install_mermaid_cli
    fi
    setup_puppeteer
    ensure_wrapper_script
}

install_mermaid_cli() {
    echo "[INFO] Installing Mermaid CLI globally using npm..."
    npm install -g @mermaid-js/mermaid-cli
    echo "[INFO] Mermaid CLI installed: $(mmdc -V)"

    # Create a symlink if not already existing
    if [ ! -x "$(command -v mmdc)" ]; then
        echo "[WARNING] 'mmdc' not found in PATH after installation. Attempting to symlink."
        NPM_GLOBAL_BIN="$(npm config get prefix)/bin"
        if [ -x "$NPM_GLOBAL_BIN/mmdc" ]; then
            [ -w "$INSTALL_DIR" ] || (echo "[ERROR] $INSTALL_DIR is not writable." && exit 1)
            ln -sf "$NPM_GLOBAL_BIN/mmdc" /usr/local/bin/mmdc
            echo "[INFO] Symlinked 'mmdc' to /usr/local/bin/mmdc."
        else
            echo "[ERROR] 'mmdc' not found in $NPM_GLOBAL_BIN. Mermaid CLI may not have installed correctly."
            exit 1
        fi
    fi
}

setup_puppeteer() {
    echo "[INFO] Installing Puppeteer dependencies (Chrome headless shell) for $USERNAME..."
    su - "$USERNAME" -c "npx puppeteer browsers install chrome-headless-shell" || {
        echo "[ERROR] Puppeteer installation failed."
        exit 1
    }
    create_puppeteer_config
}

create_puppeteer_config() {
    echo "[INFO] Creating shared configuration directory at $CONFIG_DIR..."
    mkdir -p "$CONFIG_DIR"

    echo "[INFO] Creating Puppeteer configuration file at $PUPPETEER_CONFIG..."
    cat > "$PUPPETEER_CONFIG" <<EOF
{
  "args": ["--no-sandbox", "--disable-setuid-sandbox"]
}
EOF

    chown "$USERNAME":"$USERNAME" "$PUPPETEER_CONFIG"
    chmod 644 "$PUPPETEER_CONFIG"
    echo "[INFO] Puppeteer configuration file created and permissions set."
}

ensure_wrapper_script() {
    echo "[INFO] Ensuring wrapper script exists and is executable..."
    if [ ! -f "$WRAPPER_SCRIPT" ]; then
        echo "[ERROR] Wrapper script $WRAPPER_SCRIPT not found."
        exit 1
    fi

    [ -w "$INSTALL_DIR" ] || (echo "[ERROR] $INSTALL_DIR is not writable." && exit 1)
    cp "$WRAPPER_SCRIPT" "$INSTALL_PATH"
    chmod 755 "$INSTALL_PATH"
    echo "[INFO] Wrapper script installed at $INSTALL_PATH"
}

message_ended() {
    echo "=============================================="
    echo "Mermaid environment setup complete."
    echo "=============================================="
    echo "Use 'mermaid-mmdc --help' for usage information."
}

main() {
    message_starting
    check_root
    create_non_root_user
    install_dependencies
    install_nodejs
    setup_mermaid
    message_ended
}

main
