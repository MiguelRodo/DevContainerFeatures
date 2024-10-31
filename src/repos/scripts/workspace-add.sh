cat > /usr/local/bin/repos-workspace-add << 'EOF'
#!/usr/bin/env bash

set -e

usage() {
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  -f, --file <file>       Specify the path to the repository list file."
  echo "                          Defaults to 'repos-to-clone.list'."
  echo "  -h, --help              Display this help message."
  echo
  echo "Each line in the repository list file should be in one of the following formats:"
  echo "  owner/repo[@branch]"
  echo "  datasets/owner/repo[@branch]"
  echo "  https://<host>/owner/repo[@branch]"
  echo
  echo "Examples:"
  echo "  user1/project1"
  echo "  user2/project2@develop"
  echo "  datasets/user3/dataset1@main"
  echo "  https://gitlab.com/user4/project4@feature-branch"
}

# Default values
repos_list_file="repos-to-clone.list"

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -f|--file)
      if [[ -n "$2" ]]; then
        repos_list_file="$2"
        shift 2
      else
        echo "Error: --file requires an argument."
        usage
        exit 1
      fi
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Get the absolute path of the current working directory
current_dir="$(pwd)"
echo "Current directory:"
echo "$current_dir"

# Define the path to the workspace JSON file
workspace_file="${current_dir}/EntireProject.code-workspace"

# Create the workspace file if it does not exist and is needed
if [ ! -f "$workspace_file" ]; then
  k=0
  if [ -f "${repos_list_file}" ]; then
    while IFS= read -r repository || [ -n "$repository" ]; do
      # Skip lines that are empty or contain only whitespace
      if [[ -z "$repository" || "$repository" =~ ^[[:space:]]*$ || "$repository" =~ ^[[:space:]]*# ]]; then
        continue
      fi
      k=1
      break
    done < "${repos_list_file}"
  fi
  if [ "$k" -eq 1 ]; then
    echo "Workspace file does not exist. Creating it now..."
    echo '{"folders": [{"path": "."}]}' > "$workspace_file"
  fi
fi

add_to_workspace() {
  # Ensure jq is installed
  if ! command -v jq &> /dev/null; then
    echo "jq could not be found, installing jq..."
    sudo apt update -y
    sudo apt install -y jq
  fi

  # Read and process each line from the input file
  while IFS= read -r line || [ -n "$line" ]; do
    # Skip lines that are empty, contain only whitespace, or start with a hash
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# || "$line" =~ ^[[:space:]]+$ ]]; then
      continue
    fi

    # Remove leading and trailing whitespace
    line="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    # Split line into repo_url_or_path and branch
    if [[ "$line" == *@* ]]; then
      repo_url_or_path="${line%@*}"
      branch="${line##*@}"
    else
      repo_url_or_path="$line"
      branch=""
    fi

    # Initialize variables
    repo_url=""
    dir=""

    # Check if repo_url_or_path starts with 'https://'
    if [[ "$repo_url_or_path" =~ ^https:// ]]; then
      # Use the URL as is
      repo_url="$repo_url_or_path"
      # Remove .git if present for directory naming
      dir="$(basename "${repo_url%%.git}" .git)"
    else
      repo="$repo_url_or_path"
      # Determine host and repository path
      if [[ "$repo" =~ ^datasets/.* ]]; then
        # Use huggingface.co
        host="https://huggingface.co"
        repo_path="$repo"
        dir="${repo#datasets/}"
      else
        # Use GitHub
        host="https://github.com"
        repo_path="$repo"
        dir="${repo#*/}"
      fi

      repo_url="$host/$repo_path"
    fi

    # The repos are cloned into the parent directory of the current directory
    # So the relative path from the current directory to the repo directory is "../<dir>"
    repo_path="../$dir"

    # Check if the path is already in the workspace file
    if [ -f "$workspace_file" ]; then
      if jq -e --arg path "$repo_path" '.folders[] | select(.path == $path) | length > 0' "$workspace_file" > /dev/null; then
        continue
      fi
      # Add the path to the workspace JSON file
      jq --arg path "$repo_path" '.folders += [{"path": $path}]' "$workspace_file" > temp.json && mv temp.json "$workspace_file"
    else
      # Create the workspace file with the repo path
      echo "{\"folders\": [{\"path\": \"$repo_path\"}]}" > "$workspace_file"
    fi

  done < "$1"
}

# Attempt to add from the specified file if it exists
if [ -f "${repos_list_file}" ]; then
  add_to_workspace "${repos_list_file}"
else
  echo "Repository list file '${repos_list_file}' not found."
  exit 1
fi

EOF

# Make the script executable
chmod +x /usr/local/bin/repos-workspace-add

echo "Script /usr/local/bin/repos-workspace-add has been created and made executable."
