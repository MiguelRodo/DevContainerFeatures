# Dev Container Features

A collection of reusable DevContainer Features for various development tools and workflows.

## Features

This repository contains the following DevContainer Features:

- **[apptainer](#apptainer)** - Install Apptainer for HPC containerization
- **[cmdstan](#cmdstan)** - Install CmdStan (Stan probabilistic programming system)
- **[renv-cache](#renv-cache)** - Configure R with renv cache
- **[fit-sne](#fit-sne)** - Install FIt-SNE for dimensionality reduction
- **[mermaid](#mermaid)** - Install Mermaid CLI for diagram generation
- **[repos](#repos)** - Manage multiple Git repositories

## Usage

Each feature can be added to your `devcontainer.json` file. See the sections below for specific usage examples and options.

---

## apptainer

Installs [Apptainer](https://apptainer.org/), a container system widely used in High Performance Computing (HPC) environments.

### Example

```json
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/MiguelRodo/DevContainerFeatures/apptainer:1": {
            "timezone": "UTC"
        }
    }
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `timezone` | string | `"UTC"` | Timezone to configure in the container (e.g., "UTC", "Europe/London"). Required for proper Apptainer mounting behavior. |

### Notes

- Adds the `ppa:apptainer/ppa` repository
- Configures `tzdata` because Apptainer containers often inherit the host's `/etc/localtime`

---

## cmdstan

Installs [CmdStan](https://mc-stan.org/users/interfaces/cmdstan), the command-line interface to [Stan](https://mc-stan.org/) – a state-of-the-art platform for Bayesian probabilistic programming and statistical inference.

The feature downloads the official CmdStan release tarball, pre-compiles the Stan C++ toolchain during the image build, and configures the `CMDSTAN` environment variable system-wide so that the installation **survives container rebuilds**.

### Example

```json
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/MiguelRodo/DevContainerFeatures/cmdstan:1": {
            "version": "latest"
        }
    }
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `version` | string | `"latest"` | CmdStan version to install (e.g. `"2.36.0"`). Use `"latest"` to always pull the newest release. |
| `installDir` | string | `"/opt/cmdstan"` | Base directory under which the versioned CmdStan folder is created. |
| `installRPackage` | boolean | `true` | When `true` and R is present, install the `cmdstanr` R package and configure it to use the system CmdStan installation. |

### Notes

- Installs CmdStan to a system-wide path (not a user home directory) so the installation survives rebuilds
- Pre-compiles the Stan C++ toolchain during the image build (`make build`)
- Sets `CMDSTAN` and updates `PATH` via `/etc/profile.d/cmdstan.sh` and `/etc/environment`
- Compilation may take 3–10 minutes depending on available CPU cores

---

## renv-cache

Configures R for development in VS Code, including library paths, GitHub tokens, and package restoration with renv cache.

### Example

```json
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/MiguelRodo/DevContainerFeatures/renv-cache:2": {
            "setRLibPaths": true,
            "restore": true
        }
    }
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `setRLibPaths` | boolean | `true` | Set default paths for R libraries (including for `renv`) to avoid reinstalling upon rebuild |
| `ensureGitHubPatSet` | boolean | `true` | If GITHUB_PAT is not set, attempt to set it from GH_TOKEN or GITHUB_TOKEN |
| `restore` | boolean | `true` | Whether to run package restoration using `renvvv::renvvv_restore()` |
| `update` | boolean | `false` | Whether to run package update using `renvvv::renvvv_update()`. If both restore and update are true, `renvvv::renvvv_restore_and_update()` is used |
| `renvDir` | string | `"/usr/local/share/renv-cache/renv"` | Path to directory containing subdirectories with `renv.lock` files |
| `pkgExclude` | string | `""` | Comma-separated list of packages to exclude from renv snapshot restore |
| `usePak` | boolean | `false` | Whether to use `pak` for package installation |
| `debug` | boolean | `false` | Print debug information during package restore |
| `debugRenv` | boolean | `false` | Print debug information during renv restore |

### Notes

- Runs automatically via `postCreateCommand`
- Sets up GitHub tokens for API access
- Configures R library paths and renv settings

---

## fit-sne

Installs [FIt-SNE](https://github.com/KlugerLab/FIt-SNE) (Fast Interpolation-based t-SNE) by compiling it from source along with the required FFTW 3.3.10 library.

### Example

```json
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/MiguelRodo/DevContainerFeatures/fit-sne:1": {
            "version": "1.2.1"
        }
    }
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `version` | string | `"latest"` | FIt-SNE version tag or commit SHA to install. Use "latest" for the default branch. |

### Notes

- Compiles from source, so installation may take a few minutes
- Installs required dependencies: `build-essential`, `wget`, `git`

---

## mermaid

Installs [Mermaid CLI](https://github.com/mermaid-js/mermaid-cli) to generate diagrams from `.mmd` files. Sets up a non-root user and Puppeteer configuration for headless rendering.

### Example

```json
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/MiguelRodo/DevContainerFeatures/mermaid:1": {
            "userName": "mermaiduser",
            "nodeVersion": "lts"
        }
    }
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `userName` | string | `"mermaiduser"` | Username under which Mermaid CLI will run |
| `puppeteerConfigDir` | string | `"/usr/local/share/mermaid-config"` | Directory to store Puppeteer configuration files |
| `nodeVersion` | string | `"lts"` | Node.js version to install if not present (e.g., "lts", "20", "18") |

### Notes

- Requires Node.js (will install if missing)
- Installs system dependencies required for Puppeteer

---

## repos

Installs the `repos` CLI tool to manage multiple Git repositories. Automatically clones repositories defined in `repos.list` when the container starts.

### Example

```json
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/MiguelRodo/DevContainerFeatures/repos:3": {
            "runOnStart": true
        }
    }
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `runOnStart` | boolean | `true` | Automatically run 'repos' when the container starts |

### Usage

When `runOnStart` is `true`, the `repos` tool automatically executes on container start. Create a `repos.list` file in your project to define which repositories to clone.

To run manually:

```bash
repos
```

### Notes

- Installs from the `apt-miguelrodo` APT repository
- Creates a post-start script at `/usr/local/bin/repos-post-start`
- For detailed usage, refer to the repos tool documentation

---

## Development

### Testing

Run tests for all features:

```bash
devcontainer features test --global-scenarios-only .
```

### Publishing

Features are automatically published to GitHub Container Registry (GHCR) via GitHub Actions on release. They are available at:

```
ghcr.io/MiguelRodo/DevContainerFeatures/<feature-name>
```

## License

See [LICENSE](LICENSE) file for details.
