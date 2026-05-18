#!/usr/bin/env bash

set -e

VERSION="${VERSION:-"development"}"
BUILD_DATE="${BUILDDATE:-"unknown"}"

DATA_DIR="/usr/local/etc/container_metadata"
mkdir -p "$DATA_DIR"

cat << EOF > "${DATA_DIR}/build_info.txt"
CONTAINER_VERSION="${VERSION}"
BUILD_DATE="${BUILD_DATE}"
EOF

COMMAND_PATH="/usr/local/bin/container-info"
cat << 'EOF' > "$COMMAND_PATH"
#!/usr/bin/env bash
DATA_FILE="/usr/local/etc/container_metadata/build_info.txt"
if [ ! -f "$DATA_FILE" ]; then
    echo "[ERROR] Container release metadata log file is missing." >&2
    exit 1
fi

. "$DATA_FILE"

echo "--------------------------------------------------"
echo "🚀 DevContainer Release Information"
echo "--------------------------------------------------"
echo "  Version : ${CONTAINER_VERSION}"
echo "  Built On: ${BUILD_DATE}"
echo "--------------------------------------------------"
EOF

chmod +x "$COMMAND_PATH"
echo "Metadata injection and system command generation complete!"