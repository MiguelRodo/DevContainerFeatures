# DevContainerFeatures Repository Instructions

This repository contains a collection of DevContainer Features - reusable development container configuration modules that can be referenced in `devcontainer.json` files. The features include `git-xet`, `repos`, `config-r`, `apptainer`, `fit-sne`, and `mermaid`.

## Code Standards

### Required Before Each Commit
- Ensure all feature changes include updates to the corresponding `devcontainer-feature.json` file
- Update feature version numbers following semantic versioning when making changes
- Update README.md documentation for any feature modifications

### Development Flow
- **Test**: Run `devcontainer features test --global-scenarios-only .` to test all features
- **Validate**: Run validation via GitHub Actions or locally with `devcontainer` CLI
- **Build**: Features are automatically built and published via GitHub Actions on release

## Repository Structure
- `.github/`: GitHub-specific configuration including workflows
- `src/`: Individual feature implementations, each in its own subdirectory
  - Each feature contains:
    - `devcontainer-feature.json`: Feature metadata and configuration
    - `install.sh`: Installation script
    - `README.md`: Feature-specific documentation
    - `cmd/` and `scripts/`: Optional helper scripts
- `test/`: Test scenarios for features
  - `test/_global/`: Global test scenarios that test multiple features together

## Key Guidelines
1. **Follow DevContainer Feature specification**: Each feature must have a valid `devcontainer-feature.json` file
2. **Use semantic versioning**: Update version numbers appropriately in `devcontainer-feature.json`
3. **Write installation scripts defensively**: Use `set -e` to exit on errors, validate inputs, and provide clear error messages
4. **Test thoroughly**: Add test scenarios in `test/_global/` for new features or significant changes
5. **Document clearly**: Update both feature README and main repository README when adding or modifying features
6. **Maintain backward compatibility**: Be cautious when changing existing feature options or behavior
7. **Use appropriate file permissions**: Ensure scripts have execute permissions (chmod 755)
8. **Handle errors gracefully**: Installation scripts should provide helpful error messages and clean up on failure

## Feature Development Workflow
1. Create or modify feature in `src/<feature-name>/` directory
2. Update `devcontainer-feature.json` with correct version and metadata
3. Implement or update `install.sh` script
4. Add or update tests in appropriate test directory
5. Update feature-specific README.md
6. Update main repository README.md if adding new feature
7. Test locally with `devcontainer features test`
8. Validate with GitHub Actions workflows

## Testing Notes
- The repository uses the DevContainer CLI's built-in testing framework
- Test files use `dev-container-features-test-lib` for assertions
- Global tests in `test/_global/all.sh` test multiple features working together
- CI runs tests automatically on pull requests and pushes to main

## Publishing
- Features are automatically published to GitHub Container Registry (GHCR) via GitHub Actions
- Publishing happens on release workflow trigger
- Features are available at `ghcr.io/MiguelRodo/DevContainerFeatures/<feature-name>`
