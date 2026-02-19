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

### The Problem

R development tools (`renv`, `remotes`, `pak`, etc.) search for GitHub authentication tokens in a specific order:

1. `GITHUB_TOKEN`
2. `GH_TOKEN`
3. `GITHUB_PAT`

This precedence causes problems in GitHub Actions and Codespaces because:

- GitHub Actions automatically provides a `GITHUB_TOKEN` environment variable
- This automatic token has **limited permissions** (typically read-only for public repos)
- It often **cannot access private repositories** or install private packages
- Even when a more permissive token (`GH_TOKEN` or `GITHUB_PAT`) is available in the environment, R tools will use the restricted `GITHUB_TOKEN` first
- This leads to confusing failures where package installation fails despite having a valid token available

### The Solution

This feature provides three complementary strategies to manage GitHub tokens:

#### 1. `ensureGitHubPatSet` (default: `true`)

Always sets `GITHUB_PAT` from the best available token if it's not already set.

**Token priority:** `GITHUB_PAT` (if already set) > `GH_TOKEN` > `GITHUB_TOKEN`

**Use case:** Ensures R tools can fall back to `GITHUB_PAT` if they check it (though most prioritize `GITHUB_TOKEN`).

#### 2. `elevateGitHubToken` (default: `true`)

When a more permissive token (`GH_TOKEN` or `GITHUB_PAT`) is available, override `GITHUB_TOKEN` to match it.

**How it works:**
- If `GH_TOKEN` or `GITHUB_PAT` exists, set `GITHUB_TOKEN` to that value
- This ensures R tools find the better token first (since they check `GITHUB_TOKEN` before others)
- Does not override if only `GITHUB_TOKEN` is available

**Use case:** **Recommended for most scenarios.** Automatically "elevates" the GitHub Actions automatic token to a more permissive one when available.

**Example:**
```json
{
  "features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/config-r:2": {
      "elevateGitHubToken": true
    }
  }
}
```

#### 3. `overrideGitHubToken` (default: `false`)

Force `GITHUB_TOKEN` to always use `GH_TOKEN` or `GITHUB_PAT`, regardless of what `GITHUB_TOKEN` is currently set to.

**How it works:**
- Always replaces `GITHUB_TOKEN` with `GH_TOKEN` or `GITHUB_PAT` (in that priority order)
- More aggressive than `elevateGitHubToken`
- Use when you **always** want to override the automatic GitHub Actions token

**Use case:** When you need to guarantee that the automatic `GITHUB_TOKEN` is never used, even if it's the only token available.

**Example:**
```json
{
  "features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/config-r:2": {
      "overrideGitHubToken": true
    }
  }
}
```

### Common Scenarios

#### GitHub Actions with Private Packages

**Problem:** Need to install private R packages from GitHub, but the automatic `GITHUB_TOKEN` doesn't have access.

**Solution:**
1. Create a Personal Access Token (PAT) with `repo` scope
2. Add it as a repository secret (e.g., `MY_GITHUB_PAT`)
3. Pass it to the devcontainer:

```yaml
# .github/workflows/build.yml
- name: Build devcontainer
  env:
    GH_TOKEN: ${{ secrets.MY_GITHUB_PAT }}
  run: |
    devcontainer build
```

```json
// .devcontainer/devcontainer.json
{
  "features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/config-r:2": {
      "elevateGitHubToken": true  // Will use GH_TOKEN instead of automatic GITHUB_TOKEN
    }
  }
}
```

#### Codespaces

**Problem:** Codespaces provides a limited `GITHUB_TOKEN` that can't access private repos.

**Solution:**
1. Create a PAT with necessary scopes
2. Add it as a Codespaces secret named `GH_TOKEN`
3. The feature will automatically elevate `GITHUB_TOKEN` to use your PAT

#### Interactive Development

**Problem:** Want to ensure the best token is always used during interactive R sessions.

**Solution:**
```json
{
  "features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/config-r:2": {
      "ensureGitHubPatSet": true,
      "elevateGitHubToken": true
    }
  }
}
```

### Disabling Token Management

If you want to manage tokens manually:

```json
{
  "features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/config-r:2": {
      "ensureGitHubPatSet": false,
      "elevateGitHubToken": false,
      "overrideGitHubToken": false
    }
  }
}
```

### References

- [renv issue #1285: Token lookup order and private packages](https://github.com/r-lib/renv/issues/1285)
- [GitHub Actions: Automatic token authentication](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)
- [GitHub Actions: Permissions for the GITHUB_TOKEN](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token)
