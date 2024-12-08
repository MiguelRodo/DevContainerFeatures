#!/usr/bin/env bash
set -e

# Set non-interactive frontend to avoid debconf prompts
export DEBIAN_FRONTEND=noninteractive

# Variables
USERNAME="mermaiduser"
CONFIG_DIR="/usr/local/share/mermaid-config"
PUPPETEER_CONFIG="$CONFIG_DIR/puppeteer-config.json"
WRAPPER_SCRIPT="/usr/local/bin/mermaid-mmdc"

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

echo "=============================================="
echo "Starting Mermaid DevContainer Feature Installation"
echo "=============================================="

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: install.sh must be run as root."
    exit 1
fi
echo "Verified script is running as root."

# Create the non-root user without a home directory, if it doesn't exist
if ! id "$USERNAME" &>/dev/null; then
    echo "Creating non-root user: $USERNAME"
    useradd --system --shell /bin/bash --no-create-home "$USERNAME"
    echo "User '$USERNAME' created successfully."
else
    echo "User '$USERNAME' already exists. Skipping user creation."
fi

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

# Remove conflicting Node.js packages
echo "Removing conflicting Node.js packages if any..."
apt-get remove -y libnode-dev nodejs npm || echo "No conflicting Node.js packages found."
apt-get autoremove -y
echo "Conflicting packages removed."

# Detect Ubuntu codename
UBUNTU_CODENAME=$(get_ubuntu_codename)
if [ "$UBUNTU_CODENAME" = "unknown" ]; then
    echo "Error: Unable to detect Ubuntu codename."
    exit 1
fi
echo "Detected Ubuntu codename: $UBUNTU_CODENAME"

# Add NodeSource GPG key
echo "Adding NodeSource GPG key..."
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg > /dev/null
echo "NodeSource GPG key added."

# Add NodeSource repository for Node.js LTS (ensure correct codename)
echo "Adding NodeSource repository for Node.js LTS..."
echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_lts $UBUNTU_CODENAME main" | tee /etc/apt/sources.list.d/nodesource.list
echo "deb-src [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_lts $UBUNTU_CODENAME main" | tee -a /etc/apt/sources.list.d/nodesource.list
echo "NodeSource repository added."

# Update package lists to include NodeSource repository
echo "Updating package lists to include NodeSource repository..."
apt-get update -y
echo "Package lists updated."

# Install Node.js (LTS) and npm
echo "Installing Node.js (LTS) and npm..."
apt-get install -y nodejs
echo "Node.js and npm installed successfully."

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

# Create the wrapper script
echo "Creating Mermaid CLI wrapper script at $WRAPPER_SCRIPT..."
cat > "$WRAPPER_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -e

DEFAULT_USERNAME="mermaiduser"
DEFAULT_CONFIG="/usr/local/share/mermaid-config/puppeteer-config.json"

USERNAME="$DEFAULT_USERNAME"
CONFIG_FILE="$DEFAULT_CONFIG"

print_help() {
    cat <<USAGE
Usage: mermaid-mmdc [options] -- [mmdc args]

Options:
  --username=USER      Run as this user (default: $DEFAULT_USERNAME)
  --config=FILE        Puppeteer config file (default: $DEFAULT_CONFIG)
  --help               Show this help message

Examples:
  mermaid-mmdc -i input.mmd -o output.png
  mermaid-mmdc --username=anotheruser -- -i input.mmd -o output.png

If running as root, this script uses 'su' to run mmdc as USER.
If not root and 'sudo' is available, 'sudo -u USER' will be used.
Otherwise, it fails.
USAGE
}

# Parse options
while [ $# -gt 0 ]; do
    case "$1" in
        --username=*)
            USERNAME="${1#*=}"
            shift
            ;;
        --config=*)
            CONFIG_FILE="${1#*=}"
            shift
            ;;
        --help)
            print_help
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            # Unrecognized option, stop parsing
            break
            ;;
        *)
            # Positional argument, stop parsing
            break
            ;;
    esac
done

# Ensure mmdc is installed
if ! command -v mmdc &>/dev/null; then
    echo "Error: 'mmdc' command not found."
    exit 1
fi

# Construct the mmdc command with the provided config and arguments
CMD="mmdc -c \"$CONFIG_FILE\" $*"

# Execute the command as the specified user
if [ "$EUID" -eq 0 ]; then
    # Running as root
    exec su -s /bin/bash "$USERNAME" -c "$CMD"
else
    # Not running as root, check for sudo
    if command -v sudo &>/dev/null; then
        exec sudo -u "$USERNAME" bash -c "$CMD"
    else
        echo "Error: Not root and no 'sudo' available to switch user."
        exit 1
    fi
fi
EOF
echo "Wrapper script created."

# Make the wrapper script executable
echo "Making the wrapper script executable..."
chmod +x "$WRAPPER_SCRIPT"
echo "Wrapper script is now executable."

echo "=============================================="
echo "Mermaid environment setup complete."
echo "=============================================="
echo "Use 'mermaid-mmdc --help' for usage information."
