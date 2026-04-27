# Install CmdStan (cmdstan)

Installs [CmdStan](https://mc-stan.org/users/interfaces/cmdstan), the command-line interface to [Stan](https://mc-stan.org/) – a state-of-the-art platform for Bayesian probabilistic programming and statistical inference.

The feature downloads the official CmdStan release tarball, pre-compiles the Stan C++ toolchain during the image build, and configures the `CMDSTAN` environment variable system-wide so that the installation **survives container rebuilds** without requiring any per-session setup.

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/cmdstan:1": {}
}
```

With a specific version and R integration disabled:

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/cmdstan:1": {
        "version": "2.36.0",
        "installRPackage": false
    }
}
```

## Options

| Option Id | Description | Type | Default Value |
|-----------|-------------|------|---------------|
| `version` | CmdStan version to install (e.g. `"2.36.0"`). Use `"latest"` to always pull the newest release. | string | `latest` |
| `installDir` | Base directory under which the versioned CmdStan folder is created (e.g. `/opt/cmdstan/cmdstan-2.36.0`). | string | `/opt/cmdstan` |
| `installRPackage` | When `true` and R is present in the image, install the `cmdstanr` R package and configure it to use the system CmdStan installation. | boolean | `true` |

## Notes

### How the installation survives image builds

Standard Stan/R workflows (e.g. `cmdstanr::install_cmdstan()`) download CmdStan into the user's home directory (`~/.cmdstan/`), which is often not included in the container image or is overwritten on rebuild. This feature instead:

1. Installs CmdStan to `<installDir>/cmdstan-<version>/` – a system-wide, persistent location.
2. Creates a stable symlink at `<installDir>/current` for tooling that needs a version-independent path.
3. Exports `CMDSTAN` and updates `PATH` via `/etc/profile.d/cmdstan.sh` and `/etc/environment`, so every shell session (interactive, non-interactive, login, PAM) automatically sees the correct path.
4. If R is available, writes `CMDSTAN=<path>` to R's `Renviron.site` so that `cmdstanr` picks up the system installation without any runtime configuration.

### Compilation time

`make build` compiles the Stan Math library and several C++ utilities. Expect this step to take **3–10 minutes** depending on the number of CPU cores available during the build.

### Using CmdStan with R (`cmdstanr`)

When `installRPackage` is `true` and R is present, the feature installs `cmdstanr` from the [Stan universe](https://stan-dev.r-universe.dev) and persists the path via `Renviron.site`. No additional R-side configuration is needed:

```r
library(cmdstanr)
cmdstan_path()   # returns /opt/cmdstan/cmdstan-<version>
```

### Using CmdStan directly

After the container starts the `stanc` compiler and `stansummary` utility are on `PATH`:

```bash
stanc --version
stansummary --help
```

---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/cmdstan/devcontainer-feature.json). Add additional notes to a `NOTES.md`._
