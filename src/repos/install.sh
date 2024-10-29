#!/usr/bin/env bash

set -e

## Config shellrc
config_shellrc_d() {
  # Determine which shell configuration file to use
  # Override for specifying the shell to configure (either "bash" or "zsh")
  local shell_override="${1:-}"

  # Determine the configuration file and directory based on override or existing files
  if [ "$shell_override" = "bash" ]; then
    shell_rc="$HOME/.bashrc"
    shell_rc_d_name=".bashrc.d"
  elif [ "$shell_override" = "zsh" ]; then
    shell_rc="$HOME/.zshrc"
    shell_rc_d_name=".zshrc.d"
  else
    if [ -e "$HOME/.bashrc" ]; then
      shell_rc="$HOME/.bashrc"
      shell_rc_d_name=".bashrc.d"
    elif [ -e "$HOME/.zshrc" ]; then
      shell_rc="$HOME/.zshrc"
      shell_rc_d_name=".zshrc.d"
    else
      # Default to .bashrc if neither exists
      shell_rc="$HOME/.bashrc"
      shell_rc_d_name=".bashrc.d"
      touch "$shell_rc"
    fi
  fi

  # Ensure that the corresponding .rc.d directory is sourced in the shell configuration file
  if ! grep -qF "$shell_rc_d_name" "$shell_rc"; then
    echo "for i in \$(ls -A \$HOME/$shell_rc_d_name/); do source \$HOME/$shell_rc_d_name/\$i; done" >> "$shell_rc"
  fi

  # Create the directory for shell configuration scripts
  mkdir -p "$HOME/$shell_rc_d_name"
}

config_shellrc_d

# ======================
## HuggingFace CLI
# ======================

# Create the installation script
cat > /usr/local/bin/repos-hf-install << 'EOF'
#!/usr/bin/env bash
set -e

# ==============================================================================
# repos-hf-install
# A script to install Hugging Face CLI and Git LFS either system-wide or for
# the current user, based on provided parameters.
# ==============================================================================

# Default installation scopes
HF_SCOPE="user"
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
        sudo apt-get install -y "$pkg"
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
    sudo apt-get update -y

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

echo "Installation script /usr/local/bin/repos-hf-install has been created and made executable."

if [ "$INSTALL_HUGGINGFACE" = "true" ]; then
    echo "Installing Hugging Face CLI and Git LFS..."
    /usr/local/bin/repos-hf-install --hf-scope system --lfs-scope system || {
        echo "Failed to install Hugging Face CLI and Git LFS."
        exit 1
    }
    echo "Hugging Face CLI and Git LFS have been installed successfully."
fi



## HuggingFace CLI
# ======================

# Create the installation script
cat > /usr/local/bin/repos-hf-clone-ind << 'EOF'
#!/usr/bin/env bash

# Script to clone a Hugging Face dataset repository using either Hugging Face CLI or Git with .netrc authentication.

# Exit immediately if a command exits with a non-zero status
set -e

# Trap to handle errors
trap 'echo "An error occurred. Exiting..."; exit 1;' ERR

# Usage function
usage() {
    echo "Usage: $0 -r <owner>/<repo_name> [OPTIONS]"
    echo
    echo "Options:"
    echo "  -r, --repo          The full name of the Hugging Face dataset repository to clone (owner/repo_name) [Required]"
    echo "  -m, --method        Cloning method: 'git' (Git) or 'hf' (Hugging Face CLI). Default is 'git'. (Optional)"
    echo "  -t, --token         The token for authenticated cloning. If not provided,"
    echo "                      then defaults to '\$GH_TOKEN' if using 'git' and '\$HF_TOKEN' if using 'hf'. (Optional)"
    echo "  -s, --netrc-suffix  Custom suffix for the .netrc file (e.g., '.custom')."
    echo "                      If provided, then the .netrc file '\$HOME/.netrc-\$NETRC_SUFFIX' will be used. (Optional)"
    echo "  -p, --path          The directory path to clone the repository into. Defaults to the current directory. (Optional)"
    echo "  -h, --help          Display this help message."
    echo
    echo "Authentication Methods:"
    echo "  git - Uses Git with .netrc for authentication and cloning."
    echo "  hf  - Uses the Hugging Face CLI for authentication and cloning."
    echo
    echo "Examples:"
    echo "  # Clone using Hugging Face CLI with token"
    echo "  \$0 -r owner/repo_name -m hf --token your_token_here"
    echo
    echo "  # Clone using Git with a custom .netrc suffix"
    echo "  \$0 -r owner/repo_name -m git --netrc-suffix custom_suffix"
    echo
    echo "  # Clone specifying a destination path"
    echo "  \$0 -r owner/repo_name -m hf -p /desired/path"
    exit 1
}

# Initialize variables with defaults
REPO_FULL_NAME=""
CLONE_METHOD="git"      # Default method is 'git'
ARG_PAT=""
HF_PAT="${HF_TOKEN:-}"
GH_PAT="${GH_TOKEN:-}"
NETRC_SUFFIX=""
PATH_DIR="."

# Parse options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r|--repo)
            REPO_FULL_NAME="$2"
            shift 2
            ;;
        -m|--method)
            CLONE_METHOD="$2"
            shift 2
            ;;
        -t|--token)
            ARG_PAT="$2"
            shift 2
            ;;
        -s|--netrc-suffix)
            NETRC_SUFFIX="$2"
            shift 2
            ;;
        -p|--path)
            PATH_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option '$1'"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$REPO_FULL_NAME" ]; then
    echo "Error: --repo is required."
    usage
fi

# Validate cloning method
if [[ "$CLONE_METHOD" != "hf" && "$CLONE_METHOD" != "git" ]]; then
    echo "Error: Invalid cloning method '$CLONE_METHOD'. Choose 'hf' or 'git'."
    usage
fi

# Determine the final token to use
if [ "$CLONE_METHOD" == "hf" ]; then
    FINAL_PAT="${ARG_PAT:-$HF_PAT}"
else
    FINAL_PAT="${ARG_PAT:-$GH_PAT}"
fi

# Validate that --netrc-suffix is used only with 'git' method
if [ -n "$NETRC_SUFFIX" ] && [[ "$CLONE_METHOD" != "git" ]]; then
    echo "Error: --netrc-suffix can only be used with '--method git'."
    exit 1
fi

# Function to clone using Hugging Face CLI
clone_with_hf_cli() {
    # Check if huggingface-cli is installed
    if ! command -v huggingface-cli &> /dev/null; then
        echo "huggingface-cli not found. Installing it using repos-hf-install..."
        repos-hf-install
    else
        echo "huggingface-cli is already installed."
    fi

    # Authenticate using Hugging Face CLI
    if [ -n "$FINAL_PAT" ]; then
        echo "Logging in to Hugging Face CLI with provided token..."
        huggingface-cli login --token "$FINAL_PAT"
    else
        # Check if user is already authenticated
        if ! huggingface-cli whoami &> /dev/null; then
            echo "You are not authenticated with Hugging Face CLI."
            echo "Please log in by running 'huggingface-cli login'."
            exit 1
        else
            echo "Authenticated as $(huggingface-cli whoami)."
        fi
    fi

    # Determine the destination directory name
    DEST_DIR_NAME="$(basename "$REPO_FULL_NAME")"

    # Full destination path
    FULL_DEST_PATH="$PATH_DIR/$DEST_DIR_NAME"

    # Check if the destination directory already exists
    if [ -d "$FULL_DEST_PATH" ]; then
        echo "Error: Destination directory '$FULL_DEST_PATH' already exists."
        exit 1
    fi

    # Clone the repository using Hugging Face CLI
    echo "Cloning repository '$REPO_FULL_NAME' into '$FULL_DEST_PATH' using Hugging Face CLI..."
    huggingface-cli repo clone datasets/"$REPO_FULL_NAME" "$FULL_DEST_PATH"

    echo "Repository cloned successfully to '$FULL_DEST_PATH'."
}

# Function to clone using Git with .netrc or token
clone_with_git() {
    local clone_url=""
    local ORIGINAL_NETRC="$HOME/.netrc"
    local TEMP_DIR_BACKUP
    TEMP_DIR_BACKUP=$(mktemp -d)
    local BACKUP_NETRC="$TEMP_DIR_BACKUP/.netrc.bak"
    
    # Determine the .netrc file to use if --netrc-suffix is specified
    if [ -n "$NETRC_SUFFIX" ]; then
        NETRC_FILE="$HOME/.netrc-$NETRC_SUFFIX"

        # Check if the .netrc file exists
        if [ ! -f "$NETRC_FILE" ]; then
            echo "Error: .netrc file '$NETRC_FILE' does not exist."
            rm -rf "$TEMP_DIR_BACKUP"
            exit 1
        fi

        # Ensure the .netrc file has correct permissions
        chmod 600 "$NETRC_FILE"

        # Backup the original .netrc
        if [ -f "$ORIGINAL_NETRC" ]; then
            cp "$ORIGINAL_NETRC" "$BACKUP_NETRC" || {
                echo "Error: Failed to backup original .netrc to '$BACKUP_NETRC'. Aborting."
                rm -rf "$TEMP_DIR_BACKUP"
                exit 1
            }
            echo "Original .netrc backed up to '$BACKUP_NETRC'."
        fi

        # Overwrite the original .netrc with the custom one
        cp "$NETRC_FILE" "$ORIGINAL_NETRC" || {
            echo "Error: Failed to overwrite original .netrc with '$NETRC_FILE'. Aborting."
            # Restore the original .netrc if backup exists
            if [ -f "$BACKUP_NETRC" ]; then
                mv "$BACKUP_NETRC" "$ORIGINAL_NETRC" || {
                    echo "Error: Failed to restore original .netrc from '$BACKUP_NETRC'."
                    rm -rf "$TEMP_DIR_BACKUP"
                    exit 1
                }
                echo "Original .netrc restored from '$BACKUP_NETRC'."
            fi
            rm -rf "$TEMP_DIR_BACKUP"
            exit 1
        }
    fi

    # Construct the clone URL
    if [ -n "$FINAL_PAT" ]; then
        clone_url="https://$FINAL_PAT@huggingface.co/datasets/$REPO_FULL_NAME"
    else
        clone_url="https://huggingface.co/datasets/$REPO_FULL_NAME"
    fi

    # Determine the destination directory name
    DEST_DIR_NAME="$(basename "$REPO_FULL_NAME")"

    # Full destination path
    FULL_DEST_PATH="$PATH_DIR/$DEST_DIR_NAME"

    # Check if the destination directory already exists
    if [ -d "$FULL_DEST_PATH" ]; then
        echo "Error: Destination directory '$FULL_DEST_PATH' already exists."
        # Restore the original .netrc if it was overwritten
        if [ -n "$NETRC_SUFFIX" ]; then
            if [ -f "$BACKUP_NETRC" ]; then
                mv "$BACKUP_NETRC" "$ORIGINAL_NETRC" || {
                    echo "Error: Failed to restore original .netrc from '$BACKUP_NETRC'."
                    rm -rf "$TEMP_DIR_BACKUP"
                    exit 1
                }
                echo "Original .netrc restored from '$BACKUP_NETRC'."
            else
                rm -f "$ORIGINAL_NETRC" || {
                    echo "Error: Failed to remove the custom .netrc file '$ORIGINAL_NETRC'."
                    rm -rf "$TEMP_DIR_BACKUP"
                    exit 1
                }
                echo "Custom .netrc file removed."
            fi
        fi
        rm -rf "$TEMP_DIR_BACKUP"
        exit 1
    fi

    # Clone the repository using Git
    echo "Cloning repository '$REPO_FULL_NAME' into '$FULL_DEST_PATH' using Git..."

    git clone "$clone_url" "$FULL_DEST_PATH" || {
        echo "Failed to clone the repository '$REPO_FULL_NAME'."
        # Restore the original .netrc if it was overwritten
        if [ -n "$NETRC_SUFFIX" ]; then
            if [ -f "$BACKUP_NETRC" ]; then
                mv "$BACKUP_NETRC" "$ORIGINAL_NETRC" || {
                    echo "Error: Failed to restore original .netrc from '$BACKUP_NETRC'."
                    rm -rf "$TEMP_DIR_BACKUP"
                    exit 1
                }
                echo "Original .netrc restored from '$BACKUP_NETNC'."
            else
                rm -f "$ORIGINAL_NETRC" || {
                    echo "Error: Failed to remove the custom .netrc file '$ORIGINAL_NETRC'."
                    rm -rf "$TEMP_DIR_BACKUP"
                    exit 1
                }
                echo "Custom .netrc file removed."
            fi
        fi
        rm -rf "$TEMP_DIR_BACKUP"
        exit 1
    }

    # Restore the original .netrc after successful clone
    if [ -n "$NETRC_SUFFIX" ]; then
        if [ -f "$BACKUP_NETRC" ]; then
            mv "$BACKUP_NETRC" "$ORIGINAL_NETRC" || {
                echo "Error: Failed to restore original .netrc from '$BACKUP_NETRC'."
                rm -rf "$TEMP_DIR_BACKUP"
                exit 1
            }
            echo "Original .netrc restored from '$BACKUP_NETNC'."
        else
            rm -f "$ORIGINAL_NETRC" || {
                echo "Error: Failed to remove the custom .netrc file '$ORIGINAL_NETNC'."
                rm -rf "$TEMP_DIR_BACKUP"
                exit 1
            }
            echo "Custom .netrc file removed."
        fi
    fi

    echo "Repository cloned successfully to '$FULL_DEST_PATH'."

    # Clean up the temporary backup directory
    rm -rf "$TEMP_DIR_BACKUP"
}

EOF

# Make the installation script executable
chmod +x /usr/local/bin/repos-hf-clone-ind

# Clone multiple Hugging Face dataset repositories
cat > /usr/local/bin/repos-hf-clone << 'EOF'
#!/usr/bin/env bash

# Script to clone multiple Hugging Face dataset repositories using repos-hf-clone-ind.

# Exit immediately if a command exits with a non-zero status
set -e

# Trap to handle errors
trap 'echo "An error occurred. Exiting..."; exit 1;' ERR

# Usage function
usage() {
    echo "Usage: \$0 [OPTIONS] [-- repos-hf-clone-ind OPTIONS]"
    echo
    echo "Options:"
    echo "  -f, --file <file>    Path to the repositories list file. Defaults to './repos-to-clone-hf.list'. (Optional)"
    echo "  -h, --help           Display this help message."
    echo
    echo "Any additional OPTIONS after '--' will be passed to the 'repos-hf-clone-ind' command."
    echo
    echo "Authentication Methods:"
    echo "  git - Uses Git with .netrc for authentication and cloning."
    echo "  hf  - Uses the Hugging Face CLI for authentication and cloning."
    echo
    echo "Examples:"
    echo "  # Clone all repositories listed in repos-to-clone.list with default settings"
    echo "  \$0"
    echo
    echo "  # Clone using Hugging Face CLI method"
    echo "  \$0 --method hf -- repos-hf-clone-ind-specific-options"
    echo
    echo "  # Clone using a custom repos list file"
    echo "  \$0 --file /path/to/custom-repos.list -- repos-hf-clone-ind-specific-options"
    echo
    exit 1
}

# Default repositories list file
REPOS_LIST="./repos-to-clone-hf.list"

# Parse options using getopt
PARSED_OPTIONS=$(getopt -n "$0" -o f:h --long file:,help -- "$@")
if [ $? -ne 0 ]; then
    usage
fi

eval set -- "$PARSED_OPTIONS"

# Initialize an array to hold repos-hf-clone-ind options
CLONE_OPTIONS=()

# Extract options
while true; do
    case "$1" in
        -f|--file)
            REPOS_LIST="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        --)
            shift
            # All remaining arguments are for repos-hf-clone-ind
            CLONE_OPTIONS=("$@")
            break
            ;;
        *)
            echo "Internal error!"
            exit 1
            ;;
    esac
done

# Check if the repositories list file exists
if [ ! -f "$REPOS_LIST" ]; then
    echo "Error: Repositories list file '$REPOS_LIST' does not exist."
    exit 1
fi

# Function to clone a single repository using repos-hf-clone-ind
clone_repo() {
    local repository="$1"
    # Call repos-hf-clone-ind with the repository and additional options
    repos-hf-clone-ind "$repository" "${CLONE_OPTIONS[@]}"
}

# Loop over each line in the repositories list file
while IFS= read -r repository || [ -n "$repository" ]; do
    # Skip empty lines and lines starting with '#'
    if [[ -z "$repository" || "$repository" =~ ^[[:space:]]*$ || "$repository" =~ ^[[:space:]]*# ]]; then
        continue
    fi

    echo "Cloning repository: $repository"

    # Invoke the clone_repo function with the repository
    clone_repo "$repository"
done < "$REPOS_LIST"

echo "All repositories have been cloned successfully."
EOF
chmod +x /usr/local/bin/repos-hf-clone

# ======================
# GitHub
# ======================

# set up environment variables
# -------------------
mkdir -p "/var/tmp/repos"

cat > "/var/tmp/repos/repos-gh-login-env" << 'EOF'
FORCE_GH_TOKEN="${FORCE_GH_TOKEN:-true}"

# github token
if [ -n "$GH_TOKEN" ]; then
  # necessarily override GITHUB_TOKEN with GH_TOKEN if set and if in a codespace
  # as that token is scoped to only the creating repo, which is not great.
  if [ "$FORCE_GH_TOKEN" = "true" ]; then
    export GITHUB_TOKEN="$GH_TOKEN"
    export GITHUB_PAT="$GH_TOKEN"
  else
    export GITHUB_TOKEN="${GITHUB_TOKEN:-"$GH_TOKEN"}"
    export GITHUB_PAT="${GITHUB_PAT:-"$GH_TOKEN"}"
  fi
elif [ -n "$GITHUB_PAT" ]; then
  export GH_TOKEN="${GH_TOKEN:-"$GITHUB_PAT"}"
  export GITHUB_TOKEN="${GITHUB_TOKEN:-"$GITHUB_PAT"}"
elif [ -n "$GITHUB_TOKEN" ]; then
  export GH_TOKEN="${GH_TOKEN:-"$GITHUB_TOKEN"}"
  export GITHUB_PAT="${GITHUB_PAT:-"$GITHUB_TOKEN"}"
else
  echo "No GitHub token found (none of GH_TOKEN, GITHUB_PAT, GITHUB_TOKEN)"
fi
EOF

# clone
# -------------------
cat > /usr/local/bin/repos-gh-clone << 'EOF'
#!/usr/bin/env bash

set -e

config_shellrc_d() {
  # Check if ~/.bashrc or ~/.zshrc exists, preferring ~/.bashrc if both exist
  if [ -e "$HOME/.bashrc" ]; then
    shell_rc="$HOME/.bashrc"
  else
    shell_rc="$HOME/.zshrc"
  fi

  # Ensure that `.shellrc.d` files are sourced in
  if [ -e "$shell_rc" ]; then
    # Add `.shellrc.d` sourcing if not already present
    if ! grep -qF ".shellrc.d" "$shell_rc"; then
      echo 'for i in $(ls -A $HOME/.shellrc.d/); do source $HOME/.shellrc.d/$i; done' >> "$shell_rc"
    fi
  else
    # Create the shell configuration file if it doesn’t exist
    touch "$shell_rc"
    echo 'for i in $(ls -A $HOME/.shellrc.d/); do source $HOME/.shellrc.d/$i; done' > "$shell_rc"
  fi

  # Create the directory for shell configuration scripts
  mkdir -p "$HOME/.shellrc.d"
}

add_to_shellrc_d() {
  if [ -d "/var/tmp/$1" ]; then
    for file in $(ls "/var/tmp/$1"); do
      cp "/var/tmp/$1/$file" "$HOME/.shellrc.d/$file"
    done
    sudo rm -rf "/var/tmp/$1"
  fi
}

clone_repos() {
  # Clones all repos in repos-to-clone.list into the parent directory of the current working directory.

  echo "The initial value of OVERRIDE_CREDENTIAL_HELPER is $OVERRIDE_CREDENTIAL_HELPER"
  OVERRIDE_CREDENTIAL_HELPER="${OVERRIDE_CREDENTIAL_HELPER:-auto}"
  echo "The final value of OVERRIDE_CREDENTIAL_HELPER is $OVERRIDE_CREDENTIAL_HELPER"

  # Get the absolute path of the current working directory
  current_dir="$(pwd)"

  # Determine the parent directory of the current directory
  parent_dir="$(cd "${current_dir}/.." && pwd)"

  # Function to clone a repository
  clone_repo() {
    cd "${parent_dir}"
    repo_and_branch=(${1//@/ }) # split input into array using @ as delimiter
    repo=${repo_and_branch[0]}
    branch=${repo_and_branch[1]}
    dir="${repo#*/}"

    if [ ! -d "$dir" ]; then
      if [ -z "$branch" ]; then
        git clone "https://github.com/$repo"
      else
        git clone -b "$branch" "https://github.com/$repo"
      fi
    else
      cd "$dir"
      if [ ! -d ".git" ]; then
        echo "Warning: $dir is not a Git repository but exists already"
      else
        if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
          if [ -z "$branch" ]; then
            # If no branch is specified, checkout to the default branch
            if git remote show origin > /dev/null 2>&1; then
              git checkout $(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)
            fi
          else
            current_branch=$(git rev-parse --abbrev-ref HEAD)
            if [ "$current_branch" != "$branch" ]; then
              git checkout "$branch"
            fi
          fi
        fi
      fi
      cd ..
      echo "Already cloned $repo"
    fi
  }

  # If running in a Codespace, set up Git credentials
  if [ ! "${OVERRIDE_CREDENTIAL_HELPER}" == "never" ]; then
    # Check if there are repos specified in repos-to-clone.list
    # If there are none, then do not do this:
    if [ ! "${OVERRIDE_CREDENTIAL_HELPER}" == "always" ]; then
      k=0
      if [ -f "./repos-to-clone.list" ]; then
        while IFS= read -r repository || [ -n "$repository" ]; do
          # Skip lines that are empty or contain only whitespace
          if [[ -z "$repository" || "$repository" =~ ^[[:space:]]*$ || "$repository" =~ ^[[:space:]]*# ]]; then
            continue
          fi
          k=1
          break
        done < "./repos-to-clone.list"
      fi
    else
      k=1
    fi
    if [ "$k" -eq 1 ]; then
      # Remove the default credential helper
      sudo sed -i -E 's/helper =.*//' /etc/gitconfig

      # Add one that just uses secrets available in the Codespace
      sudo git config --system credential.helper '!f() { sleep 1; echo "username=${GITHUB_USER}"; echo "password=${GH_TOKEN}"; }; f'
    fi
  else
    echo "Retaining initial Git credential helper"
    echo "The value of OVERRIDE_CREDENTIAL_HELPER is: ${OVERRIDE_CREDENTIAL_HELPER}"
  fi

  # If there is a list of repositories to clone, clone them
  if [ -f "./repos-to-clone.list" ]; then
    while IFS= read -r repository || [ -n "$repository" ]; do
      # Skip lines that are empty or contain only whitespace
      if [[ -z "$repository" || "$repository" =~ ^[[:space:]]*$ || "$repository" =~ ^[[:space:]]*# ]]; then
        continue
      fi
      clone_repo "$repository"
    done < "./repos-to-clone.list"
  fi
}

# Source if not already in ~/.shellrc.d, and so it will presumably have been sourced otherwise already
if [ -f /var/tmp/repos/repos-gh-login-env ]; then
  source /var/tmp/repos/repos-gh-login-env
fi

config_shellrc_d
add_to_shellrc_d repos
clone_repos
EOF

chmod +x /usr/local/bin/repos-gh-clone

# log in using the store to GitHub
# -------------------
cat > /usr/local/bin/repos-gh-login-store << 'EOF'
#!/usr/bin/env bash

set -e

sudo apt update -y
sudo apt install -y jq gh

# Use plain-text credential store
git config --global credential.helper 'store'

# Get GitHub username
# username=$(gh api user | jq -r '.login')
username=$GITHUB_USER

# Get GitHub PAT from environment variable
PAT=$GITHUB_PAT

if [ -z "$PAT" ]; then
  PAT=$GH_TOKEN
fi

if [ -z "$PAT" ]; then
  PAT=$GITHUB_TOKEN
fi

if [ -z "$PAT" ] || [ -z "$username" ]; then
  echo "Error: One or more environment variables are not set. Please set GITHUB_USER and GITHUB_PAT."
  exit 1
fi

# Create a credential string
credential_string="protocol=https
host=github.com
username=$username
password=$PAT"

# Write the credential string to a temporary file
temp_file=$(mktemp)
echo "$credential_string" > $temp_file

# Use the temporary file as the input for 'git credential approve'
git credential approve < $temp_file

# Delete the temporary file
rm $temp_file
EOF

chmod +x /usr/local/bin/repos-gh-login-store

## Push, pull, fetch

### log in using the store to GitHub
cat > /usr/local/bin/repos-gh-push << 'EOF'
#!/usr/bin/env bash

IFS=""
all_args="$*"
git
IFS=" "
EOF

# Add to VS Code workspace
# -------------------
cat > /usr/local/bin/repos-workspace-add << 'EOF'
#!/usr/bin/env bash

set -e

# Get the absolute path of the current working directory
current_dir="$(pwd)"
echo "current_dir:"
echo "$current_dir"

# Define the path to the workspace JSON file
workspace_file="${current_dir}/EntireProject.code-workspace"

# Create the workspace file if it does not exist, and is needed (i.e. if it is a multi-root workspace, as indicated by the repos-to-clone*.list files)
if [ ! -f "$workspace_file" ]; then
  k=0
  if [ -f "./repos-to-clone.list" ]; then
    while IFS= read -r repository || [ -n "$repository" ]; do
      # Skip lines that are empty or contain only whitespace
      if [[ -z "$repository" || "$repository" =~ ^[[:space:]]*$ || "$repository" =~ ^[[:space:]]*# ]]; then
        continue
      fi
      k=1
      break
    done < "./repos-to-clone.list"
  fi
  if [ -f "./repos-to-clone-xethub.list" ]; then
    while IFS= read -r repository || [ -n "$repository" ]; do
      # Skip lines that are empty or contain only whitespace
      if [[ -z "$repository" || "$repository" =~ ^[[:space:]]*$ || "$repository" =~ ^[[:space:]]*# ]]; then
        continue
      fi
      k=1
      break
    done < "./repos-to-clone-xethub.list"
  fi
  if [ "$k" -eq 1 ]; then
    echo "Workspace file does not exist. Creating it now..."
    echo '{"folders": [{"path": "."}]}' > "$workspace_file"
  fi
fi

add_to_workspace() {
  sudo apt update -y
  sudo apt install -y jq

  # Read and process each line from the input file
  while IFS= read -r repo || [ -n "$repo" ]; do
    # Skip lines that are empty, contain only whitespace, or start with a hash
    if [[ -z "$repo" || "$repo" =~ ^[[:space:]]*# || "$repo" =~ ^[[:space:]]+$ ]]; then
      continue
    fi

    # Extract the repository name and create the path
    repo_name="${repo%%@*}" # Remove everything after @
    repo_name="${repo_name##*/}" # Remove everything before the last /
    repo_path="../$repo_name"

    # Check if the path is already in the workspace file
    if jq -e --arg path "$repo_path" '.folders[] | select(.path == $path) | length > 0' "$workspace_file" > /dev/null; then
      continue
    fi

    # Add the path to the workspace JSON file
    jq --arg path "$repo_path" '.folders += [{"path": $path}]' "$workspace_file" > temp.json && mv temp.json "$workspace_file"
  done < "$1"
}

# Attempt to add from these files if they exist
if [ -f "./repos-to-clone.list" ]; then
  add_to_workspace "./repos-to-clone.list"
fi

if [ -f "./repos-to-clone-xethub.list" ]; then
  add_to_workspace "./repos-to-clone-xethub.list"
fi
EOF

chmod +x /usr/local/bin/repos-workspace-add
