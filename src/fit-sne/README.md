
# Install FIt-SNE (fit-sne)

Installs FIt-SNE (Fast Interpolation-based t-SNE) by compiling it from source. This feature also compiles and installs the required FFTW 3.3.10 library.

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/fit-sne:1": {
        "version": "1.2.1"
    }
}
```

## Options

| Option | Description | Type | Default |
|---|---|---|---|
| version | FIt-SNE version tag or commit SHA to install. Use "latest" for the default branch. | string | "latest" |

## Notes

- This feature compiles code from source, so installation may take a few minutes.
- It installs `build-essential`, `wget`, and `git`.




---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/fit-sne/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
