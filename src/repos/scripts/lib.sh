#!/usr/bin/env bash

# Must be root
[ "$(id -u)" -eq 0 ] || { echo "Please run as root (or via sudo)." >&2; exit 1; }

apt-get update -y

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
  echo "jq could not be found, installing jq..."
  apt-get install -y jq
fi
