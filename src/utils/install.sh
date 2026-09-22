#!/usr/bin/env bash
set -e

[ "$(id -u)" -eq 0 ] || { echo "Please run as root (or via sudo)." >&2; exit 1; }

INSTALL_REPOS=${INSTALLREPOS:-true}
REPOS_VERSION=${REPOSVERSION:-2.7.1}
INSTALL_SETUPMJR=${INSTALLSETUPMJR:-true}
SETUPMJR_VERSION=${SETUPMJRVERSION:-0.7.5}
RUN_ON_START=${RUNONSTART:-false}

if [ "$INSTALL_REPOS" = "false" ] && [ "$INSTALL_SETUPMJR" = "false" ]; then
    echo "Both installRepos and installSetupmjr are false. Nothing to do."
    exit 0
fi

normalise_version() {
    local value
    value=${1#v}
    if [[ ! "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: invalid version '$1'; expected X.Y.Z." >&2
        return 1
    fi
    printf '%s\n' "$value"
}

release_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo amd64 ;;
        arm64|aarch64) echo arm64 ;;
        *) echo "Error: unsupported architecture: $(uname -m)" >&2; return 1 ;;
    esac
}

install_release_binary() (
    set -e
    local repo=$1 name=$2 version=$3 arch asset checksums base tmp expected actual
    arch=$(release_arch)
    asset="${name}_linux_${arch}"
    checksums="${name}_${version}_checksums.txt"
    base="https://github.com/${repo}/releases/download/v${version}"
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    echo "Installing ${name} ${version}..."
    curl -fsSL "${base}/${asset}" -o "${tmp}/${asset}"
    curl -fsSL "${base}/${checksums}" -o "${tmp}/${checksums}"

    expected=$(awk -v asset="$asset" '$2 == asset || $2 == "*" asset {print $1; exit}' "${tmp}/${checksums}")
    if [[ ! "$expected" =~ ^[0-9a-fA-F]{64}$ ]]; then
        echo "Error: checksum for ${asset} not found in ${checksums}." >&2
        exit 1
    fi
    actual=$(sha256sum "${tmp}/${asset}" | awk '{print $1}')
    if [ "$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')" != "$actual" ]; then
        echo "Error: checksum verification failed for ${name} ${version}." >&2
        exit 1
    fi

    cp "${tmp}/${asset}" "/usr/local/bin/${name}"
    chmod 0755 "/usr/local/bin/${name}"
)

if [ "$INSTALL_REPOS" = "true" ]; then
    REPOS_VERSION=$(normalise_version "$REPOS_VERSION")
fi
if [ "$INSTALL_SETUPMJR" = "true" ]; then
    SETUPMJR_VERSION=$(normalise_version "$SETUPMJR_VERSION")
fi

# Install runtime dependencies using the image's native package manager.
if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y ca-certificates curl git jq wget
    mkdir -p -m 755 /etc/apt/keyrings
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg > /etc/apt/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
    apt-get update
    apt-get install -y gh
elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache bash ca-certificates curl git jq github-cli gcompat
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y bash ca-certificates curl git jq gh
elif command -v yum >/dev/null 2>&1; then
    yum install -y bash ca-certificates curl git jq gh
elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm bash ca-certificates curl git jq github-cli
else
    echo "Warning: unknown package manager. Required dependencies: bash, ca-certificates, curl, git, jq, gh, sha256sum" >&2
fi

command -v sha256sum >/dev/null 2>&1 || { echo "Error: sha256sum is required." >&2; exit 1; }

if [ "$INSTALL_REPOS" = "true" ]; then
    install_release_binary MiguelRodo/repos repos "$REPOS_VERSION"
fi

if [ "$INSTALL_SETUPMJR" = "true" ]; then
    install_release_binary MiguelRodo/setupmjr setupmjr "$SETUPMJR_VERSION"
fi

if command -v apt-get >/dev/null 2>&1; then
    apt-get clean
    rm -rf /var/lib/apt/lists/*
fi

POST_START_SCRIPT=/usr/local/bin/utils-post-start
cat > "$POST_START_SCRIPT" << 'EOF'
#!/usr/bin/env bash
EOF

if [ "$INSTALL_REPOS" = "true" ] && [ "$RUN_ON_START" = "true" ]; then
    cat >> "$POST_START_SCRIPT" << 'EOF'
REPOS_LIST="${REPOS_LIST:-repos.list}"
if [ -f "$REPOS_LIST" ]; then
  repos clone
else
  echo "Info: No repos.list file found. Skipping repository setup."
  echo "Create a repos.list file and run 'repos clone' to clone repositories."
fi
EOF
fi

chmod +x "$POST_START_SCRIPT"
echo "MiguelRodo Utils feature installation complete!"
