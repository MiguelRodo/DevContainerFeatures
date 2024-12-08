#!/usr/bin/env bash
set -e

USERNAME="mermaiduser"
CONFIG_DIR="/usr/local/share/mermaid-config"
PUPPETEER_CONFIG="$CONFIG_DIR/puppeteer-config.json"
WRAPPER_SCRIPT="/usr/local/bin/mermaid-mmdc"

if [ "$EUID" -ne 0 ]; then
    echo "Error: install.sh must be run as root."
    exit 1
fi

# Create the non-root user without a home directory, if it doesn't exist
if ! id "$USERNAME" &>/dev/null; then
    useradd --system --shell /bin/bash --no-create-home "$USERNAME"
fi

# Update packages and install dependencies
apt-get update -y
apt-get install -y curl gnupg ca-certificates build-essential libssl-dev \
    libx11-xcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 \
    libxi6 libxrandr2 libxrender1 libxss1 libxtst6 libnss3 libgbm1 \
    fonts-liberation libappindicator3-1 libatk-bridge2.0-0 libgtk-3-0 libasound2
apt-get clean
rm -rf /var/lib/apt/lists/*

# Install Node.js (LTS) and npm
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# Install Mermaid CLI globally
npm install -g @mermaid-js/mermaid-cli

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
            # Encountered an option that's not recognized by this script.
            # Stop parsing here, remaining args go to mmdc.
            break
            ;;
        *)
            # Positional argument (likely an mmdc arg), stop parsing
            break
            ;;
    esac
done

# After parsing known options, $@ holds arguments intended for mmdc
if ! command -v mmdc &>/dev/null; then
    echo "Error: 'mmdc' command not found."
    exit 1
fi

# Construct the command
CMD="mmdc -c \"$CONFIG_FILE\" $*"

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

chmod +x "$WRAPPER_SCRIPT"

echo "Mermaid environment setup complete."
echo "Use 'mermaid-mmdc --help' for usage information."
