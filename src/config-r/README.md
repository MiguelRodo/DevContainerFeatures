
# Configure R (config-r)

Configure R

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/config-r:2": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| setRLibPaths | Whether to set default paths for R libraries (including for `renv`) to avoid needing to reinstall upon codespace rebuild. | boolean | true |
| ensureGitHubPatSet | If true and GITHUB_PAT is not set, will first try set it from GH_TOKEN and then GITHUB_TOKEN. | boolean | true |
| restore | Whether to run `renv::restore()`. Default is true. | boolean | true |
| renvDir | Path to the directory containing subdirectories with `renv.lock` files. Defaults to `/usr/local/share/config-r/renv` if the environment variable is not set. | string | /usr/local/share/config-r/renv |
| pkgExclude | Comma-separated list of packages to exclude from the renv snapshot restore process. | string | - |
| usePak | Whether to use `pak` for package installation. | boolean | false |
| debug | Whether to print debug information during package restore. | boolean | false |

## Acknowledgments

This project incorporates code from [AwesomeProject](https://github.com/rocker-org/devcontainer-features), which is licensed under the MIT License.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/config-r/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
