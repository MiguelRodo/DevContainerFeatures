
# Container Build and Share (container)

Installs the container-build-and-share command for building and sharing Docker and Apptainer images.

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/container:0": {}
}
```



### Notes on `container-build-and-share.sh`

The `container-build-and-share.sh` script is a versatile command-line utility designed to simplify the process of building Docker images from a GitHub repository and optionally uploading them to the GitHub Container Registry (GHCR) or creating an Apptainer (formerly Singularity) image. 

#### Usage Overview

The script provides a variety of options, making it flexible for different workflows:

- **Default Behavior**: By default, the script will clone the specified GitHub repository, build a Docker image based on the `devcontainer.json` file within the repository, and upload both the Docker image to GHCR and an Apptainer image to a GitHub release.

- **Opt-Out Flags**: Users can specify flags to opt-out of uploading either the Docker image or the Apptainer image:
  - `-a`: Use this flag if you **do not** want to upload the Apptainer image as a GitHub release.
  - `-d`: Use this flag if you **do not** want to upload the Docker image to GHCR.

- **Other Options**: The script also allows you to specify the GitHub repository, user, branch, image name, tag, and the path to the `devcontainer.json` file.

#### Detailed Usage

Here’s a breakdown of the available options:

- `-r <github_repo>`: The GitHub repository to clone. If not provided, the script defaults to the basename of the current directory.
- `-b <branch>`: The branch to clone from the GitHub repository. If not provided, the default branch is cloned.
- `-u <github_user>`: The GitHub username or organization. Defaults to the `GITHUB_USERNAME` environment variable.
- `-c <devcontainer.json path>`: The path to the `devcontainer.json` file within the cloned repository. If not provided, it defaults to the `devcontainer build` command’s default.
- `-i <image_name>`: The name of the image to be built. If not provided, it defaults to the basename of the current directory, converted to lowercase.
- `-t <tag>`: The tag to apply to the Docker image. Defaults to `latest`.
- `-a`: Opt-out of uploading the Apptainer image.
- `-d`: Opt-out of uploading the Docker image.
- `-h`: Display the help message.

#### Example Commands

To build and upload both Docker and Apptainer images (default behavior):

```bash
container-build-and-share.sh -r my-repo -u my-user
```

To build but not upload the Apptainer image:

```bash
container-build-and-share.sh -r my-repo -u my-user -a
```

To build but not upload the Docker image:

```bash
container-build-and-share.sh -r my-repo -u my-user -d
```

#### Important Notes

- Ensure that the `GH_TOKEN` environment variable is set with a GitHub token that has the necessary permissions to clone the repository, push to GHCR, and create releases.
- The `GITHUB_USER` environment variable should be set to the GitHub username or organization associated with the repository.
- This script automates the process of building and sharing container images, streamlining your CI/CD workflow and making it easier to manage containerized environments.



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/container/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
