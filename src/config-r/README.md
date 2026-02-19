
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
| elevateGitHubToken | If true and a more permissive token (GH_TOKEN or GITHUB_PAT) is available, override GITHUB_TOKEN to match it. This helps R tools like renv that prioritize GITHUB_TOKEN over other tokens. | boolean | true |
| overrideGitHubToken | If true, force GITHUB_TOKEN to be set to either GH_TOKEN or GITHUB_PAT (in priority order), regardless of existing value. Use only if you always want to override GITHUB_TOKEN. | boolean | false |
| restore | Whether to run package restoration using `renvvv::renvvv_restore()`. Default is true. | boolean | true |
| update | Whether to run package update using `renvvv::renvvv_update()`. If both restore and update are true, `renvvv::renvvv_restore_and_update()` is used. Default is false. | boolean | false |
| renvDir | Path to the directory containing subdirectories with `renv.lock` files. Defaults to `/usr/local/share/config-r/renv` if the environment variable is not set. | string | /usr/local/share/config-r/renv |
| pkgExclude | Comma-separated list of packages to exclude from the renv snapshot restore process. | string | - |
| usePak | Whether to use `pak` for package installation. | boolean | false |
| debug | Whether to print debug information during package restore. | boolean | false |
| debugRenv | Whether to print debug information during renv restore. | boolean | false |

## Acknowledgments

This project incorporates code from [AwesomeProject](https://github.com/rocker-org/devcontainer-features), which is licensed under the MIT License.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/config-r/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
