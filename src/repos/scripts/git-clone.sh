cat > /usr/local/bin/repos-git-clone << 'EOF'
#!/usr/bin/env bash
set -e

usage() {
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  -f, --file <file>          Specify the repository list file (default: 'repos-to-clone.list')."
  echo "  -h, --help                 Display this help message."
  echo
  echo "Each line in the repository list file can be in the following formats:"
  echo "  repo_spec [target_directory]"
  echo
  echo "Where repo_spec is one of:"
  echo "  owner/repo[@branch]"
  echo "  datasets/owner/repo[@branch]"
  echo "  https://<host>/owner/repo[@branch]"
  echo
  echo "Examples:"
  echo "  user1/project1"
  echo "  user2/project2@develop ./Projects/Repo2"
  echo "  datasets/user3/dataset1@main ../Datasets"
  echo "  https://gitlab.com/user4/project4@feature-branch ./GitLabRepos"
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

clone_repos() {
  # Get the absolute path of the current working directory
  current_dir="$(pwd)"

  # Function to clone a repository
  clone_repo() {
    # Parse the repository line
    line="$1"
    # Remove leading and trailing whitespace
    line="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    # Split line into tokens
    tokens=($line)
    repo_spec="${tokens[0]}"
    target_dir="${tokens[1]:-".."}"  # Default to parent directory if not specified

    # Ensure target directory is relative to current directory
    target_dir="$(realpath -m "${current_dir}/${target_dir}")"

    # Create target directory if it doesn't exist
    mkdir -p "${target_dir}"
    cd "${target_dir}"

    # Split repo_spec into repo_url_or_path and branch
    if [[ "$repo_spec" == *@* ]]; then
      repo_url_or_path="${repo_spec%@*}"
      branch="${repo_spec##*@}"
    else
      repo_url_or_path="$repo_spec"
      branch=""
    fi

    # Determine repo_url and dir
    if [[ "$repo_url_or_path" =~ ^https:// ]]; then
      # Use the URL as is
      repo_url="$repo_url_or_path"
      dir="$(basename "${repo_url%%.git}" .git)"
    else
      repo="$repo_url_or_path"
      if [[ "$repo" =~ ^datasets/.* ]]; then
        host="https://huggingface.co"
        repo_path="$repo"
        dir="${repo#datasets/}"
      else
        host="https://github.com"
        repo_path="$repo"
        dir="${repo#*/}"
      fi
      repo_url="$host/$repo_path"
    fi

    # Ensure git lfs is set up for Hugging Face repos
    if [[ "$host" == "https://huggingface.co" ]]; then
      if command -v git-lfs &> /dev/null; then
        git lfs install --skip-repo
      fi
    fi

    if [ ! -d "$dir" ]; then
      if [ -z "$branch" ]; then
        git clone "$repo_url"
      else
        git clone -b "$branch" "$repo_url"
      fi
    else
      cd "$dir"
      if [ ! -d ".git" ]; then
        echo "Warning: $dir exists but is not a Git repository."
      else
        if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
          if [ -z "$branch" ]; then
            default_branch=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)
            git checkout "$default_branch"
          else
            current_branch=$(git rev-parse --abbrev-ref HEAD)
            if [ "$current_branch" != "$branch" ]; then
              git checkout "$branch"
            fi
          fi
        fi
      fi
      cd ..
      echo "Already cloned $repo_url"
    fi

    # Return to the original directory
    cd "${current_dir}"
  }

  # Clone repositories listed in the specified file
  if [ -f "${repos_list_file}" ]; then
    while IFS= read -r repository || [ -n "$repository" ]; do
      # Skip empty lines and comments
      if [[ -z "$repository" || "$repository" =~ ^[[:space:]]*$ || "$repository" =~ ^[[:space:]]*# ]]; then
        continue
      fi
      clone_repo "$repository"
    done < "${repos_list_file}"
  else
    echo "Repository list file '${repos_list_file}' not found."
    exit 1
  fi
}

clone_repos

EOF

# Make the script executable
chmod +x /usr/local/bin/repos-git-clone

echo "Script /usr/local/bin/repos-git-clone has been created and made executable."
