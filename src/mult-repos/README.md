
# Work with multiple repositories

Provides features to work with multiple repositories.

```jsonc
"features": {
    "ghcr.io/MiguelRodo/DevContainerFeatures/mult-repos": {}
}
```

## Clone GitHub repositories

Adds the command `repos-clone-github` to clone all repositories listed in `repos-to-clone.list`.

This command is run each time the container starts.

## Clone XetHub repositories

Adds the command `repos-clone-xethub` to clone all repositories listed in `repos-to-clone-xethub.list`.
These repositories are lazily cloned.

This command is also run each time the container starts.
If `git-xet` is not installed, then it's not run.

## Create `EntireProject.code-workspace` file

All repositories listed in `repos-to-clone.list` and `repos-to-clone-xethub.list` are added to the `EntireProject.code-workspace` file.


