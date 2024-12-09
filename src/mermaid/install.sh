#!/usr/bin/env bash
set -e

# Set non-interactive frontend to avoid debconf prompts
export DEBIAN_FRONTEND=noninteractive

# Variables
USERNAME="mermaiduser"
CONFIG_DIR="/usr/local/share/mermaid-config"
PUPPETEER_CONFIG="$CONFIG_DIR/puppeteer-config.json"
WRAPPER_SCRIPT="/usr/local/bin/mermaid-mmdc"

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
        useradd --system --shell /bin/bash "$USERNAME"
        echo "User '$USERNAME' created successfully."
    else
        echo "User '$USERNAME' already exists. Skipping user creation."
    fi
    if [ ! -d "/home/$USERNAME" ]; then
        echo "Creating home directory for user '$USERNAME'..."
        mkdir -p "/home/$USERNAME"
        echo "Home directory created."
    fi
    if ! chown "$USERNAME":"$USERNAME" "/home/$USERNAME"; then
        echo "Failed to set ownership for home directory."
        exit 1
    fi
    if ! usermod -d /home/mermaiduser mermaiduser; then
        echo "Failed to set home directory for user."
        exit 1
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
    pkg_array=(libnode-dev nodejs npm)
    for pkg in "${pkg_array[@]}"; do
        apt-get purge -y "$pkg" || echo "Conflict package $pkg not found."
    done
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
    # Attempt Node.js LTS installation via NodeSource using setup_18.x
    echo "Attempting Node.js 18.x LTS installation via NodeSource..."
    if curl -fsSL https://deb.nodesource.com/setup_18.x | bash -; then
        echo "Installing Node.js 18.x from NodeSource..."
        apt-get install -y nodejs
    else
        echo "NodeSource installation failed. Falling back to nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        # Load nvm
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        # Install and use latest LTS
        nvm install --lts
        nvm use --lts
        # Ensure npm global bin is accessible
        export PATH="$NVM_DIR/versions/node/$(nvm version)/bin:$PATH"
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

setup_mermaid() {
    install_mermaid_cli
    create_puppeteer_config
    copy_and_set_execute_bit mmdc
}

install_mermaid_cli() {
    # Install Mermaid CLI globally
    echo "Installing Mermaid CLI globally using npm..."
    npm install -g @mermaid-js/mermaid-cli
    echo "Mermaid CLI installed successfully."

    # Verify Mermaid CLI installation
    if command -v mmdc &>/dev/null; then
        MMDCLI_VERSION=$(mmdc -V)
        echo "Mermaid CLI installed: $MMDCLI_VERSION"
    else
        echo "Error: Mermaid CLI installation failed."
        exit 1
    fi

    # If installed via nvm, ensure mmdc is accessible system-wide
    # Create a symlink from npm global bin to /usr/local/bin
    echo "Ensuring 'mmdc' is accessible system-wide..."
    NPM_GLOBAL_BIN="$(npm config get prefix)/bin"
    echo "Global npm bin directory: $NPM_GLOBAL_BIN"
    if [ -x "$NPM_GLOBAL_BIN/mmdc" ]; then
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

copy_and_set_execute_bit() {
    local script_name="$1"

    # Determine the directory where this script resides
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Path to the source script
    SOURCE_SCRIPT="$SCRIPT_DIR/cmd/$script_name"

    # Destination path with prefix 'mermaid-'
    DEST_SCRIPT="/usr/local/bin/mermaid-$script_name"

    # Check if the source script exists
    if [ ! -f "$SOURCE_SCRIPT" ]; then
        echo "Error: Source script '$SOURCE_SCRIPT' does not exist."
        exit 1
    fi

    # Copy the script
    echo "Copying '$SOURCE_SCRIPT' to '$DEST_SCRIPT'..."
    if ! cp "$SOURCE_SCRIPT" "$DEST_SCRIPT"; then
        echo "Failed to copy '$SOURCE_SCRIPT' to '$DEST_SCRIPT'."
        exit 1
    fi

    # Set execute permissions
    echo "Setting execute permissions for '$DEST_SCRIPT'..."
    if ! chmod 755 "$DEST_SCRIPT"; then
        echo "Failed to set execute permissions for '$DEST_SCRIPT'."
        exit 1
    fi

    echo "Wrapper script '$DEST_SCRIPT' created and made executable."
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
