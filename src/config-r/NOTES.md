## Package Restoration

This feature uses [`UtilsProjrMR::projr_renv_restore()`](https://github.com/MiguelRodo/UtilsProjrMR) for package restoration instead of the default `renv::restore()`. This provides more robust restoration logic with better handling of:

- GitHub packages
- Fallback mechanisms
- Edge cases in package dependencies

The `UtilsProjrMR` package is automatically installed during feature setup.

## Acknowledgments

This project incorporates code from [AwesomeProject](https://github.com/rocker-org/devcontainer-features), which is licensed under the MIT License.
