
# CmdStan (cmdstan)

Installs CmdStan (the Stan probabilistic programming system command-line interface) from the official GitHub release, compiles it during image build, and configures the CMDSTAN environment variable system-wide so the installation survives container rebuilds.

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/cmdstan:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | CmdStan version to install (e.g. '2.36.0'). Use 'latest' to always pull the newest release. | string | 2.36.0 |
| installDir | Base directory under which the versioned CmdStan folder is created (e.g. /opt/cmdstan/cmdstan-2.36.0). | string | /opt/cmdstan |
| installRPackage | When true and R is present in the image, install the 'cmdstanr' R package and configure it to use the system CmdStan installation. | boolean | true |
| installPythonPackage | When true and Python/pip is present in the image, install the 'cmdstanpy' Python package and configure it to use the system CmdStan installation. | boolean | true |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/cmdstan/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
