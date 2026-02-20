
# GitHub Tokens (github-tokens)

Manage GitHub authentication tokens (`GITHUB_PAT`, `GITHUB_TOKEN`) on each shell startup.

## Example Usage

```json
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/github-tokens:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| elevateGitHubToken | If true and a more permissive token (GH_TOKEN or GITHUB_PAT) is available, override GITHUB_TOKEN to match it. This helps R tools like renv that prioritize GITHUB_TOKEN over other tokens. | boolean | true |
| overrideGitHubToken | If true, force GITHUB_TOKEN to be set to either GH_TOKEN or GITHUB_PAT (in priority order), regardless of existing value. Use only if you always want to override GITHUB_TOKEN. | boolean | false |

## Overview

This feature provides **session-time** (login/startup) GitHub token management. It installs a script into `~/.bashrc.d/` that runs on every interactive shell startup to ensure the best available GitHub token is used.

This is a companion feature to `renv-cache`, which handles **build-time** token management only. Add this feature when you want persistent token elevation across all shell sessions.

## How It Works

### The Problem

R development tools (`renv`, `remotes`, `pak`, etc.) and other GitHub-aware tools search for authentication tokens in a specific order:

1. `GITHUB_TOKEN`
2. `GH_TOKEN`
3. `GITHUB_PAT`

This precedence causes problems in GitHub Actions and Codespaces because:

- GitHub Actions automatically provides a `GITHUB_TOKEN` with **limited permissions** (typically read-only for public repos)
- It often **cannot access private repositories** or install private packages
- Even when a more permissive token (`GH_TOKEN` or `GITHUB_PAT`) is available, tools will use the restricted `GITHUB_TOKEN` first

### The Solution

This feature ensures that on every shell startup:

1. **`GITHUB_PAT` is always set** from the best available token if not already set.
   - Priority: `GITHUB_PAT` (if set) > `GH_TOKEN` > `GITHUB_TOKEN`

2. **`GITHUB_TOKEN` is elevated** (when `elevateGitHubToken=true`, the default):
   - If `GH_TOKEN` or `GITHUB_PAT` exists, set `GITHUB_TOKEN` to that value
   - Ensures R tools find the better token first

3. **`GITHUB_TOKEN` is force-overridden** (when `overrideGitHubToken=true`):
   - Always replaces `GITHUB_TOKEN` with `GH_TOKEN` or `GITHUB_PAT`
   - More aggressive than `elevateGitHubToken`

## Options Details

### `elevateGitHubToken` (default: `true`)

When a more permissive token (`GH_TOKEN` or `GITHUB_PAT`) is available, override `GITHUB_TOKEN` to match it.

**Use case:** Recommended for most scenarios. Automatically "elevates" the GitHub Actions automatic token when a better one is available.

### `overrideGitHubToken` (default: `false`)

Force `GITHUB_TOKEN` to always use `GH_TOKEN` or `GITHUB_PAT`, regardless of what `GITHUB_TOKEN` is currently set to.

**Use case:** When you need to guarantee the automatic `GITHUB_TOKEN` is never used.

## Relationship with `renv-cache`

The `renv-cache` feature handles token management **only during the image build phase** (for `renv` package installation). It sets tokens at build time and resets them afterwards.

Use `github-tokens` when you also want:
- Token elevation on every shell startup (e.g., for interactive R sessions in a codespace)
- Persistent `GITHUB_PAT` set from the best available token

**Example: combining both features:**
```json
{
  "features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/renv-cache:1": {},
    "ghcr.io/MiguelRodo/DevContainerFeatures/github-tokens:1": {}
  }
}
```

## Common Scenarios

### GitHub Actions with Private R Packages

**Problem:** The automatic `GITHUB_TOKEN` cannot access private repos.

**Solution:** Pass a more permissive token as `GH_TOKEN`:
```yaml
# .github/workflows/build.yml
- name: Build devcontainer
  env:
    GH_TOKEN: ${{ secrets.MY_GITHUB_PAT }}
  run: devcontainer build
```

```json
// .devcontainer/devcontainer.json
{
  "features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/github-tokens:1": {
      "elevateGitHubToken": true
    }
  }
}
```

### Codespaces

**Problem:** Codespaces provides a limited `GITHUB_TOKEN`.

**Solution:** Add a PAT as a Codespaces secret named `GH_TOKEN`. This feature will automatically elevate `GITHUB_TOKEN` to use it on every shell startup.

### Disabling Token Management

If you want to manage tokens manually:
```json
{
  "features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/github-tokens:1": {
      "elevateGitHubToken": false,
      "overrideGitHubToken": false
    }
  }
}
```

## References

- [renv issue #1285: Token lookup order and private packages](https://github.com/r-lib/renv/issues/1285)
- [GitHub Actions: Automatic token authentication](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)
- [GitHub Actions: Permissions for the GITHUB_TOKEN](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token)

---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/github-tokens/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
