
# Container Metadata Injector (zzz-build-info)

Bakes build-time release version and date metadata directly into a system-wide command.

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/zzz-build-info:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| imageVersion | The automated version number injected from the runner host environment. Valid formats include 1, v1.2, 1.2.3.4, v2.0-12. | string | - |
| buildDate | If left empty, automatically sets to the current date and time formatted as an ISO 8601 UTC timestamp. | string | - |

## Providing build info within the container image

This provides the command `/usr/local/bin/container-info` inside the container, which outputs the build details in this format:

```text
--------------------------------------------------
🚀 DevContainer Release Information
--------------------------------------------------
Version: v1.2.3
Built On: 2026-06-12T14:36:22Z
--------------------------------------------------
```

The version and build date are those specified by the feature options.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/zzz-build-info/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
