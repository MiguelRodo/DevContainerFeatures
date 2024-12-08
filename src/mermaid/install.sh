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

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: install.sh must be run as root."
    exit 1
fi

# Create the non-root user without a home directory, if it doesn't exist
if ! id "$USERNAME" &>/dev/null; then
    useradd --system --shell /bin/bash --no-create-home "$USERNAME"
fi

# Update package lists and install dependencies
apt-get update -y
apt-get install -y curl gnupg ca-certificates build-essential libssl-dev \
    libx11-xcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 \
    libxi6 libxrandr2 libxrender1 libxss1 libxtst6 libnss3 libgbm1 \
    fonts-liberation libappindicator3-1 libatk-bridge2.0-0 libgtk-3-0 libasound2

# Clean up APT cache
apt-get clean
rm -rf /var/lib/apt/lists/*

# Remove conflicting Node.js packages
apt-get remove -y libnode-dev nodejs npm
apt-get autoremove -y

# Detect Ubuntu codename
UBUNTU_CODENAME=$(get_ubuntu_codename)
if [ "$UBUNTU_CODENAME" = "unknown" ]; then
    echo "Error: Unable to detect Ubuntu codename."
    exit 1
fi

# Add NodeSource GPG key
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg > /dev/null

# Add NodeSource repository for Node.js LTS (ensure correct codename)
echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_lts $UBUNTU_CODENAME main" | tee /etc/apt/sources.list.d/nodesource.list
echo "deb-src [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_lts $UBUNTU_CODENAME main" | tee -a /etc/apt/sources.list.d/nodesource.list

# Update package lists to include NodeSource repository
apt-get update -y

# Install Node.js (LTS) and npm
apt-get install -y nodejs

# Verify Node.js installation
if ! command -v node &>/dev/null; then
    echo "Error: Node.js installation failed."
    exit 1
fi

# Install Mermaid CLI globally
npm install -g @mermaid-js/mermaid-cli

# Verify Mermaid CLI installation
if ! command -v mmdc &>/dev/null; then
    echo "Error: Mermaid CLI installation failed."
    exit 1
fi

# Create shared configuration directory and Puppeteer config
mkdir -p "$CONFIG_DIR"
cat > "$PUPPETEER_CONFIG" <<EOF
{
  "args": ["--no-sandbox", "--disable-setuid-sandbox"]
}
EOF
chown "$USERNAME":"$USERNAME" "$PUPPETEER_CONFIG"
chmod 644 "$PUPPETEER_CONFIG"

# Create the wrapper script
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

# Make the wrapper script executable
chmod +x "$WRAPPER_SCRIPT"

echo "Mermaid environment setup complete."
echo "Use 'mermaid-mmdc --help' for usage information."
