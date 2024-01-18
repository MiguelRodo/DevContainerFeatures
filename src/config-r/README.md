
# Configure R for use in VS Code

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/config-r: {}
}
```

## Configure GitHub tokens, R libraries and radian

Adds `config-r` command, which:

- Ensures that the environment variables `GH_TOKEN`, `GITHUB_TOKEN`, and `GITHUB_PAT` are all set for GitHub API access. 
- Ensures that the Radian R console works correctly in GitPod or Codespace by setting the `radian.editing_mode` and `radian.auto_match` options.
- Configures the standard and `renv` libraries.
- Configures the linting settings for R code by creating a `.lintr` file in the home directory if it doesn't exist, and setting the linter to ignore warnings about object length and snake/camel case.

The command `config-r` is set to be run via `.bashrc`.

## Configure VS Code settings for `R`

This script configures R settings in Visual Studio Code for GitPod or Codespace environments. It sets the r.libPaths setting to the default .libPaths() output, creates or updates a JSON file with VS Code settings, and ensures the correct R version is used. This prevents warnings about missing R packages that the VS Code extensions depend on.

It adds the `config-r-vscode` command to the path, which is run each time the container starts.

## Update typically-used R pacakges

This script is used to ensure that key Visual Studio Code packages for R are up-to-date. It navigates to the home directory, disables the pak package (a fast, light-weight package management system for R), and installs or updates the jsonlite, languageserver, pak, and renv packages.

It adds `config-r-pkg` to the the path, which is run each time the container starts.
