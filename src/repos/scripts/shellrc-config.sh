#!/usr/bin/env bash
set -e

config_shellrc_d() {
  local shell_override="${1:-}"
  local shell_rc shell_rc_d_name snippet

  # 1) Pick RC file and its “.rc.d” directory
  case "$shell_override" in
    bash)
      shell_rc="$HOME/.bashrc"
      shell_rc_d_name=".bashrc.d"
      ;;
    zsh)
      shell_rc="$HOME/.zshrc"
      shell_rc_d_name=".zshrc.d"
      ;;
    *)
      if   [ -e "$HOME/.bashrc" ]; then
        shell_rc="$HOME/.bashrc"
        shell_rc_d_name=".bashrc.d"
      elif [ -e "$HOME/.zshrc" ];  then
        shell_rc="$HOME/.zshrc"
        shell_rc_d_name=".zshrc.d"
      else
        shell_rc="$HOME/.bashrc"
        shell_rc_d_name=".bashrc.d"
        touch "$shell_rc"
      fi
      ;;
  esac

  # 2) The exact snippet we want to append (with quotes to handle spaces)
  snippet='for i in "$HOME/'"$shell_rc_d_name"'"/*; do
    [ -e "$i" ] && source "$i"
  done'

  # 3) Append it only if it's not already in the RC
  if ! grep -Fxq "$snippet" "$shell_rc"; then
    printf "\n%s\n" "$snippet" >> "$shell_rc"
  fi

  # 4) Create the directory if missing
  mkdir -p "$HOME/$shell_rc_d_name"
}

config_shellrc_d "${1:-}"
