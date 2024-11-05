#!/usr/bin/env bash
set -e

INSTALL_HUGGINGFACE="${INSTALLHUGGINGFACE:-true}"
HUGGINGFACE_INSTALL_SCOPE="${HUGGINGFACEINSTALLSCOPE:-system}"

initialize_command_file() {
    local file_path="$1"
    if [ ! -f "$file_path" ]; then
        printf '#!/usr/bin/env bash\n' > "$file_path"
    else
        # Check if shebang exists; add if missing
        if ! grep -q '^#!/usr/bin/env bash' "$file_path"; then
            sed -i '1i#!/usr/bin/env bash' "$file_path"
        fi
    fi
    chmod 755 "$file_path"
}

# Function to append a command with error handling to a specified file
append_command_with_error_handling() {
    local command="$1"
    local file_path="$2"
    # Check if the command already exists to prevent duplicates
    if ! grep -Fxq "$command || { echo \"Failed to run $command\"; }" "$file_path"; then
        printf '%s || {\n    echo "Failed to run %s"\n}\n\n' "$command" "$command" >> "$file_path"
    fi
}

# install scripts
# ---------------------

source scripts/hf-install.sh

source scripts/git-auth.sh

source scripts/git-clone.sh

source scripts/workspace-add.sh

source scripts/shellrc-config.sh

# set up post-create and post-start commands
# ---------------------

# Paths to the command files
PATH_POST_CREATE_COMMAND=/usr/local/bin/repos-post-create
PATH_START_CREATE_COMMAND=/usr/local/bin/repos-post-start

# Initialize the command files
initialize_command_file "$PATH_POST_CREATE_COMMAND"
initialize_command_file "$PATH_START_CREATE_COMMAND"

# Add commands
append_command_with_error_handling \
    "/usr/local/bin/repos-workspace-add" "$PATH_POST_CREATE_COMMAND"
append_command_with_error_handling \
    "sudo /usr/local/bin/repos-git-auth --scope system" "$PATH_POST_CREATE_COMMAND"
append_command_with_error_handling \
    "/usr/local/bin/repos-git-clone" "$PATH_POST_CREATE_COMMAND"

# post-start
append_command_with_error_handling \
    "/usr/local/bin/repos-workspace-add" "$PATH_START_CREATE_COMMAND"
append_command_with_error_handling \
    "/usr/local/bin/repos-git-clone" "$PATH_START_CREATE_COMMAND"

# run scripts
# ---------------------

# install Hugging Face
if [ "$INSTALL_HUGGINGFACE" = "true" ]; then
  repos-hf-install --hf-scope "$HUGGINGFACE_INSTALL_SCOPE"
fi

