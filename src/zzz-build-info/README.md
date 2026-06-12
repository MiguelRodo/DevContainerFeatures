
# Container Metadata Injector (zzz-build-info)

Bakes build-time release version and date metadata from GHA directly into a system-wide command.

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/zzz-build-info:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | The automated version number injected from the runner host environment. | string | development |
| buildDate | The build timestamp injected from the runner host environment. | string | unknown |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/zzz-build-info/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
