#!/usr/bin/env bash

set -e

## XetHub

### login
cat > /usr/local/bin/repos-xethub-login \
<< 'EOF'
#!/usr/bin/env bash

set -e

if [ -z "$XETHUB_TOKEN" ]
then
    # If not set, assign the value of XETHUB_PAT to XETHUB_TOKEN
    XETHUB_TOKEN="$XETHUB_PAT"
fi

# Check if the environment variables are set and not empty
if [ -z "$XETHUB_USERNAME" ] || [ -z "$XETHUB_EMAIL" ] || [ -z "$XETHUB_TOKEN" ]
then
    echo "Error: One or more environment variables are not set. Please set XETHUB_USERNAME, XETHUB_EMAIL, and XETHUB_TOKEN."
    exit 1
else
    git xet login -u "$XETHUB_USERNAME" -e "$XETHUB_EMAIL" -p "$XETHUB_TOKEN"
fi

EOF

chmod +x /usr/local/bin/repos-xethub-login

### clone

cat > /usr/local/bin/repos-xethub-clone \
<< 'EOF'
#!/usr/bin/env bash
# Clones all repos in repos-to-clone-xethub.list
# into the parent directory of the current
# working directory.

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
if [ -f "${current_dir}/repos-to-clone-xethub.list" ]
then
    # The file exists, now check if it's empty or not
    if grep -qvE '^\s*(#|$)' "${current_dir}/repos-to-clone-xethub.list"
    then
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

## GitHub

cat > /usr/local/bin/repos-github-clone \
<< 'EOF'
#!/usr/bin/env bash

set -e

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

chmod +x /usr/local/bin/repos-github-clone

### log in using the store to GitHub
cat > /usr/local/bin/repos-github-login-store \
<< 'EOF'
#!/usr/bin/env bash

set -e

#!/usr/bin/env bash

# Use plain-text credential store
git config --global credential.helper 'store'

# Get GitHub username
# username=$(gh api user | jq -r '.login')
username=$GITHUB_USERNAME

# Get GitHub PAT from environment variable
PAT=$GITHUB_PAT

if [ -z "$PAT" ]
then
    PAT=$GH_TOKEN
fi

if [ -z "$PAT" ]
then
    PAT=$GITHUB_TOKEN
fi

if [ -z "$PAT" ] || [ -z "$username" ]
then
    echo "Error: One or more environment variables are not set. Please set GITHUB_USERNAME and GITHUB_PAT."
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
cat > /usr/local/bin/repos-github-push \
<< 'EOF'
#!/usr/bin/env bash

IFS=""
all_args="$*"
git 
IFS=" "

EOF



## Add to workspace

cat > /usr/local/bin/repos-workspace-add \
<< 'EOF'
#!/usr/bin/env bash

set -e

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

chmod +x /usr/local/bin/repos-workspace-add