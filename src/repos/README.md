
# Repos - Multi-Repository Management (repos)

Installs the 'repos' CLI tool to manage multiple Git repositories. By default, it automatically runs 'repos' when the container starts to clone repositories defined in repos.list.

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/repos:2": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| runOnStart | Automatically run 'repos' when the container starts. | boolean | true |

## Overview

The **Repos DevContainer Feature** installs the `repos` CLI tool from the `apt-miguelrodo` APT repository. This tool automates the management of multiple Git repositories in your development environment.

By default, the feature automatically runs `repos` when the container starts, which clones and sets up repositories defined in a `repos.list` file.

## Installation

The feature installs the `repos` package from the `apt-miguelrodo` APT repository. The package is automatically configured and ready to use.

### APT Repository Details

- **Repository URL**: `https://raw.githubusercontent.com/MiguelRodo/apt-miguelrodo/main/`
- **Package**: `repos`

## Configuration

### runOnStart Option

By default, the feature runs `repos` automatically when the container starts. You can disable this behavior by setting `runOnStart` to `false`:

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/repos:2": {
        "runOnStart": false
    }
}
```

When `runOnStart` is set to `false`, the `repos` command will not execute automatically, but you can still run it manually when needed.

## Usage

### Automatic Mode (Default)

When `runOnStart` is `true` (the default), the `repos` tool automatically executes when the container starts. Create a `repos.list` file in your project to define which repositories to clone.

### Manual Mode

When `runOnStart` is `false`, you can manually run the `repos` command at any time:

```bash
repos
```

### The repos Command

The `repos` command is provided by the installed package. Refer to the `repos` tool documentation for details on:

- Creating and managing `repos.list` files
- Repository formats and syntax
- Advanced configuration options

## Notes

- The `repos` binary is installed system-wide and available in the PATH
- The feature creates a post-start script at `/usr/local/bin/repos-post-start` that controls automatic execution
- For detailed `repos` usage and configuration, refer to the repos tool documentation

## Migration from Version 1.x

If you're upgrading from version 1.x of this feature:

- The manual script implementation has been replaced with a system package
- Old scripts like `repos-git-clone`, `repos-workspace-add`, etc., are no longer provided
- The new `repos` binary provides all necessary functionality
- The `runOnStart` option replaces the previous automatic execution behavior

---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/repos/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
