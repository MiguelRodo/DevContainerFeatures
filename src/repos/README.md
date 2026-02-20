
# Automatically set up multi-repo projects (repos)

Installs the 'repos' CLI tool to manage multiple Git repositories. Optionally runs 'repos setup' when the container starts to clone repositories defined in repos.list.

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/repos:2": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| runOnStart | Automatically run 'repos setup' when the container starts. | boolean | false |

# TL;DR

The **Repos DevContainer Feature** automates the process of working with multiple repositories in your development environment. By default, it clones repositories specified in a `repos.list` file and sets up your workspace accordingly. It also provides scripts and commands to set up Git authentication for GitHub and Hugging Face, install necessary tools like Hugging Face CLI and Git LFS, and manage VSCode workspaces automatically.

## Introduction

Managing multiple repositories can be challenging, especially when dealing with authentication, cloning, and workspace configuration. The Repos DevContainer Feature streamlines this process by automating:

- Cloning multiple repositories from a list.
- Setting up Git authentication for GitHub and Hugging Face.
- Installing Hugging Face CLI and Git LFS.
- Automatically adding repositories to a VSCode workspace.

## Key Features

### Automatic Repository Cloning

- **Immediate Setup**: When `runOnStart` is set to `true`, the feature automatically clones all repositories specified in the `repos.list` file upon creating or starting the devcontainer. By default, this is disabled.
- **Custom Clone Locations**: You can specify exactly where each repository should be cloned by providing a target directory for each entry in your `repos.list` file.
- **Commands Used**:
  - `repos-workspace-add`: Adds repositories to the VSCode workspace.
  - `repos-git-clone`: Clones the repositories into specified directories.

### Git Authentication

- **Automatic Configuration**: Sets up Git credential helpers for GitHub and Hugging Face by modifying the system `gitconfig`. This allows Git to use custom credential helpers that securely provide authentication tokens when interacting with repositories, without storing passwords in plain text.
  - **System Credential Manager**: Leverages the system credential manager to avoid storing sensitive information in configuration files.
- **Environment Variables**: Authentication tokens are sourced from environment variables to ensure secure access:
  - **GitHub**:
    - Defaults to `GH_TOKEN`. If not set, falls back to `GITHUB_TOKEN`.
  - **Hugging Face**:
    - Defaults to `HF_TOKEN`. If not set, falls back to `HUGGINGFACE_TOKEN`.

### Cloning Multiple Repositories

- **Batch Cloning**: The `repos-git-clone` script reads a list of repositories from a specified file (defaulting to `repos.list`) and clones them into specified directories. This simplifies the process of setting up multiple projects or datasets at once.
- **Flexible Formats**: Supports various repository formats to accommodate different hosting services:
  - **GitHub Repositories**: `owner/repo` or `owner/repo@branch`.
  - **Hugging Face Datasets**: `datasets/owner/repo` or `datasets/owner/repo@branch`.
  - **Full URLs**: `https://host/owner/repo` or `https://host/owner/repo@branch`.
- **Branch Selection**: You can specify a branch or tag to clone by appending `@branch` to the repository identifier:
  - Example: `owner/repo@develop` will clone the `develop` branch of the repository.
- **Custom Target Directories**: Specify a target directory for each repository directly in the `repos.list` file.

## Installation and Usage

### Adding the Feature to Your DevContainer

Include the feature in your `devcontainer.json`:

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/repos:1.3.0": {
        "installHuggingface": true,
        "authGitconfig": "auto",
        "huggingfaceInstallScope": "system"
    }
}
```

### Default Configuration

By default, the feature includes the following in your `devcontainer.json`:

```json
{
    "postCreateCommand": "repos-workspace-add; repos-git-clone",
    "postStartCommand": "repos-workspace-add; repos-git-clone"
}
```

- **`postCreateCommand`**: Runs after the devcontainer is created.
- **`postStartCommand`**: Runs each time the devcontainer starts.
- **Effect**: These commands ensure that the repositories specified in `repos.list` are cloned and added to your VSCode workspace automatically.

### Feature Options

- **`installHuggingface`**:
  - **Type**: Boolean
  - **Description**: Whether to install the Hugging Face CLI and Git LFS. Default is `true`.
- **`authGitconfig`**:
  - **Type**: String
  - **Enum**: `"true"`, `"false"`, `"auto"`
  - **Description**: Whether to set up `.gitconfig` as the system default for authentication. Default is `"auto"`, in which case it is only done if in a GitHub Codespace.
- **`huggingfaceInstallScope`**:
  - **Type**: String
  - **Enum**: `"system"`, `"user"`
  - **Description**: Whether to install the Hugging Face CLI system-wide or just for the current user. Default is `"system"`.

### Example Usage

#### Create a Repository List File

Create a `repos.list` file in your devcontainer:

```bash
# Example repositories
owner1/repo1
owner2/repo2@develop ./Projects/Repo2
datasets/owner3/dataset1 ../Datasets
https://gitlab.com/owner4/repo4@feature-branch ./GitLabRepos
```

- **Specifying Target Directories**: Each line can optionally include a target directory where the repository should be cloned.
  - **Format**: `repo_spec [target_directory]`
    - `repo_spec`: The repository specification (e.g., `owner/repo[@branch]`).
    - `target_directory`: Optional. The directory where you want to clone the repository.
  - **Default Target Directory**: If no target directory is specified, the repository will be cloned into the parent directory (`..`) of the devcontainer.

#### Set Up Authentication Tokens

Ensure the necessary environment variables are set for authentication:

- **GitHub**:
  - Set `GH_TOKEN` or `GITHUB_TOKEN` with your GitHub Personal Access Token.
- **Hugging Face**:
  - Set `HF_TOKEN` or `HUGGINGFACE_TOKEN` with your Hugging Face token.

##### Injecting Secrets into GitHub Codespaces

To securely inject your tokens into GitHub Codespaces:

1. **Navigate to Your Repository**: Go to your repository on GitHub.
2. **Go to Settings**: Click on the `Settings` tab.
3. **Access Secrets**: In the left sidebar, click on `Codespaces` under `Secrets and variables`.
4. **Add New Secrets**:
   - Click on `New repository secret`.
   - **For GitHub**:
     - **Name**: `GH_TOKEN` or `GITHUB_TOKEN`
     - **Value**: Your GitHub Personal Access Token.
   - **For Hugging Face**:
     - **Name**: `HF_TOKEN` or `HUGGINGFACE_TOKEN`
     - **Value**: Your Hugging Face token.
5. **Save**: Click `Add secret`.

These secrets will be automatically injected into your Codespace environment, ensuring secure authentication without exposing your tokens in the code.

#### Rebuild Your DevContainer

Rebuild or reopen your devcontainer to apply the feature:

- **VSCode Prompt**: You may be prompted to rebuild the container—accept the prompt.
- **Manual Rebuild**: Alternatively, you can trigger a rebuild via the Command Palette (`F1` or `Ctrl+Shift+P`) and selecting **Remote-Containers: Rebuild Container**.

### Feature Execution

- **Cloning Repositories**: The feature clones the specified repositories into the directories you've specified in the `repos.list` file upon creation or start.
- **Git Authentication**: Sets up Git credential helpers for seamless authentication with GitHub and Hugging Face.
- **Tool Installation**: Installs Hugging Face CLI and Git LFS if specified.
- **Workspace Configuration**: Adds the repositories to a VSCode workspace file for easy access.

## Commands Provided

### `repos-git-clone`

Clones repositories listed in a specified file into specified directories.

**Usage:**

```bash
repos-git-clone [-f|--file <file>]
```

**Options:**

- `-f, --file <file>`: Specify the repository list file. Defaults to `repos.list`.

**Repository List File Format:**

Each line in the repository list file can be in the following formats:

```bash
repo_spec [target_directory]
```

- **`repo_spec`**: The repository specification.
- **`target_directory`**: Optional. The directory where you want to clone the repository.

### `repos-workspace-add`

Adds cloned repositories to a VSCode workspace file.

**Usage:**

```bash
repos-workspace-add [-f|--file <file>]
```

**Options:**

- `-f, --file <file>`: Specify the repository list file. Defaults to `repos.list`.

### `repos-git-auth-gitconfig`

Sets up Git credential helpers for GitHub and Hugging Face.

**Usage:**

```bash
repos-git-auth-gitconfig
```

### `repos-hf-install`

Installs Hugging Face CLI and Git LFS.

**Usage:**

```bash
repos-hf-install [--hf-scope <system|user>]
```

**Options:**

- `--hf-scope`: Install scope for Hugging Face CLI (`system` or `user`). Default is `system`.

## Detailed Features

### Cloning Repositories into Specified Directories

- **Custom Target Directories**: You can specify a target directory for each repository in the `repos.list` file.
- **Default Behavior**: If no target directory is specified, repositories are cloned into the parent directory (`..`) of the devcontainer.

**Example Entry with Target Directory:**

```bash
owner2/repo2@develop ./Projects/Repo2
```

This will clone `owner2/repo2` into the `./Projects/Repo2` directory relative to your devcontainer.

### Workspace Configuration

- **Automatic Workspace Update**: The `repos-workspace-add` script will add the cloned repositories to the VSCode workspace file, respecting the target directories you've specified.
- **Relative Paths**: The paths in the workspace file are relative to the devcontainer, ensuring portability.

## Environment Variables

Ensure the following environment variables are set for authentication:

- **GitHub**:
  - `GH_TOKEN` or `GITHUB_TOKEN` (`GH_TOKEN` takes precedence).
- **Hugging Face**:
  - `HF_TOKEN` or `HUGGINGFACE_TOKEN` (`HF_TOKEN` takes precedence).

## Notes

- **Repository Directory**: You have full control over where repositories are cloned by specifying target directories.
- **Repository List File**: The `repos.list` file supports comments (lines starting with `#`) and ignores empty lines.
- **Environment Suitability**: The feature is particularly useful in Codespaces or similar development environments.

## Acknowledgments

This project incorporates code from [AwesomeProject](https://github.com/rocker-org/devcontainer-features), which is licensed under the MIT License.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/repos/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
