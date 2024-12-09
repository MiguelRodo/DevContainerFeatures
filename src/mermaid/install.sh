#!/usr/bin/env bash
set -e

# Set non-interactive frontend to avoid debconf prompts
export DEBIAN_FRONTEND=noninteractive

# Variables
USERNAME="mermaiduser"
CONFIG_DIR="/usr/local/share/mermaid-config"
PUPPETEER_CONFIG="$CONFIG_DIR/puppeteer-config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

message_starting() {
    echo "=============================================="
    echo "Starting Mermaid DevContainer Feature Installation"
    echo "=============================================="
}

# Function to detect Ubuntu codename
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
    # Ensure the script is run as root
    if [ "$EUID" -ne 0 ]; then
        echo "Error: install.sh must be run as root."
        exit 1
    fi
    echo "Verified script is running as root."
}

create_non_root_user() {
    # Create the non-root user without a home directory, if it doesn't exist
    if ! id "$USERNAME" &>/dev/null; then
        echo "Creating non-root user: $USERNAME"
        useradd --system --shell /bin/bash --no-create-home "$USERNAME"
        echo "User '$USERNAME' created successfully."
    else
        echo "User '$USERNAME' already exists. Skipping user creation."
    fi
}

install_dependencies() {
    # Update package lists and install dependencies
    echo "Updating package lists..."
    apt-get update -y
    echo "Installing necessary dependencies..."
    apt-get install -y curl gnupg ca-certificates build-essential libssl-dev \
        libx11-xcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 \
        libxi6 libxrandr2 libxrender1 libxss1 libxtst6 libnss3 libgbm1 \
        fonts-liberation libappindicator3-1 libatk-bridge2.0-0 libgtk-3-0 libasound2
    echo "Dependencies installed successfully."
    # Clean up APT cache
    echo "Cleaning up APT cache to reduce image size..."
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    echo "APT cache cleaned."
}

install_nodejs() {
    remove_nodejs_conflicts
    detect_ubuntu_codename
    install_nodejs_actual
    verify_nodejs_installation
}

remove_nodejs_conflicts() {
    # Remove conflicting Node.js packages
    echo "Removing conflicting Node.js packages if any..."
    apt-get remove -y libnode-dev nodejs npm || echo "No conflicting Node.js packages found."
    apt-get autoremove -y
    echo "Conflicting packages removed."
}


detect_ubuntu_codename() {
    # Detect Ubuntu codename
    UBUNTU_CODENAME=$(get_ubuntu_codename)
    if [ "$UBUNTU_CODENAME" = "unknown" ]; then
        echo "Error: Unable to detect Ubuntu codename."
        exit 1
    fi
    echo "Detected Ubuntu codename: $UBUNTU_CODENAME"
}

install_nodejs_actual() {
    # Try NodeSource repository installation
    echo "Attempting Node.js LTS installation via NodeSource..."
    if curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -; then
        echo "Installing Node.js from NodeSource..."
        apt-get install -y nodejs
    else
        echo "NodeSource installation failed. Falling back to nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install --lts
        nvm use --lts
    fi
    }

verify_nodejs_installation() {
    # Verify Node.js installation
    if command -v node &>/dev/null; then
        NODE_VERSION=$(node -v)
        echo "Node.js installed: $NODE_VERSION"
    else
        echo "Error: Node.js installation failed."
        exit 1
    fi

    if command -v npm &>/dev/null; then
        NPM_VERSION=$(npm -v)
        echo "npm installed: $NPM_VERSION"
    else
        echo "Error: npm installation failed."
        exit 1
    fi
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

setup_mermaid() {
    install_mermaid_cli
    create_puppeteer_config
    copy_and_set_execute_bit mmdc
}

install_mermaid_cli() {
    echo "Installing Mermaid CLI globally using npm..."
    npm install -g @mermaid-js/mermaid-cli
    echo "Mermaid CLI installed successfully."

    if command -v mmdc &>/dev/null; then
        MMDCLI_VERSION=$(mmdc -V)
        echo "Mermaid CLI installed: $MMDCLI_VERSION"
    else
        echo "Error: Mermaid CLI installation failed."
        exit 1
    fi
    
    # If Node.js was installed via NVM, 'mmdc' might not be in the global PATH outside nvm environment.
    # To ensure 'mmdc' is accessible system-wide, create a symlink to /usr/local/bin.
    echo "Ensuring 'mmdc' is accessible system-wide..."
    NPM_GLOBAL_BIN="$(npm bin -g)"
    if [ -x "$NPM_GLOBAL_BIN/mmdc" ]; then
        # Create or update the symlink
        ln -sf "$NPM_GLOBAL_BIN/mmdc" /usr/local/bin/mmdc
        echo "Symlinked 'mmdc' to /usr/local/bin/mmdc."
    else
        echo "Warning: Could not find 'mmdc' in $NPM_GLOBAL_BIN. Make sure npm bin path is correct."
    fi
}

create_puppeteer_config() {
    # Create shared configuration directory and Puppeteer config
    echo "Creating shared configuration directory at $CONFIG_DIR..."
    mkdir -p "$CONFIG_DIR"
    echo "Creating Puppeteer configuration file at $PUPPETEER_CONFIG..."
    cat > "$PUPPETEER_CONFIG" <<EOF
{
  "args": ["--no-sandbox", "--disable-setuid-sandbox"]
}
EOF
    echo "Puppeteer configuration file created."
    # Set ownership and permissions for Puppeteer config
    echo "Setting ownership and permissions for Puppeteer config..."
    chown "$USERNAME":"$USERNAME" "$PUPPETEER_CONFIG"
    chmod 644 "$PUPPETEER_CONFIG"
    echo "Ownership and permissions set."
}

# Function to copy a script and set its execute permissions
copy_and_set_execute_bit() {
    local script_name="$1"

    # Copy the script to /usr/local/bin with a prefixed name
    if ! cp "$SCRIPT_DIR/cmd/$script_name" "/usr/local/bin/mermaid-$script_name"; then
        echo "Failed to copy cmd/$script_name"
        exit 1
    fi

    # Set execute permissions on the copied script
    if ! chmod 755 "/usr/local/bin/mermaid-$script_name"; then
        echo "Failed to set execute bit for /usr/local/bin/mermaid-$script_name"
    fi
}

message_ended() {
    echo "=============================================="
    echo "Mermaid environment setup complete."
    echo "=============================================="
    echo "Use 'mermaid-mmdc --help' for usage information."
}


main
