# Dev Container Features

We provide several devcontainer features.

## Description

This repository contains a _collection_ of several Features - `git-xet`, `repos`, `config-r` and `apptainer`.
Each sub-section below shows a sample `devcontainer.json` alongside example usage of the Feature.

### `git-xet`

Install Git Xet CLI (see [here](https://xethub.com/assets/docs/getting-started/install)).

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/MiguelRodo/DevContainerFeatures/git-xet": {}
    }
}
```

To log in to XetHub, you'll need to run the following command:

```bash
git xet login -u <xethub-username> -e <xethub-email> -p <xethub-pat> 
```

The above command, with an auto-generated PAT, can be obtaind [here](https://xethub.com/user/settings/pat).


### Install Apptainer

Install Apptainer.

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/MiguelRodo/DevContainerFeatures/apptainer": {}
    }
}
```

### Work with multiple repositories

Provides features to work with multiple repositories.

```jsonc
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/repos": {}
}
```


#### Clone GitHub repositories

Adds the command `repos-clone-github` to clone all repositories listed in `repos-to-clone.list`.

This command is run each time the container starts.

#### Clone XetHub repositories

Adds the command `repos-clone-xethub` to clone all repositories listed in `repos-to-clone-xethub.list`.
These repositories are lazily cloned.

This command is also run each time the container starts.
If `git-xet` is not installed, then it's not run.

#### Create `EntireProject.code-workspace` file

All repositories listed in `repos-to-clone.list` and `repos-to-clone-xethub.list` are added to the `EntireProject.code-workspace` file.

### Configure R for use in VS Code

Sets up `R` for use in VS Code.

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/config-r: {}
}
```

#### Configure GitHub tokens, R libraries and radian

Adds `config-r` command, which:

- Ensures that the environment variables `GH_TOKEN`, `GITHUB_TOKEN`, and `GITHUB_PAT` are all set for GitHub API access.
- Ensures that the Radian R console works correctly in GitPod or Codespace by setting the `radian.editing_mode` and `radian.auto_match` options.
- Configures the standard and `renv` libraries.
- Configures the linting settings for R code by creating a `.lintr` file in the home directory if it doesn't exist, and setting the linter to ignore warnings about object length and snake/camel case.

The command `config-r` is set to be run via `.bashrc`.

#### Configure VS Code settings for `R`

This script configures R settings in Visual Studio Code for GitPod or Codespace environments. It sets the r.libPaths setting to the default .libPaths() output, creates or updates a JSON file with VS Code settings, and ensures the correct R version is used. This prevents warnings about missing R packages that the VS Code extensions depend on.

It adds the `config-r-vscode` command to the path, which is run each time the container starts.

#### Update typically-used R pacakges

This script is used to ensure that key Visual Studio Code packages for R are up-to-date. It navigates to the home directory, disables the pak package (a fast, light-weight package management system for R), and installs or updates the jsonlite, languageserver, pak, and renv packages.

It adds `config-r-pkg` to the the path, which is run each time the container starts.
