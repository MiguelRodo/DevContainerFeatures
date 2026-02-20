
# GitHub Tokens (github-tokens)

Manage GitHub authentication tokens (GITHUB_PAT, GITHUB_TOKEN) on each shell startup

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



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/MiguelRodo/DevContainerFeatures/blob/main/src/github-tokens/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
