
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
| installPakAndBiocManager | Whether to install `pak` and `BiocManager` (into `renv` cache and out). Default is true. | boolean | true |
| restoreRenv | Whether to restore renv packages if renv.lock file is detected. | boolean | true |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/config-r/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
