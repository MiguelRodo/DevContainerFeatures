#!/usr/bin/env bash
set -e

# Must be root
[ "$(id -u)" -eq 0 ] || { echo "Please run as root (or via sudo)." >&2; exit 1; }

# ── Install prerequisites ────────────────────────────────────────────────────
echo "Installing prerequisites..."
apt-get update
apt-get install -y curl gnupg ca-certificates

# ── Setup APT repository ─────────────────────────────────────────────────────
echo "Setting up APT repository..."
# Download the GPG key
curl -fsSL https://raw.githubusercontent.com/MiguelRodo/apt-miguelrodo/main/KEY.gpg \
  -o /usr/share/keyrings/miguelrodo-repos.gpg

# Add the repository source
echo "deb [signed-by=/usr/share/keyrings/miguelrodo-repos.gpg] https://raw.githubusercontent.com/MiguelRodo/apt-miguelrodo/main/ ./" \
  > /etc/apt/sources.list.d/miguelrodo-repos.list

# ── Install repos package ────────────────────────────────────────────────────
echo "Installing repos package..."
apt-get update
apt-get install -y repos

# ── Configure start script ───────────────────────────────────────────────────
echo "Configuring post-start script..."
POST_START_SCRIPT="/usr/local/bin/repos-post-start"

# Check RUNONSTART environment variable (defaults to true if not set)
if [ "${RUNONSTART}" = "false" ]; then
  cat > "$POST_START_SCRIPT" << 'EOF'
#!/usr/bin/env bash
echo "repos start-up skipped"
EOF
else
  cat > "$POST_START_SCRIPT" << 'EOF'
#!/usr/bin/env bash
repos
EOF
fi

# Make the script executable
chmod +x "$POST_START_SCRIPT"

# ── Cleanup ──────────────────────────────────────────────────────────────────
echo "Cleaning up..."
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "repos feature installation complete!"
