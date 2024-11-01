
# Configure R (config-r)

Configure R

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/config-r:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| set_r_lib_paths | Whether to set default paths for R libraries (including for `renv`) to avoid needing to reinstall upon codespace rebuild. | string | true |
| radian_auto_match | Whether to set `auto_match` to `FALSE` for the radian terminal. | string | true |
| lighten_linting | Whether to stop checking for camel/snake case and object name length. | string | true |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/config-r/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
