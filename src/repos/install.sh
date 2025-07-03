#!/usr/bin/env bash
set -e

# Must be root (for /usr/local/bin)
[ "$(id -u)" -eq 0 ] || { echo "Please run as root (or via sudo)." >&2; exit 1; }

# ── Portable sed -i flags ────────────────────────────────────────────────────
if sed --version >/dev/null 2>&1; then
  SED_INPLACE=(-i)
else
  SED_INPLACE=(-i '')
fi

# ── Initialize a command file with a bash shebang ────────────────────────────
initialize_command_file() {
  local file_path="$1"

  if [ ! -f "$file_path" ]; then
    printf '#!/usr/bin/env bash\n' > "$file_path"
  else
    # Only insert if neither /bin/bash nor env bash is present
    if ! grep -qE '^#!.*/(bash|env bash)' "$file_path"; then
      sed "${SED_INPLACE[@]}" '1i#!/usr/bin/env bash' "$file_path"
    fi
  fi

  chmod 755 "$file_path"
}

# ── Copy a script into /usr/local/bin and make it executable ────────────────
copy_and_set_execute_bit() {
  local script_name="$1"
  local dest="/usr/local/bin/repos-$script_name"

  if ! cp "cmd/$script_name" "$dest"; then
    echo "Failed to copy cmd/$script_name to $dest" >&2
    exit 1
  fi

  chmod 755 "$dest"
}

# ── Append a command (with error-handler) to a file if not already present ──
append_command_with_error_handling() {
  local cmd_line="$1"
  local file_path="$2"

  # Must be a regular file or absent
  if [ -e "$file_path" ] && [ ! -f "$file_path" ]; then
    echo "Error: $file_path exists but is not a regular file" >&2
    exit 2
  fi

  # Create if missing
  [ -f "$file_path" ] || touch "$file_path" || {
    echo "Error: Failed to create $file_path" >&2
    exit 3
  }

  # Skip if already present (exact match including handler)
  if ! grep -Fxq "$cmd_line || { echo \"Failed to run $cmd_line\"; }" "$file_path"; then
    printf '%s || {\n    echo "Failed to run %s"\n}\n\n' \
      "$cmd_line" "$cmd_line" >> "$file_path"
  fi
}

# ── Main install flow ────────────────────────────────────────────────────────

source scripts/lib.sh

copy_and_set_execute_bit git-auth
copy_and_set_execute_bit git-create
copy_and_set_execute_bit git-clone

copy_and_set_execute_bit codespaces-auth
copy_and_set_execute_bit workspace-add

source scripts/shellrc-config.sh

# Paths for post-create and post-start command files
PATH_POST_CREATE_COMMAND=/usr/local/bin/repos-post-create
PATH_START_COMMAND=/usr/local/bin/repos-post-start

initialize_command_file "$PATH_POST_CREATE_COMMAND"
initialize_command_file "$PATH_START_COMMAND"

# post-create: ensure auth
append_command_with_error_handling \
'if [ "$(id -u)" -eq 0 ]; then
    /usr/local/bin/repos-git-auth --scope system;
else
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        sudo /usr/local/bin/repos-git-auth --scope system;
    else
        echo "Warning: Cannot run as root and sudo is not available. Skipping."
    fi;
fi' \
"$PATH_POST_CREATE_COMMAND"

# post-start: create, clone and add to workspace
append_command_with_error_handling "/usr/local/bin/repos-git-create" "$PATH_START_COMMAND"
append_command_with_error_handling "/usr/local/bin/repos-git-clone"  "$PATH_START_COMMAND"
append_command_with_error_handling "/usr/local/bin/repos-workspace-add" "$PATH_START_COMMAND"
