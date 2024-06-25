#!/usr/bin/env bash
# Source: https://xethub.com/assets/docs/getting-started/install

# 1. Installs `git-xet` cli

ensure_git_up_to_date() {
  # Get Git version information
  git_version_string=$(git --version)
  git_version=$(echo "$git_version_string" | cut -d' ' -f3)

  # Compare with target version (2.30)
  required_version="2.30"

  # String comparison (works well for simple version formats)
  if [[ "$git_version" < "$required_version" ]]; then
      echo "Your Git version ($git_version) is outdated. Updating..."

      # Update Git (using apt)
      sudo apt-get update  # Refresh package lists
      sudo apt-get install -y git 

      # Verify update
      new_git_version=$(git --version | cut -d' ' -f3)
      echo "Git has been updated to version $new_git_version"
  else
      echo "Your Git version ($git_version) is up-to-date."
  fi
}

set -e

ensure_git_up_to_date

pushd /tmp

# Download with error checking
if ! wget -q https://github.com/xetdata/xet-tools/releases/latest/download/xet-linux-x86_64.deb; then
    echo "Error: Failed to download xet-linux-x86_64.deb package."
    exit 1
fi

# Install with error checking
if ! sudo apt-get install -y ./xet-linux-x86_64.deb; then
    echo "Error: Failed to install xet-linux-x86_64.deb package."
    exit 1
fi

git xet install

rm -rf ./xet-linux-x86_64.deb
popd
