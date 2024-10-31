#!/usr/bin/env bash

set -e

## Config shellrc
config_shellrc_d() {
  # Determine which shell configuration file to use
  # Override for specifying the shell to configure (either "bash" or "zsh")
  local shell_override="${1:-}"

  # Determine the configuration file and directory based on override or existing files
  if [ "$shell_override" = "bash" ]; then
    shell_rc="$HOME/.bashrc"
    shell_rc_d_name=".bashrc.d"
  elif [ "$shell_override" = "zsh" ]; then
    shell_rc="$HOME/.zshrc"
    shell_rc_d_name=".zshrc.d"
  else
    if [ -e "$HOME/.bashrc" ]; then
      shell_rc="$HOME/.bashrc"
      shell_rc_d_name=".bashrc.d"
    elif [ -e "$HOME/.zshrc" ]; then
      shell_rc="$HOME/.zshrc"
      shell_rc_d_name=".zshrc.d"
    else
      # Default to .bashrc if neither exists
      shell_rc="$HOME/.bashrc"
      shell_rc_d_name=".bashrc.d"
      touch "$shell_rc"
    fi
  fi

  # Ensure that the corresponding .rc.d directory is sourced in the shell configuration file
  if ! grep -qF "$shell_rc_d_name" "$shell_rc"; then
    echo "for i in \$(ls -A \$HOME/$shell_rc_d_name/); do source \$HOME/$shell_rc_d_name/\$i; done" >> "$shell_rc"
  fi

  # Create the directory for shell configuration scripts
  mkdir -p "$HOME/$shell_rc_d_name"
}

config_shellrc_d
