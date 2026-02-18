
# Install Apptainer (apptainer)

Installs Apptainer, a container system widely used in High Performance Computing (HPC) environments.

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/apptainer:1": {
        "timezone": "Europe/London"
    }
}
```

## Options

| Option | Description | Type | Default |
|---|---|---|---|
| timezone | Timezone to configure in the container (e.g. "UTC", "Europe/London"). Required for proper Apptainer mounting behavior. | string | "UTC" |

## Notes

- This feature adds the `ppa:apptainer/ppa` repository.
- It configures `tzdata` because Apptainer containers often inherit the host's `/etc/localtime`, which can cause issues if the file is missing or invalid in the container.

---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/apptainer/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
