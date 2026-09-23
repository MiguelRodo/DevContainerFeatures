# Repository instructions for `MiguelRodo/DevContainerFeatures`

This repository publishes reusable Dev Container Features to GHCR. Feature metadata and behaviour live under `src/<feature>/`; integration scenarios live under `test/_global/`.

## Current features

- `apptainer`
- `build-info`
- `cmdstan`
- `fit-sne`
- `github-tokens`
- `mermaid`
- `renv-cache`
- `utils`

`repos` is deprecated. New work should target `utils` unless maintaining backwards compatibility for existing `repos` users.

## Source of truth

- `src/<feature>/devcontainer-feature.json`: canonical feature metadata, options, version and lifecycle ordering.
- `src/<feature>/install.sh`: installation behaviour.
- `src/<feature>/cmd/` and `scripts/`: runtime helpers where present.
- `test/_global/scenarios.json` plus matching shell tests: integration coverage.
- `.github/workflows/release.yaml`: manual publishing workflow.

Do not infer current options from the root README if it disagrees with feature metadata.

## Ponytail

For coding, fixing, refactoring, reviewing, dependency choices and implementation design, read and follow `.agents/skills/ponytail/SKILL.md` in **full** mode by default. Use **ultra** only when explicitly requested.

Repository-specific requirements in this file take precedence over generic Ponytail guidance. In particular, do not simplify away security, input validation, backwards compatibility, supported-platform behaviour or the repository's behavioural testing standard.

## Validation

Run the narrowest relevant scenario while iterating, then the full suite before finishing substantial feature changes:

```bash
devcontainer features test --global-scenarios-only . --filter <scenario-name>
devcontainer features test --global-scenarios-only .
```

For fast remote iteration, dispatch `CI - Test Features` on your branch with `test_mode=light` and `feature=<id>` (for example, `gh workflow run test.yaml --ref <branch> -f test_mode=light -f feature=mermaid`). This runs one behaviour-focused scenario for that feature. Pull requests still run all configured global scenarios for each changed feature. Use `test_mode=full` and `feature=all` for a full manual run.

When changing shell code, also run syntax and static checks on the files touched:

```bash
bash -n path/to/script.sh
shellcheck path/to/script.sh
```

When changing workflow YAML, validate the YAML and run `actionlint` when available.

## Testing standard: test behaviour, not installation artefacts

Presence-only checks such as `command -v`, file existence, executable bits or `--version` are useful smoke checks but are not sufficient as the primary acceptance test.

For every bug fix or behaviour change, add or strengthen a test that exercises the real user outcome. Prefer tiny deterministic fixtures.

Examples:

- `mermaid`: render a minimal Mermaid source to SVG and verify non-empty valid output.
- `cmdstan`: compile and run a minimal Stan model, or at minimum compile one successfully.
- `renv-cache`: restore a small lockfile and verify packages are available from the intended persistent cache/library path.
- `github-tokens`: verify token behaviour from a fresh shell/session, not only generated files.
- `utils`: exercise the installed command against a small fixture workflow, including `repos clone` behaviour where relevant.
- `build-info`: run `container-info` and assert the configured metadata.
- `fit-sne`: run FIt-SNE on a tiny synthetic input and verify usable output.
- `apptainer`: perform the smallest practical container operation supported by CI.

If a platform is advertised as supported, test the real behaviour on that platform where practical.

## Feature implementation conventions

- Feature install scripts are Bash. Do not introduce another scripting runtime for installation logic without a strong reason.
- Quote variable expansions and validate user-controlled option values before using them in commands.
- Keep feature installation idempotent where practical.
- Prefer existing tools already supplied by the base image or an explicit `installsAfter` dependency rather than silently replacing user-installed tooling.
- Avoid mutable remote-script execution such as `curl ... | bash`.
- Preserve backwards compatibility unless the issue explicitly calls for a breaking change.
- Update `devcontainer-feature.json` version for a shipped feature behaviour change. Test-only, CI-only and documentation-only changes do not require a feature version bump.
- Keep generated feature documentation in sync through the existing release/documentation workflow rather than hand-editing generated sections.

## Dependencies and Dependabot

`.github/dependabot.yml` monitors both:

- GitHub Actions dependencies
- Dev Container dependencies

Both are checked monthly, grouped into routine update PRs, with one open PR per ecosystem. Let Dependabot handle routine upgrades rather than making unrelated dependency bumps in feature PRs.

For GitHub Actions, avoid mutable branch references such as `@main`. Prefer a stable version or immutable SHA according to the repository's current convention.

## Pull requests

- Keep one logical change per PR.
- Link the relevant issue when one exists.
- Explain the user-visible failure and how the test proves the fix.
- Do not claim a feature is fixed merely because installation completes.
- Before finishing, inspect the diff for unrelated generated files, credentials, tokens or build artefacts.

## Release

Publishing is manual via `.github/workflows/release.yaml` from `main`. Do not create or move release tags manually unless an issue explicitly requires changing the release process.
