## Package Restoration

This feature uses [`renvvv::renvvv_restore()`](https://github.com/MiguelRodo/renvvv) for package restoration instead of the default `renv::restore()`. This provides more robust restoration logic that:

- Continues past individual package failures
- Retries failed packages individually  
- Reports what couldn't be installed
- Handles GitHub, CRAN, and Bioconductor packages
- Provides better error recovery
- Supports skipping specific packages via the `pkgExclude` option

The `renvvv` package is automatically installed during feature setup.

### Skipping Packages

You can exclude specific packages from being restored by using the `pkgExclude` option with a comma-separated list of package names:

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/config-r:2": {
        "pkgExclude": "package1,package2,package3"
    }
}
```

This is useful when:
- Certain packages fail to install in your environment
- You want to manually manage specific package versions
- Some packages are not needed for your workflow

## Acknowledgments

This project incorporates code from [AwesomeProject](https://github.com/rocker-org/devcontainer-features), which is licensed under the MIT License.
