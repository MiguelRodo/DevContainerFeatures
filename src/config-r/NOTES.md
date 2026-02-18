## Package Restoration

This feature uses [`renvvv::renvvv_restore()`](https://github.com/MiguelRodo/renvvv) for package restoration instead of the default `renv::restore()`. This provides more robust restoration logic that:

- Continues past individual package failures
- Retries failed packages individually  
- Reports what couldn't be installed
- Handles GitHub, CRAN, and Bioconductor packages
- Provides better error recovery

The `renvvv` package is automatically installed during feature setup.

## Acknowledgments

This project incorporates code from [AwesomeProject](https://github.com/rocker-org/devcontainer-features), which is licensed under the MIT License.
