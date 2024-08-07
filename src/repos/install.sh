#!/usr/bin/env bash

set -e

## XetHub
# ======================

# login
# -------------------
cat > /usr/local/bin/repos-xethub-login << 'EOF'
#!/usr/bin/env bash

set -e

echo "The value of XETHUB_USERNAME is: $XETHUB_USERNAME"
echo "The value of XETHUB_EMAIL is: $XETHUB_EMAIL"

if [ -z "$XETHUB_TOKEN" ]; then
  # If not set, assign the value of XETHUB_PAT to XETHUB_TOKEN
  XETHUB_TOKEN="$XETHUB_PAT"
fi

# Check if the environment variables are set and not empty
if [ -z "$XETHUB_USERNAME" ] || [ -z "$XETHUB_EMAIL" ] || [ -z "$XETHUB_TOKEN" ]; then
  echo "Error: One or more environment variables are not set. Please set XETHUB_USERNAME, XETHUB_EMAIL, and XETHUB_TOKEN."
  exit 1
else
  git xet login -u "$XETHUB_USERNAME" -e "$XETHUB_EMAIL" -p "$XETHUB_TOKEN"
fi
EOF

chmod +x /usr/local/bin/repos-xethub-login

# clone
# -------------------
cat > /usr/local/bin/repos-xethub-clone << 'EOF'
#!/usr/bin/env bash
# Clones all repos in repos-to-clone-xethub.list into the parent directory of the current working directory.

set -e

# Get the absolute path of the current working directory
current_dir="$(pwd)"

# Determine the parent directory of the current directory
parent_dir="$(cd "${current_dir}/.." && pwd)"

# Function to clone a repository
clone_repo() {
  cd "${parent_dir}"
  if [ ! -d "${1#*/}" ]; then
    git xet clone --lazy "xet://$1"
  else
    echo "Already cloned $1"
  fi
}

# Check if the file repos-to-clone-xethub.list exists
if [ -f "${current_dir}/repos-to-clone-xethub.list" ]; then
  # The file exists, now check if it's empty or not
  if grep -qvE '^\s*(#|$)' "${current_dir}/repos-to-clone-xethub.list"; then
    # The file is not empty, proceed with login
    repos-xethub-login
  fi
fi

# If there is a list of repositories to clone, clone them
if [ -f "./repos-to-clone-xethub.list" ]; then
  while IFS= read -r repository || [ -n "$repository" ]; do
    # Skip lines that are empty or contain only whitespace
    if [[ -z "$repository" || "$repository" =~ ^[[:space:]]*$ || "$repository" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    clone_repo "$repository"
  done < "./repos-to-clone-xethub.list"
fi
EOF

chmod +x /usr/local/bin/repos-xethub-clone

# GitHub
# ======================

# set up environment variables
# -------------------
mkdir -p "/var/tmp/repos"

cat > "/var/tmp/repos/repos-github-login-env" << 'EOF'
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
cat > /usr/local/bin/repos-github-clone << 'EOF'
#!/usr/bin/env bash

set -e

config_bashrc_d() {
  # ensure that `.bashrc.d` files are sourced in
  if [ -e "$HOME/.bashrc" ]; then
    # we assume that if `.bashrc.d` is mentioned in `$HOME/.bashrc`, then it's sourced in
    if [ -z "$(grep -F bashrc.d "$HOME/.bashrc")" ]; then
      # if it can't pick up `.bashrc.d`, tell it to source all files inside `.bashrc.d`
      echo 'for i in $(ls -A $HOME/.bashrc.d/); do source $HOME/.bashrc.d/$i; done' >> "$HOME/.bashrc"
    fi
  else
    # create bashrc if it doesn't exist, and tell it to source all files in `.bashrc.d`
    touch "$HOME/.bashrc"
    echo 'for i in $(ls -A $HOME/.bashrc.d/); do source $HOME/.bashrc.d/$i; done' > "$HOME/.bashrc"
  fi
  mkdir -p "$HOME/.bashrc.d"
}

add_to_bashrc_d() {
  if [ -d "/var/tmp/$1" ]; then
    for file in $(ls "/var/tmp/$1"); do
      cp "/var/tmp/$1/$file" "$HOME/.bashrc.d/$file"
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

# Source if not already in ~/.bashrc.d, and so it will presumably have been sourced otherwise already
if [ -f /var/tmp/repos/repos-github-login-env ]; then
  source /var/tmp/repos/repos-github-login-env
fi

config_bashrc_d
add_to_bashrc_d repos
clone_repos
EOF

chmod +x /usr/local/bin/repos-github-clone

# log in using the store to GitHub
# -------------------
cat > /usr/local/bin/repos-github-login-store << 'EOF'
#!/usr/bin/env bash

set -e

sudo apt update -y
sudo apt install -y jq

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

chmod +x /usr/local/bin/repos-github-login-store

## Push, pull, fetch

### log in using the store to GitHub
cat > /usr/local/bin/repos-github-push << 'EOF'
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
