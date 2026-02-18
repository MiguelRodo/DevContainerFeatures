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

The `renvvv` package is automatically installed during feature setup.

## Acknowledgments

This project incorporates code from [AwesomeProject](https://github.com/rocker-org/devcontainer-features), which is licensed under the MIT License.
