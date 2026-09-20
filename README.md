# Dev Container Features

A collection of reusable Dev Container Features for development tools and workflows.

## Features

The catalogue below is generated from `src/<feature>/devcontainer-feature.json`, which is the source of truth for feature names, descriptions, options and lifecycle metadata.

<!-- BEGIN GENERATED FEATURE CATALOGUE -->
| Feature | Status | Description |
|---------|--------|-------------|
| [`apptainer`](docs/features/apptainer.qmd) | Current | Install Apptainer, a container system for HPC |
| [`build-info`](docs/features/build-info.qmd) | Current | Bakes build-time release version and date metadata directly into a system-wide command. |
| [`cmdstan`](docs/features/cmdstan.qmd) | Current | Installs CmdStan (the Stan probabilistic programming system command-line interface) from the official GitHub release, compiles it during image build, and configures the CMDSTAN environment variable system-wide so the installation survives container rebuilds. |
| [`fit-sne`](docs/features/fit-sne.qmd) | Current | Installs FIt-SNE (Fast Interpolation-based t-SNE) by compiling from source. |
| [`github-tokens`](docs/features/github-tokens.qmd) | Current | Manage GitHub authentication tokens (GITHUB_PAT, GITHUB_TOKEN) on each shell startup |
| [`mermaid`](docs/features/mermaid.qmd) | Current | Installs Mermaid CLI to generate diagrams. Sets up a non-root user and Puppeteer configuration. |
| [`renv-cache`](docs/features/renv-cache.qmd) | Current | Configure R with renv cache |
| [`repos`](docs/features/repos.qmd) | Deprecated | (DEPRECATED: Use the 'utils' feature instead) Installs the 'repos' CLI tool to manage multiple Git repositories. Optionally runs 'repos clone' when the container starts to clone repositories defined in repos.list. |
| [`utils`](docs/features/utils.qmd) | Current | Installs Miguel Rodo's utilities like 'repos' and 'setupmjr'. |
<!-- END GENERATED FEATURE CATALOGUE -->

`repos` is retained for backwards compatibility. New configurations should use [`utils`](docs/features/utils.qmd).

## Usage

Add a feature to your `devcontainer.json` using its GHCR identifier:

```json
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/<feature-name>:1": {}
  }
}
```

See the linked feature page for usage notes and options. The canonical option names and defaults live in each feature's `src/<feature>/devcontainer-feature.json`.

## Keeping documentation in sync

Regenerate the catalogue after feature metadata changes:

```bash
python3 scripts/docs_catalogue.py
```

CI runs the same script with `--check` and also verifies that Quarto navigation and feature option tables match metadata.

## Development

Run tests for all features:

```bash
devcontainer features test --global-scenarios-only .
```

## Publishing

Publishing is manual through `.github/workflows/release.yaml` from `main`. Features are published to:

```text
ghcr.io/MiguelRodo/DevContainerFeatures/<feature-name>
```

## License

See [LICENSE](LICENSE) for details.
