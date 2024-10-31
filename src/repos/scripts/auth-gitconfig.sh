cat > /usr/local/bin/repos-git-auth-gitconfig << 'EOF'
#!/usr/bin/env bash

set -e

setup_gitconfig() {
  # Remove the default credential helper
  sudo sed -i -E 's/helper =.*//' /etc/gitconfig

  sudo git config --system credential."https://github.com".helper '!f() {
    sleep 1; 
    echo username=${GITHUB_USER:-TOKEN}; 
    echo password=${GH_TOKEN:-$GITHUB_TOKEN}; 
  }; f'

  sudo git config --system credential."https://huggingface.co".helper '!f() { 
    sleep 1; 
    echo username=${HF_USER:-${HUGGINGFACE_USER:-TOKEN}}; 
    echo password=${HF_TOKEN:-$HUGGINGFACE_TOKEN}; 
  }; f'
}

setup_gitconfig

EOF

# Make the script executable
chmod +x /usr/local/bin/repos-git-auth-gitconfig

echo "Script /usr/local/bin/repos-git-auth-gitconfig has been created and made executable."
