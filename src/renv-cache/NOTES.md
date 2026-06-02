## renv Global Cache Configuration

This feature configures the container to use renv's global package cache, which allows packages to be installed once during the image build and reused when the container runs.
This significantly speeds up container rebuilds by avoiding repeated package downloads and installations.

### How It Works

#### 1. R Configuration Files Modified

The feature modifies the site-wide `Renviron.site` file during the build process.
This file is located at `$R_HOME/lib/R/etc/Renviron.site` (typically `/usr/local/lib/R/etc/Renviron.site` or similar depending on R installation).

Two different configurations are applied at different stages:

**During Image Build** (`scripts/r-lib.sh`):

```bash
RENV_PATHS_ROOT=/renv/local
RENV_PATHS_LIBRARY_ROOT=/workspaces/.local/lib/R/library
RENV_PATHS_CACHE=/renv/cache
R_LIBS=/workspaces/.local/lib/R
```

**After Container Creation** (`scripts/r-lib-update.sh`):
```bash
RENV_PATHS_ROOT=/workspaces/.local/renv
RENV_PATHS_LIBRARY_ROOT=/workspaces/.local/lib/R/library
RENV_PATHS_CACHE=/workspaces/.cache/renv:/renv/cache
R_LIBS=/workspaces/.local/lib/R
```

#### 2. Image Build Phase

When the container image is built:

1. `Renviron.site` is configured with initial paths by `scripts/r-lib.sh`.
2. Directories are created for the renv project root during build (`/renv/local`), the global package cache (`/renv/cache`), the library root (`/workspaces/.local/lib/R/library`), and the pak cache directory (`/workspaces/.cache/R/pkgcache/pkg`).
3. Packages are installed from multiple potential sources.
   These sources include `renv.lock` files located in subdirectories of the `renvDir` (default: `/usr/local/share/renv-cache/renv`), remote GitHub repositories specified via the `repositories` option, and explicit package strings specified via the `pkg` option.
   For each source, packages are restored using `renvvv::renvvv_restore()` (or `renvvv_update()` / `renvvv_restore_and_update()` based on options).
   Installed packages are automatically cached in `/renv/cache` due to the `RENV_PATHS_CACHE` setting.
4. A Unified Lockfile is Generated.
  After processing all individual projects and repositories, the feature natively aggregates all unique package dependencies and performs a combined `renv::restore(clean = FALSE)` followed by a `renv::snapshot()`.
  This creates a single, master `renv.lock` containing the union of all dependencies.
  Both this combined lockfile and the individual project lockfiles are saved to an internal container cache (`/usr/local/share/renv-cache/lockfiles`).
5. Cache permissions are set via environment variables to ensure proper access for the runtime user.

#### 3. Container Runtime Phase

When the container starts:

1. `Renviron.site` is updated by `scripts/r-lib-update.sh` (called during post-create).
   `RENV_PATHS_CACHE` is updated to `/workspaces/.cache/renv:/renv/cache`.
   This creates a two-level cache: workspace-specific cache first, then the built-in cache as fallback.
   `RENV_PATHS_ROOT` points to `/workspaces/.local/renv` for workspace-specific project data.
2. Packages from the build cache are automatically available.
  When renv needs a package, it first checks `/workspaces/.cache/renv`.
  If not found, it checks `/renv/cache` (populated during build).
  If found in either cache, renv links the package instead of reinstalling.

### The `renv-cache-copy-lockfile` CLI

This feature installs a built-in CLI tool, `renv-cache-copy-lockfile`, which allows you to easily copy the cached `renv.lock` files out of the internal cache and into your workspace.

By default, it copies the unified, combined lockfile (containing all dependencies from all projects and repos) to your current directory.

**Basic usage:**

```bash
# Copy the unified lockfile to your current directory
renv-cache-copy-lockfile

# Copy the unified lockfile to a specific path
renv-cache-copy-lockfile ./my-project/renv.lock
```

- `--list`: Lists all available cached projects (including the default `renv-cache-overall` combined lockfile and any specific remote repos/local subdirectories) and whether they have updated versions available.
- `-p, --project <name>`: Copy a specific project's lockfile instead of the overall combined one (e.g., `-p M72_CITEseqHIVE_scRNAseq_Pipeline`).
- `--update`: If `update: true` was set in the feature options, prefer copying the updated lockfile over the originally restored one.
- `--overwrite`: Overwrite the destination file if it already exists.

### How to Use This Feature

1. Configure the feature in your `devcontainer.json`.
   You can pass a local directory of lockfiles, remote repositories, or both:

```json
{
  "features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/renv-cache:1": {
      "renvDir": "${containerWorkspaceFolder}/.devcontainer/renv",
      "repositories": "MiguelRodo/projr@main,MiguelRodo/renvvv"
    }
  }
}
```

2. Mount the renv directory (if using `renvDir`):

```json
{
  "mounts": [
    "source=${localWorkspaceFolder}/.devcontainer/renv,target=${containerWorkspaceFolder}/.devcontainer/renv,type=bind"
  ]
}
```

3. Initialize your workspace.
   Once the container builds and starts, simply run the copy command to grab your pre-warmed, unified lockfile and activate your project:

```bash
renv-cache-copy-lockfile
Rscript -e "renv::restore()"
```

#### Advanced: Custom Scripts

You can place custom scripts in your local renv subdirectories.
`renv-cache-renv.R` executes an R script after restore.
`renv-cache-renv.sh` executes a Bash script after restore.
These scripts receive the `pkgExclude` parameter and run in the project directory context during the build.

## Package Restoration

This feature uses `renvvv::renvvv_restore()` for package restoration instead of the default `renv::restore()`.
This provides more robust restoration logic that continues past individual package failures, retries failed packages individually, and reports what couldn't be installed.
It also handles GitHub, CRAN, and Bioconductor packages while providing better error recovery.
Additionally, it supports skipping specific packages via the `pkgExclude` option.
The `renvvv` package is automatically installed during feature setup.

### Skipping Packages

You can exclude specific packages from being restored by using the `pkgExclude` option with a comma-separated list of package names:

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/renv-cache:1": {
        "pkgExclude": "package1,package2,package3"
    }
}
```

This is useful when certain packages fail to install in your environment, you want to manually manage specific package versions, or some packages are simply not needed for your workflow.

## Acknowledgments

This project incorporates code from [AwesomeProject](https://github.com/rocker-org/devcontainer-features), which is licensed under the MIT License.

## GitHub Token Management

### Build-Time Token Override (`overrideTokensAtInstall`)

During the image build phase, `renv-cache` temporarily overrides GitHub authentication tokens so that `renv` package installation can authenticate with GitHub. This is controlled by the `overrideTokensAtInstall` option (default: `true`).

**What it does:**

1. Saves the current values of `GITHUB_TOKEN` and `GITHUB_PAT`
2. Sets `GITHUB_PAT` from the best available token (priority: `GITHUB_PAT` > `GH_TOKEN` > `GITHUB_TOKEN`) if not already set
3. Overrides `GITHUB_TOKEN` with the most permissive token available (priority: `GITHUB_PAT` > `GH_TOKEN`) so R tools find it first
4. Runs the renv package restore/install
5. Resets `GITHUB_TOKEN` and `GITHUB_PAT` to their original values (or unsets them if they were not set before)

This is a simple, blunt approach: it applies only during the feature install step and has no persistent effect on the container.

**To opt out:**

```json
{
  "features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/renv-cache:1": {
      "overrideTokensAtInstall": false
    }
  }
}
```

### Session-Time Token Management

If you also want GitHub token elevation on every shell startup (e.g., for interactive R sessions), use the companion `github-tokens` feature:

```json
{
  "features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/renv-cache:1": {},
    "ghcr.io/MiguelRodo/DevContainerFeatures/github-tokens:1": {}
  }
}
```

### Architectural Note

`renv-cache` only manages tokens **during the image build phase** (feature install). It does not modify `~/.bashrc`, `~/.bashrc.d/`, or any other shell startup files.

