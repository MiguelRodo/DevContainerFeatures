cat > /usr/local/bin/repos-git-auth << 'EOF'
#!/usr/bin/env bash

set -e

# Function to display usage information
usage() {
    echo "Usage:"
    echo "  $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --use-gitconfig [auto|true|false]          Configure Git authentication (default: auto)."
    echo "  -s, --scope [system|global|local]              Set Git config scope (default: global)."
    echo "  -h, --help                                 Display this help message."
    exit 1
}

# Default values
AUTH_GITCONFIG="auto"
AUTH_GITCONFIG_SCOPE="global"

# Parse named parameters
while [[ $# -gt 0 ]]; do
    case "$1" in
        --use-gitconfig|-u)
            AUTH_GITCONFIG="$2"
            if [ ! "$AUTH_GITCONFIG" = "auto" ] && \
               [ ! "$AUTH_GITCONFIG" = "true" ] && \
               [ ! "$AUTH_GITCONFIG" = "false" ]; then
                echo "Invalid value for --use-gitconfig: $AUTH_GITCONFIG"
                usage
            fi
            shift 2
            ;;
        -s|--scope)
            AUTH_GITCONFIG_SCOPE="$2"
            if [ ! "$AUTH_GITCONFIG_SCOPE" = "system" ] && \
               [ ! "$AUTH_GITCONFIG_SCOPE" = "global" ] && \
               [ ! "$AUTH_GITCONFIG_SCOPE" = "local" ]; then
                echo "Invalid value for --scope: $AUTH_GITCONFIG_SCOPE"
                usage
            fi
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Invalid option: $1"
            usage
            ;;
    esac
done

if [ "$AUTH_GITCONFIG" = "auto" ]; then
    if [ "$CODESPACES" = "true" ]; then
        AUTH_GITCONFIG="true"
    else
        AUTH_GITCONFIG="false"
    fi
fi

# Rest of the script logic
echo "AUTH_GITCONFIG=${AUTH_GITCONFIG}"
echo "AUTH_GITCONFIG_SCOPE=${AUTH_GITCONFIG_SCOPE}"

if [ "$AUTH_GITCONFIG" = "false" ]; then
    echo "Git authentication setup is disabled."
    exit 0
fi

setup_gitconfig() {
  local auth_gitconfig_scope="$1"
  # Remove the default credential helper
  if ("$auth_gitconfig_scope" == "system") {
    sudo sed -i -E 's/helper =.*//' /etc/gitconfig
  }

  if [ "$auth_gitconfig_scope" = "global" ]; then
    git config --global --unset credential.helper
  elif [ "$auth_gitconfig_scope" = "local" ]; then
    git config --unset credential.helper
  fi

  if [ "$auth_git_config_scope" = "system" ]; then
    SUDO="sudo"
  else
    SUDO=""
  fi

  "$SUDO" git config --${auth_gitconfig_scope} credential."https://github.com".helper '!f() {
    sleep 1; 
    echo username=${GITHUB_USER:-TOKEN}; 
    echo password=${GH_TOKEN:-$GITHUB_TOKEN}; 
  }; f'

  "$SUDO" git config --${auth_gitconfig_scope} credential."https://huggingface.co".helper '!f() { 
    sleep 1; 
    echo username=${HF_USER:-${HUGGINGFACE_USER:-TOKEN}}; 
    echo password=${HF_TOKEN:-$HUGGINGFACE_TOKEN}; 
  }; f'
}

# authenticate using gitconfig
setup_gitconfig "$AUTH_GITCONFIG_SCOPE"

EOF

# Make the script executable
chmod +x /usr/local/bin/repos-git-auth

echo "Script /usr/local/bin/repos-git-auth has been created and made executable."
