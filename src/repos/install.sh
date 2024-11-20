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

# Function to copy a script and set its execute permissions
copy_and_set_execute_bit() {
    local script_name="$1"

    # Copy the script to /usr/local/bin with a prefixed name
    if ! cp "cmd/$script_name" "/usr/local/bin/repos-$script_name"; then
        echo "Failed to copy cmd/$script_name"
    fi

    # Set execute permissions on the copied script
    if ! chmod 755 "/usr/local/bin/repos-$script_name"; then
        echo "Failed to set execute bit for /usr/local/bin/repos-$script_name"
    fi
}


# Function to append a command with error handling to a specified file
append_command_with_error_handling() {
    local command="$1"
    local file_path="$2"
    if [ -e "$file_path" ] && [ ! -f "$file_path" ]; then
        echo "Error: $file_path exists but is not a regular file"
        exit 2
    fi

    # Create the file if it doesn't exist
    if [ ! -f "$file_path" ]; then
        if ! touch "$file_path"; then
            echo "Error: Failed to create $file_path"
            exit 3
        fi
    fi

    # Check if the command already exists to prevent duplicates
    if ! grep -Fxq "$command || { echo \"Failed to run $command\"; }" "$file_path"; then
        printf '%s || {\n    echo "Failed to run %s"\n}\n\n' "$command" "$command" >> "$file_path"
    fi
}

# install scripts
# ---------------------

source scripts/lib.sh

copy_and_set_execute_bit hf-install

copy_and_set_execute_bit git-auth

copy_and_set_execute_bit git-clone

copy_and_set_execute_bit workspace-add

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

# post-create
append_command_with_error_handling \
'if [ \"$(id -u)\" -eq 0 ]; then 
    /usr/local/bin/repos-git-auth --scope system; 
else 
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then 
        sudo /usr/local/bin/repos-git-auth --scope system; 
    else 
        echo \"Warning: Cannot run as root and sudo is not available. Skipping.\" 
    fi; 
fi' "$PATH_POST_CREATE_COMMAND"

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

