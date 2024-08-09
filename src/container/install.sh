#!/usr/bin/env bash

set -e

path_container_build_and_share="/usr/local/bin/container-build-and-share"
cat > "$path_config_r_bashrc" \
<< 'EOF'
#!/usr/bin/env bash

set -e

# Function to display usage
usage() {
    echo "Usage: $0 [-r <github_repo>] [-u <github_user>] [-b <branch>] [-i <image_name>] [-t <tag>] [-a] [-d]"
    echo "  -r <github_repo>  : GitHub repository (optional, defaults to basename of current directory)"
    echo "  -b <branch>       : Branch name (optional)"
    echo "  -u <github_user>  : GitHub user/org (optional, defaults to GITHUB_USERNAME environment variable)"
    echo "  -c                : devcontainer.json path, within the cloned repo (optional, defaults to default of `devcontainer build`)"
    echo "  -i <image_name>   : Image name (optional, defaults to basename of current directory. Forced to lower case.)"
    echo "  -t <tag>          : Tag (optional, defaults to 'latest')"
    echo "  -a                : Do not upload Apptainer image as a GitHub release (optional, defaults to uploading)"
    echo "  -d                : Do not upload Docker image to GitHub container registry (optional, defaults to uploading)"
    echo "  -h                : Show this help message"
    exit 1
}

# Initialize flags
BRANCH=""
GITHUB_USER="$GITHUB_USERNAME"
DEVCONTAINER_JSON=""
# Initialize flags with default behavior set to true
UPLOAD_APPTAINER=true
UPLOAD_DOCKER=true

# Parse named parameters
while getopts ":r:u:b:c:i:t:ad:h" opt; do
    case ${opt} in
        r )
            GITHUB_REPO=$OPTARG
            ;;
        u )
            GITHUB_USER=$OPTARG
            ;;
        b )
            BRANCH=$OPTARG
            ;;
        c ) 
            DEVCONTAINER_JSON=$OPTARG
            ;;
        i )
            IMAGE_NAME=$OPTARG
            ;;
        t )
            TAG=$OPTARG
            ;;
        a )
            UPLOAD_APPTAINER=false
            ;;
        d )
            UPLOAD_DOCKER=false
            ;;
        h )
            usage
            exit 0
            ;;
        \? )
            usage
            ;;
    esac
done

# Set default values based on options or fallback to defaults
TAG=${TAG:-latest}
IMAGE_NAME=${IMAGE_NAME:-$(basename "$(pwd)")}
IMAGE_NAME=$(echo "$IMAGE_NAME" | tr '[:upper:]' '[:lower:]')
TAR_FILE="$IMAGE_NAME.tar"
SIF_FILE="$IMAGE_NAME.sif"
GITHUB_REPO=${GITHUB_REPO:-$(basename "$(pwd)")}
LOWER_GITHUB_REPO=$(echo "$GITHUB_REPO" | tr '[:upper:]' '[:lower:]')
DEVCONTAINER_JSON=${DEVCONTAINER_JSON:-".devcontainer/devcontainer.json"}


# check that gh_token is set, throw error if not
if [ -z "$GH_TOKEN" ]; then
  echo "GH_TOKEN environment variable is not set. Please set it to a GitHub token with the necessary permissions."
  exit 1
fi
if [ -z "$GITHUB_USER" ]; then
  echo "GITHUB_USER environment variable is not set. Please set it to the username of the repo to create a devcontainer from."
  exit 1
fi

# functions
# -------------------

clone_repo() {
  echo "Cloning GitHub repository $GITHUB_REPO"
  # Clone a GitHub repository
  # container a devcontainer/devcontainer.json file
  TMP_DIR=$(mktemp -d)
  if [ -z "$BRANCH" ]; then
    echo "Cloning default branch"
    git clone "https://$GH_TOKEN@github.com/$GITHUB_USER/$GITHUB_REPO.git" "$TMP_DIR"
  else
    echo "Cloning branch $BRANCH"
    git clone -b "$BRANCH" "https://$GH_TOKEN@github.com/$GITHUB_USER/$GITHUB_REPO.git" "$TMP_DIR"
  fi
  echo "Successfully cloned GitHub repository $GITHUB_USER/$GITHUB_REPO"
}

build_image() {
  echo "Building Docker image $IMAGE_NAME"
  # Build a Docker image using devcontainer CLI
  if [ -z "$DEVCONTAINER_JSON" ]; then
    devcontainer build --workspace-folder . --image-name "$IMAGE_NAME"
  else
    devcontainer build --workspace-folder . --image-name "$IMAGE_NAME" --config "$DEVCONTAINER_JSON"
  fi
  echo "Docker image $IMAGE_NAME created successfully"
}

upload_ghcr() {
  echo "Uploading Docker image $IMAGE_NAME to GHCR"
  # Login to GitHub Container Registry
  echo "$GH_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin

  # Tag the Docker image for GHCR
  docker tag "$IMAGE_NAME" "ghcr.io/$LOWER_GITHUB_REPO/$IMAGE_NAME:latest"

  # Push the Docker image to GHCR
  docker push "ghcr.io/$LOWER_GITHUB_REPO/$IMAGE_NAME:latest"

  # Delete local Docker image
  docker rmi "$IMAGE_NAME"
  echo "Successfully uploaded Docker image $IMAGE_NAME to GHCR"
}

build_and_upload_apptainer() {
  echo "Building Apptainer image $SIF_FILE"
  if [ "$UPLOAD_DOCKER" = true ]; then
    build_apptainer_ghcr
  else
    build_apptainer_local
  fi
  echo "Successfully built Apptainer image $SIF_FILE"
  upload_apptainer_release
}

build_apptainer_ghcr() {
  echo "Building apptainer image using GHCR"
  local github_repo="${GITHUB_REPO,,}"
  # Authenticate with GHCR for apptainer
  echo "$GH_TOKEN" | apptainer registry login -u "$GITHUB_USERNAME" --password-stdin docker://ghcr.io
  # Build the Apptainer image from the private Docker image
  apptainer build "$SIF_FILE" "docker://ghcr.io/$github_repo/$IMAGE_NAME:$TAG"
}

build_apptainer_local() {
  echo "Building apptainer image from local Docker image"
  apptainer build "$SIF_FILE" "docker://ghcr.io/$LOWER_GITHUB_REPO/$IMAGE_NAME:$TAG"
}

upload_apptainer_release() {
  echo "Uploading Apptainer image $SIF_FILE to GitHub release"
  # Log into gh cli with a token
  echo "$GH_TOKEN" >> /tmp/gh_token
  gh auth login --with-token < /tmp/gh_token
  rm /tmp/gh_token
  # Upload apptainer image as a release
  gh release upload "$GITHUB_USER/$GITHUB_REPO" "$SIF_FILE"
  # Delete apptainer image locally
  rm "$SIF_FILE"
  echo "Successfully uploaded Apptainer image $SIF_FILE to GitHub release"
}

# Step 1: Clone the GitHub repository
clone_repo 
ORIG_DIR="$(pwd)"
cd "$TMP_DIR"

# Step 2: Build the Docker image using devcontainer CLI
build_image

# Step 3: Upload to GHCR (optional)
if [ "$UPLOAD_DOCKER" = true ]; then
  upload_ghcr
fi

# Step 4: Build the Apptainer image (optional)
if [ "$UPLOAD_APPTAINER" = true ]; then
  build_and_upload_apptainer
fi

# Step 5: Navigate back to the original directory
cd "$ORIG_DIR"
EOF

chmod +x "$path_container_build_and_share"

echo "container-build-and-share command installed successfully."