
# renv cache (renv-cache)

Configure R with renv cache

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/renv-cache:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| setRLibPaths | Whether to set default paths for R libraries (including for `renv`) to avoid needing to reinstall upon codespace rebuild. | boolean | true |
| overrideTokensAtInstall | If true, temporarily override GITHUB_TOKEN and set GITHUB_PAT from the best available token (priority: GITHUB_PAT > GH_TOKEN > GITHUB_TOKEN) during the renv package install phase. Tokens are reset to their original values after install completes. Disable if you want to manage tokens manually. | boolean | true |
| restore | Whether to run package restoration using renvvv::renvvv_restore(). Default is true. | boolean | true |
| update | Whether to run package update using renvvv::renvvv_update(). If both restore and update are true, renvvv::renvvv_restore_and_update() is used. Default is false. | boolean | false |
| renvDir | Path to the directory containing subdirectories with `renv.lock` files. Defaults to `/usr/local/share/renv-cache/renv` if the environment variable is not set. | string | /usr/local/share/renv-cache/renv |
| pkgExclude | Comma-separated list of packages to exclude from the renv snapshot restore process. | string | - |
| usePak | Whether to use `pak` for package installation. | boolean | false |
| debug | Whether to print debug information during package restore. | boolean | false |
| debugRenv | Whether to print debug information during renv restore. | boolean | false |

## renv Global Cache Configuration

This feature configures the container to use renv's global package cache, which allows packages to be installed once during the image build and then reused when the container runs. This significantly speeds up container rebuilds by avoiding repeated package downloads and installations.

### How It Works

#### 1. R Configuration Files Modified

The feature modifies the **site-wide `Renviron.site`** file during the build process. This file is located at `$R_HOME/lib/R/etc/Renviron.site` (typically `/usr/local/lib/R/etc/Renviron.site` or similar depending on R installation).

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

1. **Renviron.site is configured** with initial paths by `scripts/r-lib.sh`
2. **Directories are created**:
   - `/renv/local` - renv project root during build
   - `/renv/cache` - global package cache (persists in image)
   - `/workspaces/.local/lib/R/library` - library root
   - `/workspaces/.cache/R/pkgcache/pkg` - pak cache directory

3. **Packages are installed** from `renv.lock` files located in subdirectories of the `renvDir` (default: `/usr/local/share/config-r/renv`):
   - The `install.sh` script calls `config-r-renv-restore-build`
   - For each subdirectory containing an `renv.lock` file, `config-r-renv-restore` is invoked
   - Packages are restored using `renvvv::renvvv_restore()` (or `renvvv_update()` / `renvvv_restore_and_update()` based on options)
   - Installed packages are automatically cached in `/renv/cache` due to the `RENV_PATHS_CACHE` setting

4. **Cache permissions** are set via environment variables:
   - `RENV_CACHE_MODE=0755` ensures proper permissions
   - `RENV_CACHE_USER` is set to `$_REMOTE_USER` if available

#### 3. Container Runtime Phase

When the container starts:

1. **Renviron.site is updated** by `scripts/r-lib-update.sh` (called during post-create):
   - `RENV_PATHS_CACHE` is updated to `/workspaces/.cache/renv:/renv/cache`
   - This creates a two-level cache: workspace-specific cache first, then the built-in cache as fallback
   - `RENV_PATHS_ROOT` points to `/workspaces/.local/renv` for workspace-specific project data

2. **Packages from the build cache are automatically available**:
   - When renv needs a package, it first checks `/workspaces/.cache/renv`
   - If not found, it checks `/renv/cache` (populated during build)
   - If found in either cache, renv links the package instead of reinstalling

### How to Use This Feature

#### Basic Usage

1. **Create the renv directory structure** in your repository:
   ```
   .devcontainer/
   └── renv/
       ├── project1/
       │   └── renv.lock
       ├── project2/
       │   └── renv.lock
       └── shared/
           └── renv.lock
   ```

2. **Configure the feature** in your `devcontainer.json`:
   ```json
   {
     "features": {
       "ghcr.io/MiguelRodo/DevContainerFeatures/config-r:2": {
         "renvDir": "${containerWorkspaceFolder}/.devcontainer/renv"
       }
     }
   }
   ```

3. **Mount the renv directory** so it's available during build:
   ```json
   {
     "mounts": [
       "source=${localWorkspaceFolder}/.devcontainer/renv,target=/usr/local/share/config-r/renv,type=bind"
     ]
   }
   ```

   Or if using a custom `renvDir`:
   ```json
   {
     "mounts": [
       "source=${localWorkspaceFolder}/.devcontainer/renv,target=${containerWorkspaceFolder}/.devcontainer/renv,type=bind"
     ],
     "features": {
       "ghcr.io/MiguelRodo/DevContainerFeatures/config-r:2": {
         "renvDir": "${containerWorkspaceFolder}/.devcontainer/renv"
       }
     }
   }
   ```

#### How Packages Get Cached

1. **During build**: All packages from `renv.lock` files in `renvDir` subdirectories are installed and cached in `/renv/cache`
2. **During runtime**: When you use renv in your project:
   - Run `renv::restore()` in your project
   - renv checks the cache first (`/workspaces/.cache/renv:/renv/cache`)
   - Packages already in cache are linked (fast) instead of downloaded (slow)
   - New packages are downloaded and added to `/workspaces/.cache/renv`

#### Advanced: Custom Scripts

You can place custom scripts in your renv subdirectories:
- `config-r-renv.R` - R script executed after restore
- `config-r-renv.sh` - Bash script executed after restore

These scripts receive the `pkgExclude` parameter and run in the project directory context.

## Package Restoration

This feature uses [`renvvv::renvvv_restore()`](https://github.com/MiguelRodo/renvvv) for package restoration instead of the default `renv::restore()`. This provides more robust restoration logic that:

- Continues past individual package failures
- Retries failed packages individually  
- Reports what couldn't be installed
- Handles GitHub, CRAN, and Bioconductor packages
- Provides better error recovery
- Supports skipping specific packages via the `pkgExclude` option

The `renvvv` package is automatically installed during feature setup.

### Skipping Packages

You can exclude specific packages from being restored by using the `pkgExclude` option with a comma-separated list of package names:

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/config-r:2": {
        "pkgExclude": "package1,package2,package3"
    }
}
```

This is useful when:
- Certain packages fail to install in your environment
- You want to manually manage specific package versions
- Some packages are not needed for your workflow

## Acknowledgments

This project incorporates code from [AwesomeProject](https://github.com/rocker-org/devcontainer-features), which is licensed under the MIT License.

## GitHub Token Management

### Build-Time Token Override (`overrideTokensAtInstall`)

During the image build phase, `renv-cache` temporarily overrides GitHub authentication tokens so that `renv` package installation can authenticate with GitHub. This is controlled by the `overrideTokensAtInstall` option (default: `true`).

**What it does:**

1. **Saves** the current values of `GITHUB_TOKEN` and `GITHUB_PAT`
2. **Sets `GITHUB_PAT`** from the best available token (priority: `GITHUB_PAT` > `GH_TOKEN` > `GITHUB_TOKEN`) if not already set
3. **Overrides `GITHUB_TOKEN`** with the most permissive token available (priority: `GITHUB_PAT` > `GH_TOKEN`) so R tools find it first
4. **Runs** the renv package restore/install
5. **Resets** `GITHUB_TOKEN` and `GITHUB_PAT` to their original values (or unsets them if they were not set before)

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

### References

- [renv issue #1285: Token lookup order and private packages](https://github.com/r-lib/renv/issues/1285)
- [GitHub Actions: Automatic token authentication](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)
- [GitHub Actions: Permissions for the GITHUB_TOKEN](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token)


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/renv-cache/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
