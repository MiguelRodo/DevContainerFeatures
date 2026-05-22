
# MiguelRodo Utils (utils)

Installs Miguel Rodo's utilities like 'repos' and 'setupmjr'.

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/utils:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| installRepos | Install the 'repos' utility. | boolean | true |
| installSetupmjr | Install the 'setupmjr' utility. | boolean | true |
| runOnStart | Automatically run 'repos clone' when the container starts (only applies if installRepos is true). | boolean | false |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
