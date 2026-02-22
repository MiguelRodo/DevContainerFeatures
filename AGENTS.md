# AGENTS.md

Guidelines for autonomous coding agents (e.g., Google Jules, GitHub Copilot) working in this repository.

---

## 1. Core Philosophy / Project Context

This repository is a collection of **DevContainer Features** — reusable, composable modules that are referenced in `devcontainer.json` files to configure development container environments. Each feature encapsulates an installation or configuration concern (e.g., installing Apptainer, setting up R with renv, installing Mermaid CLI) and is published to the GitHub Container Registry (GHCR).

Key architectural patterns:

- One feature per subdirectory under `src/`.
- Each feature is self-contained: a mandatory `devcontainer-feature.json` metadata file and an `install.sh` script.
- Integration tests live under `test/_global/` and are driven by `scenarios.json`, which maps scenario names to base images and feature option combinations.
- CI runs tests on every push/PR via GitHub Actions; publishing to GHCR is triggered manually via the release workflow.

---

## 2. Tech Stack & Tooling

| Layer | Technology |
|---|---|
| Feature scripts | Bash (`install.sh`) |
| Feature metadata | JSON (`devcontainer-feature.json`) |
| Test scripts | Bash (`test/_global/*.sh`) using `dev-container-features-test-lib` |
| Test orchestration | `@devcontainers/cli` (Node.js / npm) |
| CI/CD | GitHub Actions (`.github/workflows/`) |
| Container registry | GitHub Container Registry (GHCR) |
| Documentation | Markdown |

**Do not** introduce:

- Python, Ruby, or other scripting languages for feature install scripts — use plain Bash.
- Additional Node.js runtime dependencies beyond `@devcontainers/cli`.
- Docker Compose or Kubernetes manifests — features are tested via the DevContainers CLI directly.

---

## 3. Setup Commands

```bash
# Install the DevContainers CLI (required for local testing)
npm install -g @devcontainers/cli

# Verify installation
devcontainer --version
```

No other dependencies need to be installed locally. Feature installation logic runs inside containers during tests.

---

## 4. Build & Test Instructions

There is no separate build step. Tests run feature `install.sh` scripts inside containers.

```bash
# Run all global test scenarios
devcontainer features test --global-scenarios-only .

# Run a specific scenario (replace <scenario-name> with a key from test/_global/scenarios.json)
devcontainer features test --global-scenarios-only . --filter <scenario-name>
```

Example scenario names (from `test/_global/scenarios.json`):

- `all`
- `renv-cache`
- `renv-cache-restore`
- `github-tokens`
- `mermaid_default`
- `repos_debian`
- `repos_alpine`

Test scripts use the `dev-container-features-test-lib` library. Each script sources this library and calls `check` functions to assert expected state.

---

## 5. Coding Style & Conventions

### Bash scripts

- Use `set -e` at the top of every `install.sh` to exit on errors.
- Prefer POSIX-compatible constructs; avoid Bash-specific syntax unless the shebang is `#!/bin/bash`.
- Quote all variable expansions: `"${VAR}"`.
- Keep scripts idempotent where possible.

### JSON metadata (`devcontainer-feature.json`)

- Use camelCase for option names (e.g., `nodeVersion`, `runOnStart`).
- Provide a `description` for every option.
- Keep the `version` field in sync with any corresponding Git tag at release time.

### Naming conventions

- Feature directory names: `kebab-case` (e.g., `renv-cache`, `fit-sne`).
- Test scenario names in `scenarios.json`: `snake_case` (e.g., `mermaid_custom_user`, `repos_alpine`).
- Test script filenames: match the scenario name with a `.sh` extension.

### Commits and PRs

- Use short, imperative commit messages (e.g., `Add github-tokens feature`, `Fix renv-cache restore flag`).
- One logical change per commit.
- PR titles should describe the user-facing change; link to any related issue.
- Do not commit generated or build artifacts (no `node_modules`, no compiled binaries).
