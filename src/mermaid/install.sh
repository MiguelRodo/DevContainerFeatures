#!/usr/bin/env bash
set -e

export DEBIAN_FRONTEND=noninteractive

USERNAME="${USERNAME:-"mermaiduser"}"
CONFIG_DIR="${PUPPETEERCONFIGDIR:-"/usr/local/share/mermaid-config"}"
PUPPETEER_CONFIG="$CONFIG_DIR/puppeteer-config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_SCRIPT="$SCRIPT_DIR/cmd/mmdc"
INSTALL_DIR="/usr/local/bin"
INSTALL_PATH="$INSTALL_DIR/mermaid-mmdc"
NODE_VERSION="${NODEVERSION:-"lts"}"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Error: install.sh must be run as root."
        exit 1
    fi
}

create_non_root_user() {
    if ! id "$USERNAME" &>/dev/null; then
        echo "[INFO] Creating non-root user: $USERNAME"
        useradd --system --shell /bin/bash "$USERNAME"
        mkdir -p "/home/$USERNAME"
        chown "$USERNAME":"$USERNAME" "/home/$USERNAME"
    else
        echo "[INFO] User '$USERNAME' already exists."
    fi
}

install_dependencies() {
    echo "[INFO] Installing system dependencies..."
    apt-get update -y
    apt-get install -y --no-install-recommends \
        curl gnupg ca-certificates build-essential libssl-dev \
        libx11-xcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 \
        libxi6 libxrandr2 libxrender1 libxss1 libxtst6 libnss3 libgbm1 \
        fonts-liberation libappindicator3-1 libatk-bridge2.0-0 libgtk-3-0 sudo

    # Handle libasound2 variants for different Ubuntu versions
    if apt-cache show libasound2t64 &>/dev/null; then
        apt-get install -y libasound2t64
    else
        apt-get install -y libasound2
    fi
}

install_nodejs() {
    if command -v node &>/dev/null; then
        echo "[INFO] Node.js is already installed: $(node -v)"
    else
        echo "[INFO] Installing Node.js ${NODE_VERSION}..."
        if [ "${NODE_VERSION}" = "lts" ]; then
             curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
        else
             curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash -
        fi
        apt-get install -y nodejs
    fi
}

setup_mermaid() {
    echo "[INFO] Installing Mermaid CLI..."
    npm install -g @mermaid-js/mermaid-cli

    # Symlink if needed
    if ! command -v mmdc &>/dev/null; then
        local npm_prefix
        npm_prefix="$(npm config get prefix)"
        if [ -f "$npm_prefix/bin/mmdc" ]; then
            ln -sf "$npm_prefix/bin/mmdc" /usr/local/bin/mmdc
        fi
    fi

    # Install Chrome for Puppeteer
    echo "[INFO] Installing Chrome Headless Shell for $USERNAME..."
    # Ensure the user can write to their npm/npx cache if needed, or run as that user
    su - "$USERNAME" -c "npx puppeteer browsers install chrome-headless-shell"
}

configure_puppeteer() {
    mkdir -p "$CONFIG_DIR"
    cat > "$PUPPETEER_CONFIG" <<EOF
{
  "args": ["--no-sandbox", "--disable-setuid-sandbox"]
}
EOF
    chown "$USERNAME":"$USERNAME" "$PUPPETEER_CONFIG"
    chmod 644 "$PUPPETEER_CONFIG"
}

install_wrapper() {
    if [ -f "$WRAPPER_SCRIPT" ]; then
        cp "$WRAPPER_SCRIPT" "$INSTALL_PATH"
        chmod 755 "$INSTALL_PATH"
    else
        echo "[ERROR] Wrapper script not found at $WRAPPER_SCRIPT"
        exit 1
    fi
}

cleanup() {
    apt-get clean
    rm -rf /var/lib/apt/lists/*
}

main() {
    check_root
    create_non_root_user
    install_dependencies
    install_nodejs
    setup_mermaid
    configure_puppeteer
    install_wrapper
    cleanup
    echo "[INFO] Mermaid setup complete."
}

main
