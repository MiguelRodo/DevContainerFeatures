cat > /usr/local/bin/repos-hf-install << 'EOF'
#!/usr/bin/env bash
set -e

# ==============================================================================
# repos-hf-install
# A script to install Hugging Face CLI and Git LFS either system-wide or for
# the current user, based on provided parameters.
# ==============================================================================

# Default installation scopes
HF_SCOPE="system"
LFS_SCOPE="system"

# Function to display usage information
usage() {
    echo "Usage:"
    echo "  $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --hf-scope [user|system]     Scope to install Hugging Face CLI (default: user)"
    echo "  --lfs-scope [user|system]    Scope to install Git LFS (default: system)"
    echo "  -h, --help                   Display this help message"
    echo ""
    echo "Examples:"
    echo "  Install both Hugging Face CLI and Git LFS system-wide:"
    echo "    $(basename "$0") --hf-scope system --lfs-scope system"
    echo ""
    echo "  Install Hugging Face CLI for the user and Git LFS system-wide:"
    echo "    $(basename "$0") --hf-scope user --lfs-scope system"
    echo ""
    echo "  Install both tools for the user:"
    echo "    $(basename "$0") --hf-scope user --lfs-scope user"
    exit 1
}

# Function to parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --hf-scope)
                if [[ "$2" == "user" || "$2" == "system" ]]; then
                    HF_SCOPE="$2"
                    shift 2
                else
                    echo "Error: Invalid value for --hf-scope: $2"
                    usage
                fi
                ;;
            --lfs-scope)
                if [[ "$2" == "user" || "$2" == "system" ]]; then
                    LFS_SCOPE="$2"
                    shift 2
                else
                    echo "Error: Invalid value for --lfs-scope: $2"
                    usage
                fi
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Error: Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Function to install a package using apt-get if not already installed
install_if_needed() {
    local cmd="$1"
    local pkg="$2"
    if ! command -v "$cmd" &> /dev/null; then
        echo "$cmd not found. Installing $pkg..."
        apt-get install -y "$pkg"
    else
        echo "$cmd is already installed."
    fi
}

# Function to determine the user-level binary directory
get_user_bin_dir() {
    python3 -m site --user-base 2>/dev/null || python -m site --user-base 2>/dev/null
}

# Function to add a directory to PATH in shell configuration files
add_to_path() {
    local dir="$1"
    local shell_config_files=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")

    for file in "${shell_config_files[@]}"; do
        if [[ -f "$file" ]]; then
            if ! grep -Fxq "export PATH=\"$dir:\$PATH\"" "$file"; then
                echo "export PATH=\"$dir:\$PATH\"" >> "$file"
                echo "Added '$dir' to PATH in $file."
            else
                echo "'$dir' is already present in $file."
            fi
        fi
    done
}

# Function to install Hugging Face CLI
install_hf() {
    if [[ "$HF_SCOPE" == "system" ]]; then
        echo "Installing/Upgrading Hugging Face CLI system-wide..."
        sudo pip3 install --upgrade huggingface-hub[cli]
    else
        echo "Installing/Upgrading Hugging Face CLI for the user..."
        pip3 install --user --upgrade huggingface-hub[cli]
    fi
}

# Function to install Git LFS system-wide
install_git_lfs_system() {
    echo "Installing Git LFS system-wide..."
    sudo apt-get install -y git-lfs
    echo "Initializing Git LFS system-wide..."
    sudo git lfs install --system
}

# Function to install Git LFS for the user
install_git_lfs_user() {
    echo "Installing Git LFS for the user..."

    # Determine architecture
    ARCH=$(uname -m)
    OS=$(uname -s)

    if [[ "$OS" != "Linux" ]]; then
        echo "Error: User installation of Git LFS is only supported on Linux."
        exit 1
    fi

    # Map architecture to GitHub release asset name
    case "$ARCH" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            echo "Error: Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    # Get the latest release download URL from GitHub API
    echo "Fetching the latest Git LFS release information..."
    RELEASE_INFO=$(curl -s https://api.github.com/repos/git-lfs/git-lfs/releases/latest)
    DOWNLOAD_URL=$(echo "$RELEASE_INFO" | grep "browser_download_url" | grep "linux-$ARCH.tar.gz" | cut -d '"' -f 4)

    if [[ -z "$DOWNLOAD_URL" ]]; then
        echo "Error: Could not find a suitable Git LFS binary for your architecture."
        exit 1
    fi

    # Download and extract the binary
    TEMP_DIR=$(mktemp -d)
    echo "Downloading Git LFS from $DOWNLOAD_URL..."
    curl -L "$DOWNLOAD_URL" -o "$TEMP_DIR/git-lfs.tar.gz"

    echo "Extracting Git LFS..."
    tar -xzf "$TEMP_DIR/git-lfs.tar.gz" -C "$TEMP_DIR"

    # Copy the binary to user's bin directory
    USER_BIN_DIR="$(get_user_bin_dir)/bin"
    mkdir -p "$USER_BIN_DIR"
    echo "Installing git-lfs to $USER_BIN_DIR..."
    cp "$TEMP_DIR/git-lfs" "$USER_BIN_DIR/"
    chmod +x "$USER_BIN_DIR/git-lfs"

    # Clean up
    rm -rf "$TEMP_DIR"

    # Add USER_BIN_DIR to PATH if not already
    if [[ ":$PATH:" != *":$USER_BIN_DIR:"* ]]; then
        echo "Adding '$USER_BIN_DIR' to PATH..."
        add_to_path "$USER_BIN_DIR"
        export PATH="$USER_BIN_DIR:$PATH"
        echo "Updated PATH for the current session."
        echo "To apply the changes permanently, restart your terminal or run 'source' on your shell configuration files."
        echo "For example:"
        echo "  source ~/.bashrc"
        echo "  source ~/.zshrc"
        echo "  source ~/.profile"
    else
        echo "'$USER_BIN_DIR' is already in your PATH."
    fi

    # Initialize Git LFS for the user
    echo "Initializing Git LFS for the user..."
    git lfs install --skip-repo
}

# Function to ensure Python3 and pip3 are installed
ensure_python_pip() {
    echo "Ensuring Python3 and pip3 are installed..."
    install_if_needed "python3" "python3"
    install_if_needed "pip3" "python3-pip"
}

# Function to ensure USER_BIN_DIR is in PATH
ensure_user_bin_in_path() {
    USER_BIN_DIR="$(get_user_bin_dir)/bin"

    if [[ -d "$USER_BIN_DIR" ]]; then
        echo "User-level binary directory detected: $USER_BIN_DIR"
    else
        echo "User-level binary directory does not exist. Creating: $USER_BIN_DIR"
        mkdir -p "$USER_BIN_DIR"
    fi

    if [[ ":$PATH:" != *":$USER_BIN_DIR:"* ]]; then
        echo "'$USER_BIN_DIR' is not in your PATH. Adding it now..."
        add_to_path "$USER_BIN_DIR"

        # Export the new PATH for the current session
        export PATH="$USER_BIN_DIR:$PATH"
        echo "Updated PATH for the current session."

        echo "To apply the changes permanently, restart your terminal or run 'source' on your shell configuration files."
        echo "For example:"
        echo "  source ~/.bashrc"
        echo "  source ~/.zshrc"
        echo "  source ~/.profile"
    else
        echo "'$USER_BIN_DIR' is already in your PATH."
    fi
}

# Main script execution
main() {
    parse_args "$@"

    echo "Starting repos-hf-install..."
    echo "Hugging Face CLI will be installed: $HF_SCOPE."
    echo "Git LFS will be installed: $LFS_SCOPE."
    echo ""

    # Update package list once
    echo "Updating package list..."
    apt-get update -y

    # Ensure Python3 and pip3 are installed
    ensure_python_pip
    echo ""

    # Install Hugging Face CLI
    install_hf
    echo ""

    # Install Git LFS based on scope
    if [[ "$LFS_SCOPE" == "system" ]]; then
        install_git_lfs_system
    else
        install_git_lfs_user
    fi
    echo ""

    echo "Installation completed successfully!"
}

# Execute the main function with all script arguments
main "$@"

EOF

# Make the installation script executable
chmod +x /usr/local/bin/repos-hf-install

echo "Script /usr/local/bin/repos-hf-install has been created and made executable."
