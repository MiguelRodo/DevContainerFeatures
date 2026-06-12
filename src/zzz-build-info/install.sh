#!/usr/bin/env bash

set -e

IMAGE_VERSION="${IMAGEVERSION:-""}"

# 1. Define the number boundary:
# Matches '0', any number from '1' to '99999' (no leading zeros), or exactly '100000'
NUM_REGEX="(0|[1-9][0-9]{0,4}|100000)"

# 2. Construct the full version regex
# ^[vV]?                       : Optional 'v' or 'V' at the start
# ${NUM_REGEX}                 : <major> (Required if version is specified)
# (\.${NUM_REGEX}(\.${NUM_REGEX})?)? : Optional <minor> OR <minor>.<patch>
# ([-.]${NUM_REGEX})?$         : Optional <dev> preceded by '.' or '-' at the end
VERSION_REGEX="^[vV]?${NUM_REGEX}(\.${NUM_REGEX}(\.${NUM_REGEX})?)?([-.]${NUM_REGEX})?$"

# 3. Validate if the user provided a version
if [[ "$IMAGE_VERSION" != "" ]]; then
    if [[ ! "$IMAGE_VERSION" =~ $VERSION_REGEX ]]; then
        echo "[ERROR] Invalid imageVersion format provided: '$IMAGE_VERSION'" >&2
        echo "        Valid examples: 1, v1.2, V1.2.3, v1-4, 1.2.3.4, v2.0-12" >&2
        echo "        Rules:" >&2
        echo "        - Format: [v|V]<major>[.<minor>[.<patch>]][-|.]<dev>" >&2
        echo "        - All components must be between 0 and 100000." >&2
        echo "        - Cannot have leading zeros (e.g., '01' is invalid)." >&2
        exit 1
    fi
fi

RAW_BUILD_DATE="${BUILDDATE:-""}"

ISO_8601_REGEX="^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[-+][0-9]{2}:?[0-9]{2})?$"
if [[ -z "$RAW_BUILD_DATE" ]]; then
    # No date provided: fall back to the safe system generation string
    BUILD_DATE=$(date --iso-8601=seconds -u)
elif [[ "$RAW_BUILD_DATE" =~ $ISO_8601_REGEX || "$RAW_BUILD_DATE" == "unknown" || "$RAW_BUILD_DATE" == "development" ]]; then
    # It matches a proper date format or our accepted default strings
    BUILD_DATE="$RAW_BUILD_DATE"
else
    # Something invalid or suspicious was passed: reject it gracefully and log a warning
    echo "[WARNING] Invalid or unsafe BUILDDATE format provided: '$RAW_BUILD_DATE'." >&2
    echo "[WARNING] Falling back to standard system ISO-8601 timestamp." >&2
    BUILD_DATE=$(date --iso-8601=seconds -u)
fi

DATA_DIR="/usr/local/etc/container_metadata"
mkdir -p "$DATA_DIR"

cat << EOF > "${DATA_DIR}/build_info.txt"
IMAGE_VERSION="${IMAGE_VERSION}"
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

echo "--------------------------------------------------"
echo "🚀 DevContainer Release Information"
echo "--------------------------------------------------"
cat "$DATA_FILE" | grep "^IMAGE_VERSION=" | sed 's/^IMAGE_VERSION="/  Version : /' | sed 's/"$//'
cat "$DATA_FILE" | grep "^BUILD_DATE=" | sed 's/^BUILD_DATE="/  Built On: /' | sed 's/"$//'
echo "--------------------------------------------------"
EOF

chmod +x "$COMMAND_PATH"
echo "Metadata injection and system command generation complete!"
