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
    exit "${1:-1}"
}

# Default values
AUTH_GITCONFIG="auto"
AUTH_GITCONFIG_SCOPE="global"

# Parse named parameters
while [[ $# -gt 0 ]]; do
    case "$1" in
        --use-gitconfig|-u)
            if [[ -z "$2" ]]; then
                echo "Error: --use-gitconfig requires a value."
                usage
            fi
            AUTH_GITCONFIG="$2"
            if [[ "$AUTH_GITCONFIG" != "auto" && "$AUTH_GITCONFIG" != "true" && "$AUTH_GITCONFIG" != "false" ]]; then
                echo "Invalid value for --use-gitconfig: $AUTH_GITCONFIG"
                usage
            fi
            shift 2
            ;;
        -s|--scope)
            if [[ -z "$2" ]]; then
                echo "Error: --scope requires a value."
                usage
            fi
            AUTH_GITCONFIG_SCOPE="$2"
            if [[ "$AUTH_GITCONFIG_SCOPE" != "system" && "$AUTH_GITCONFIG_SCOPE" != "global" && "$AUTH_GITCONFIG_SCOPE" != "local" ]]; then
                echo "Invalid value for --scope: $AUTH_GITCONFIG_SCOPE"
                usage
            fi
            shift 2
            ;;
        -h|--help)
            usage 0
            ;;
        *)
            echo "Invalid option: $1"
            usage
            ;;
    esac
done

if [[ "$AUTH_GITCONFIG" == "auto" ]]; then
    if [[ "$CODESPACES" == "true" ]]; then
        AUTH_GITCONFIG="true"
    else
        AUTH_GITCONFIG="false"
    fi
fi

# Rest of the script logic
echo "AUTH_GITCONFIG=${AUTH_GITCONFIG}"
echo "AUTH_GITCONFIG_SCOPE=${AUTH_GITCONFIG_SCOPE}"

if [[ "$AUTH_GITCONFIG" == "false" ]]; then
    echo "Git authentication setup is disabled."
    exit 0
fi

setup_gitconfig() {
    local auth_gitconfig_scope="$1"

    # Remove the default credential helper
    if [[ "$auth_gitconfig_scope" == "system" ]]; then
        if ! command -v sudo >/dev/null 2>&1; then
            echo "Error: sudo is required for system scope but is not installed."
            exit 1
        fi
        sudo sed -i -E '/credential\.helper\s*=/d' /etc/gitconfig
    elif [[ "$auth_gitconfig_scope" == "global" ]]; then
        git config --global --unset credential.helper
    elif [[ "$auth_gitconfig_scope" == "local" ]]; then
        git config --unset credential.helper
    fi

    if [[ "$auth_gitconfig_scope" == "system" ]]; then
        sudo git config --${auth_gitconfig_scope} credential."https://github.com".helper "!f() {
            sleep 1
            echo username=\${GITHUB_USER:-TOKEN}
            echo password=\${GH_TOKEN:-\$GITHUB_TOKEN}
        }; f"
        sudo git config --${auth_gitconfig_scope} credential."https://huggingface.co".helper "!f() {
            sleep 1
            echo username=\${HF_USER:-\${HUGGINGFACE_USER:-TOKEN}}
            echo password=\${HF_TOKEN:-\$HUGGINGFACE_TOKEN}
        }; f"
    else
        git config --${auth_gitconfig_scope} credential."https://github.com".helper "!f() {
            sleep 1
            echo username=\${GITHUB_USER:-TOKEN}
            echo password=\${GH_TOKEN:-\$GITHUB_TOKEN}
        }; f"
        git config --${auth_gitconfig_scope} credential."https://huggingface.co".helper "!f() {
            sleep 1
            echo username=\${HF_USER:-\${HUGGINGFACE_USER:-TOKEN}}
            echo password=\${HF_TOKEN:-\$HUGGINGFACE_TOKEN}
        }; f"
    fi

    echo "Git authentication with gitconfig has been configured."
}

# Authenticate using gitconfig
setup_gitconfig "$AUTH_GITCONFIG_SCOPE"

EOF

# Make the script executable
chmod +x /usr/local/bin/repos-git-auth

echo "Script /usr/local/bin/repos-git-auth has been created and made executable."
