
# Add commands to work with repos (repos)

Add commands to work with multiple repos

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/repos:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| authGitconfig | Whether to set up .gitconfig as the system default for authentication. Default is auto, in which case it is only done if in a GitHub Codespace. | string | auto |
| installHuggingface | Whether to install the Hugging Face CLI. Default is true. | boolean | true |
| huggingfaceInstallScope | Whether to install the Hugging Face CLI system-wide or just for the current user. Default is user. | string | system |

# TL;DR

The **Repos DevContainer Feature** automates the process of working with multiple repositories in your development environment. By default, it clones repositories specified in a `repos-to-clone.list` file and sets up your workspace accordingly. It also provides scripts and commands to set up Git authentication for GitHub and Hugging Face, install necessary tools like Hugging Face CLI and Git LFS, and manage VSCode workspaces automatically.

## Introduction

Managing multiple repositories can be challenging, especially when dealing with authentication, cloning, and workspace configuration. The Repos DevContainer Feature streamlines this process by automating:

- Cloning multiple repositories from a list.
- Setting up Git authentication for GitHub and Hugging Face.
- Installing Hugging Face CLI and Git LFS.
- Automatically adding repositories to a VSCode workspace.

## Key Features

### Automatic Repository Cloning

- **Immediate Setup**: By default, the feature automatically clones all repositories specified in the `repos-to-clone.list` file upon creating or starting the devcontainer.
- **Commands Used**:
  - `repos-workspace-add`: Adds repositories to the VSCode workspace.
  - `repos-git-clone`: Clones the repositories into the parent directory.

### Git Authentication

- **Automatic Configuration**: Sets up Git credential helpers for GitHub and Hugging Face by modifying the system `gitconfig`. This allows Git to use custom credential helpers that securely provide authentication tokens when interacting with repositories, without storing passwords in plain text.
  - **System Credential Manager**: Leverages the system credential manager to avoid storing sensitive information in configuration files.
- **Environment Variables**: Authentication tokens are sourced from environment variables to ensure secure access:
  - **GitHub**:
    - Defaults to `GH_TOKEN`. If not set, falls back to `GITHUB_TOKEN`.
  - **Hugging Face**:
    - Defaults to `HF_TOKEN`. If not set, falls back to `HUGGINGFACE_TOKEN`.

### Cloning Multiple Repositories

- **Batch Cloning**: The `repos-git-clone` script reads a list of repositories from a specified file (defaulting to `repos-to-clone.list`) and clones them into the parent directory of your devcontainer. This simplifies the process of setting up multiple projects or datasets at once.
- **Flexible Formats**: Supports various repository formats to accommodate different hosting services:
  - **GitHub Repositories**: `owner/repo` or `owner/repo@branch`.
  - **Hugging Face Datasets**: `datasets/owner/repo` or `datasets/owner/repo@branch`.
  - **Full URLs**: `https://host/owner/repo` or `https://host/owner/repo@branch`.
- **Branch Selection**: You can specify a branch or tag to clone by appending `@branch` to the repository identifier:
  - Example: `owner/repo@develop` will clone the `develop` branch of the repository.

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
- **Effect**: These commands ensure that the repositories specified in `repos-to-clone.list` are cloned and added to your VSCode workspace automatically.

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

Create a `repos-to-clone.list` file in your devcontainer:

```bash
# Example repositories
owner1/repo1
owner2/repo2@develop
datasets/owner3/dataset1
https://gitlab.com/owner4/repo4@feature-branch
```

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

- **Cloning Repositories**: The feature clones the specified repositories into the parent directory of your devcontainer upon creation or start.
- **Git Authentication**: Sets up Git credential helpers for seamless authentication with GitHub and Hugging Face.
- **Tool Installation**: Installs Hugging Face CLI and Git LFS if specified.
- **Workspace Configuration**: Adds the repositories to a VSCode workspace file for easy access.

## Commands Provided

### `repos-git-clone`

Clones repositories listed in a specified file into the parent directory.

**Usage:**

```bash
repos-git-clone [-f|--file <file>]
```

**Options:**

- `-f, --file <file>`: Specify the repository list file. Defaults to `repos-to-clone.list`.

### `repos-workspace-add`

Adds cloned repositories to a VSCode workspace file.

**Usage:**

```bash
repos-workspace-add [-f|--file <file>]
```

**Options:**

- `-f, --file <file>`: Specify the repository list file. Defaults to `repos-to-clone.list`.

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

### Git Authentication

- **Automatic Configuration**: The feature sets up Git credential helpers for GitHub and Hugging Face by modifying the system `gitconfig`. This allows Git to securely provide authentication tokens during operations without storing passwords in plain text.
  - **System Credential Manager**: Utilizes the system credential manager to avoid exposing sensitive information.
- **Environment Variables**: Authentication tokens are sourced from environment variables:
  - **GitHub**:
    - Primary: `GH_TOKEN`
    - Fallback: `GITHUB_TOKEN`
  - **Hugging Face**:
    - Primary: `HF_TOKEN`
    - Fallback: `HUGGINGFACE_TOKEN`

### Cloning Multiple Repositories

- **Batch Cloning**: Automatically clones repositories listed in `repos-to-clone.list`.
- **Flexible Formats**: Supports different formats and hosts:
  - **GitHub**: `owner/repo`, `owner/repo@branch`
  - **Hugging Face Datasets**: `datasets/owner/repo`, `datasets/owner/repo@branch`
  - **Full URLs**: Including branches using `@branch`
- **Branch Selection**: Clone specific branches or tags as needed.

## Detailed Scripts Explanation

### `install.sh`

The main script that orchestrates the installation and setup:

- **Script Sourcing**: Includes other scripts that perform specific tasks.
- **Conditional Execution**: Runs installation and configuration based on provided options (`installHuggingface`, `authGitconfig`, `huggingfaceInstallScope`).

### `repos-hf-install`

Installs Hugging Face CLI and Git LFS:

- **Scope Selection**: Installs Hugging Face CLI either system-wide or for the current user based on the `--hf-scope` option.
- **Default Scope**: The default installation scope for Hugging Face CLI is `system`.
- **Dependency Handling**: Ensures Python and pip are available.
- **Git LFS Installation**: Installs Git LFS system-wide and configures it for the current user.

### `repos-git-auth-gitconfig`

Configures Git credential helpers:

- **Credential Helper Setup**: Modifies the system `gitconfig` to use custom credential helpers for GitHub and Hugging Face.
- **Token Usage**: Uses environment variables for tokens to authenticate Git operations.

### `repos-git-clone`

Clones repositories from a list:

- **Repository Parsing**: Supports different repository formats and hosts.
- **Branch Handling**: Clones specific branches if specified.
- **Directory Management**: Clones into the parent directory to keep the workspace organized.

### `repos-workspace-add`

Adds repositories to a VSCode workspace file:

- **Workspace File Detection**: Checks for the existence of `EntireProject.code-workspace` and creates it if necessary.
- **JSON Manipulation**: Uses `jq` to update the workspace file with new folders.
- **Automation**: Simplifies the process of managing multiple projects in VSCode.

## Environment Variables

Ensure the following environment variables are set for authentication:

- **GitHub**:
  - `GH_TOKEN` or `GITHUB_TOKEN` (`GH_TOKEN` takes precedence).
- **Hugging Face**:
  - `HF_TOKEN` or `HUGGINGFACE_TOKEN` (`HF_TOKEN` takes precedence).

## Notes

- **Repository Directory**: Repositories are cloned into the parent directory.
- **Repository List File**: The `repos-to-clone.list` file supports comments (lines starting with `#`) and ignores empty lines.
- **Environment Suitability**: The feature is particularly useful in Codespaces or similar development environments.

---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/repos/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
