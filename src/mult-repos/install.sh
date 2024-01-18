#!/usr/bin/env bash

set -e

## XetHub

cat > /usr/local/bin/repos-clone-xethub \
<< 'EOF'
#!/usr/bin/env bash
# Clones all repos in repos-to-clone-xethub.list
# into the parent directory of the current
# working directory.

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
if [ -f "${current_dir}/repos-to-clone-xethub.list" ]
then
    # The file exists, now check if it's empty or not
    if grep -qvE '^\s*(#|$)' "${current_dir}/repos-to-clone-xethub.list"
    then
      # The file is not empty, proceed with login
        # Check if the environment variables are set and not empty
       if [ -z "$XETHUB_USERNAME" ] || [ -z "$XETHUB_EMAIL" ] || [ -z "$XETHUB_PAT" ]
       then
           echo "Error: One or more environment variables are not set. Please set XETHUB_USERNAME, XETHUB_EMAIL, and XETHUB_PAT."
           exit 1
       else
           git xet login -u "$XETHUB_USERNAME" -e "$XETHUB_EMAIL" -p "$XETHUB_PAT"
       fi
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

chmod +x /usr/local/bin/repos-clone-xethub

## GitHub

cat > /usr/local/bin/repos-clone-github \
<< 'EOF'
#!/usr/bin/env bash

# Clones all repos in repos-to-clone.list
# into the parent directory of the current
# working directory.

# Get the absolute path of the current working directory
current_dir="$(pwd)"

# Determine the parent directory of the current directory
parent_dir="$(cd "${current_dir}/.." && pwd)"


# Function to clone a repository
clone_repo()
{
    cd "${parent_dir}"
    if [ ! -d "${1#*/}" ]; then
        git clone "https://github.com/$1"
    else 
        echo "Already cloned $1"
    fi
}

# If running in a Codespace, set up Git credentials
if [ "${CODESPACES}" = "true" ]; then
    # Remove the default credential helper
    sudo sed -i -E 's/helper =.*//' /etc/gitconfig

    # Add one that just uses secrets available in the Codespace
    git config --global credential.helper '!f() { sleep 1; echo "username=${GITHUB_USER}"; echo "password=${GH_TOKEN}"; }; f'
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
EOF

chmod +x /usr/local/bin/repos-clone-github

## Add to workspace

cat > /usr/local/bin/repos-add-workspace \
<< 'EOF'
#!/usr/bin/env bash

# Get the absolute path of the current working directory
current_dir="$(pwd)"
echo "current_dir"
echo "$current_dir"

# Define the path to the workspace JSON file
workspace_file="${current_dir}/EntireProject.code-workspace"

# Create the workspace file if it does not exist
if [ ! -f "$workspace_file" ]; then
  echo "Workspace file does not exist. Creating it now..."
  echo '{"folders": [{"path": "."}]}' > "$workspace_file"
fi

add_to_workspace() {

  # Read and process each line from the input file
  while IFS= read -r repo || [ -n "$repo" ]; do

    # Skip lines that are empty, contain only whitespace, or start with a hash
    if [[ -z "$repo" || "$repo" =~ ^[[:space:]]*# || "$repo" =~ ^[[:space:]]+$ ]]; then
      continue
    fi

    # Extract the repository name and create the path
    repo_name="${repo##*/}"
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

chmod +x /usr/local/bin/repos-add-workspace