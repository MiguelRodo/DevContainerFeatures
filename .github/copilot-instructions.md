# DevContainer Features Repository - Copilot Instructions

This repository contains a collection of DevContainer Features - reusable development container configuration modules that can be referenced in `devcontainer.json` files.

## Important: Keeping These Instructions Updated

**These copilot instructions should always be considered for updates when:**
- New features are added to the repository
- Existing features are renamed, modified, or removed
- Feature behavior changes significantly
- New development patterns or best practices emerge
- Common errors or troubleshooting scenarios are discovered

When updating these instructions, follow best practices for writing copilot instructions:
- Be concise and specific
- Use clear examples with code snippets
- Organize information hierarchically (most important/common first)
- Include actual commands that can be copy-pasted
- Document common pitfalls and their solutions
- Keep the structure consistent and navigable

## Quick Reference

### Available Features
- `apptainer` - Install Apptainer for HPC containerization
- `renv-cache` - Configure R with renv cache for VS Code development
- `fit-sne` - Install FIt-SNE for dimensionality reduction
- `mermaid` - Install Mermaid CLI for diagram generation
- `repos` - Manage multiple Git repositories automatically

### Key Commands
```bash
# Install DevContainer CLI (required for testing)
npm install -g @devcontainers/cli

# Run all tests
devcontainer features test --global-scenarios-only .

# Test a specific scenario
devcontainer features test --global-scenarios-only . --filter <scenario-name>
```

## Repository Structure

```
DevContainerFeatures/
├── .github/
│   ├── workflows/          # CI/CD workflows
│   │   ├── test.yaml      # Runs on push/PR - tests all features
│   │   ├── release.yaml   # Manual trigger - publishes to GHCR
│   │   └── validate.yml   # Validates feature metadata
│   └── copilot-instructions.md  # This file
├── src/
│   └── <feature-name>/    # Each feature has its own directory
│       ├── devcontainer-feature.json  # Metadata & options (REQUIRED)
│       ├── install.sh     # Installation script (REQUIRED, must be executable)
│       ├── README.md      # Feature documentation (REQUIRED)
│       ├── NOTES.md       # Internal development notes (optional)
│       ├── cmd/           # Executable commands (optional)
│       └── scripts/       # Helper scripts (optional)
├── test/
│   └── _global/
│       ├── scenarios.json # Test configurations for all features
│       └── *.sh          # Test scripts (use dev-container-features-test-lib)
└── README.md             # Main repository documentation
```

## Development Workflow

### Creating a New Feature

1. **Create feature directory structure**
   ```bash
   mkdir -p src/<feature-name>
   cd src/<feature-name>
   ```

2. **Create `devcontainer-feature.json`** (REQUIRED)
   ```json
   {
       "name": "Descriptive Feature Name",
       "id": "feature-name",
       "version": "1.0.0",
       "description": "Brief description of what this feature does",
       "options": {
           "optionName": {
               "type": "boolean|string",
               "default": "default-value",
               "description": "What this option does"
           }
       }
   }
   ```

3. **Create `install.sh`** (REQUIRED, must be executable)
   ```bash
   #!/usr/bin/env bash
   set -e  # Exit on any error
   
   # Must run as root
   [ "$(id -u)" -eq 0 ] || { echo "Please run as root" >&2; exit 1; }
   
   # Access options via environment variables
   OPTION_NAME="${OPTIONNAME:-default}"
   
   # Your installation logic here
   ```
   
   Make it executable: `chmod +x install.sh`

4. **Create `README.md`** (REQUIRED)
   - Include usage example with `devcontainer.json` snippet
   - Document all options in a table
   - Add any important notes or warnings

5. **Add test scenarios** in `test/_global/scenarios.json`
   ```json
   {
       "feature-name_default": {
           "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
           "features": {
               "feature-name": {}
           }
       }
   }
   ```

6. **Create test script** in `test/_global/<feature-name>.sh`
   ```bash
   #!/bin/bash
   set -e
   source dev-container-features-test-lib
   
   check "binary is installed" which <binary-name>
   check "version command works" <binary-name> --version
   
   reportResults
   ```

7. **Update main README.md** to include the new feature

### Modifying an Existing Feature

1. **Update version in `devcontainer-feature.json`**
   - PATCH: Bug fixes, documentation updates (1.0.0 → 1.0.1)
   - MINOR: New features, backward-compatible (1.0.0 → 1.1.0)
   - MAJOR: Breaking changes (1.0.0 → 2.0.0)

2. **Modify `install.sh` carefully**
   - Always use `set -e` at the top
   - Validate inputs and provide clear error messages
   - Clean up on failure
   - Maintain backward compatibility when possible

3. **Update documentation**
   - Update feature's `README.md`
   - Update main `README.md` if public-facing changes
   - Update `NOTES.md` for internal development notes

4. **Test your changes**
   ```bash
   devcontainer features test --global-scenarios-only .
   ```

## Testing

### Test Structure
- Tests are located in `test/_global/`
- `scenarios.json` defines test configurations
- Each `.sh` test file validates specific feature functionality
- Uses `dev-container-features-test-lib` for assertions

### Running Tests

**Install DevContainer CLI first** (one-time setup):
```bash
npm install -g @devcontainers/cli
```

**Run all tests**:
```bash
devcontainer features test --global-scenarios-only .
```

**Filter specific scenarios**:
```bash
devcontainer features test --global-scenarios-only . --filter renv-cache
```

### Writing Tests

Test files should:
1. Start with `#!/bin/bash` and `set -e`
2. Source the test library: `source dev-container-features-test-lib`
3. Use `check` commands to validate functionality
4. End with `reportResults`

Example:
```bash
#!/bin/bash
set -e
source dev-container-features-test-lib

check "binary exists" which my-tool
check "binary is executable" test -x /usr/local/bin/my-tool
check "version command works" my-tool --version

reportResults
```

### Common Test Scenarios
- Test with default options
- Test with custom options
- Test on different base images (Ubuntu, Debian, Alpine)
- Test combinations of features (in `test/_global/all.sh`)

## Publishing & Release

### Publishing Process
1. Features are published to GitHub Container Registry (GHCR)
2. Trigger manually via GitHub Actions: `.github/workflows/release.yaml`
3. Only runs from `main` branch
4. Automatically generates and updates documentation

### Published Location
Features are available at:
```
ghcr.io/MiguelRodo/DevContainerFeatures/<feature-name>:<version>
```

### Release Workflow
1. Make and test changes on a feature branch
2. Update version in `devcontainer-feature.json`
3. Update documentation
4. Merge to `main`
5. Manually trigger release workflow in GitHub Actions
6. Workflow will publish and create documentation PR

## Common Patterns & Best Practices

### Installation Scripts (`install.sh`)

**Always start with**:
```bash
#!/usr/bin/env bash
set -e  # Exit on error

# Check for root
[ "$(id -u)" -eq 0 ] || { echo "Please run as root" >&2; exit 1; }
```

**Access feature options via environment variables**:
```json
// devcontainer-feature.json
{
    "options": {
        "myOption": {
            "type": "string",
            "default": "defaultValue"
        }
    }
}
```
```bash
# install.sh - option names are UPPERCASE without special chars
MY_OPTION="${MYOPTION:-defaultValue}"
```

**Detect OS for cross-platform support**:
```bash
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

OS_ID=$(detect_os)
echo "Detected OS: $OS_ID"

if [ "$OS_ID" = "ubuntu" ] || [ "$OS_ID" = "debian" ]; then
    # APT-based installation
elif [ "$OS_ID" = "alpine" ]; then
    # APK-based installation
else
    echo "Unsupported OS: $OS_ID" >&2
    exit 1
fi
```

**Clean up package manager caches**:
```bash
# For APT
apt-get clean
rm -rf /var/lib/apt/lists/*

# For APK
rm -rf /var/cache/apk/*
```

### Using postCreateCommand / postStartCommand

For features that need to run scripts after container creation:

```json
{
    "postCreateCommand": "/usr/local/bin/my-post-create-script",
    "postStartCommand": "/usr/local/bin/my-post-start-script"
}
```

Scripts should:
- Be installed during the feature installation
- Be executable (`chmod +x`)
- Handle failures gracefully (use `set -e` carefully)
- Be idempotent (safe to run multiple times)

### Version Numbering

Follow semantic versioning strictly:
- **MAJOR.MINOR.PATCH** (e.g., 2.1.3)
- **MAJOR**: Breaking changes to feature behavior or options
- **MINOR**: New features, new options (backward-compatible)
- **PATCH**: Bug fixes, documentation updates

## Common Errors & Solutions

### Error: "devcontainer: command not found"
**Solution**: Install DevContainer CLI
```bash
npm install -g @devcontainers/cli
```

### Error: Test fails with "Permission denied" on install.sh
**Solution**: Ensure install.sh is executable
```bash
chmod +x src/<feature-name>/install.sh
git add src/<feature-name>/install.sh
```

### Error: Feature not found during testing
**Solution**: Check that:
1. `devcontainer-feature.json` exists in `src/<feature-name>/`
2. The `id` field matches the directory name
3. The JSON is valid (no syntax errors)

### Error: "Please run as root" during installation
**Cause**: Install scripts must run as root in container builds
**Solution**: Ensure your install.sh checks for root:
```bash
[ "$(id -u)" -eq 0 ] || { echo "Please run as root" >&2; exit 1; }
```

### Error: Option not being passed to install script
**Solution**: Option names in environment variables are transformed:
- JSON: `"myOptionName"` → Environment: `$MYOPTIONNAME`
- Hyphens are removed: `"my-option"` → `$MYOPTION`
- Case is uppercase

### Error: APT repository GPG key issues
**Common with custom APT repositories**

**Problem**: GPG key needs to be dearmored
```bash
# ❌ Wrong - doesn't work with modern APT
curl -fsSL https://example.com/KEY.gpg > /usr/share/keyrings/example.gpg

# ✅ Correct - pipe through gpg --dearmor
curl -fsSL https://example.com/KEY.gpg | gpg --dearmor -o /usr/share/keyrings/example.gpg
```

**Full example** (see `src/repos/install.sh` for reference):
```bash
curl -fsSL https://raw.githubusercontent.com/MiguelRodo/apt-miguelrodo/main/KEY.gpg \
    | gpg --dearmor -o /usr/share/keyrings/miguelrodo-repos.gpg

echo "deb [signed-by=/usr/share/keyrings/miguelrodo-repos.gpg] https://raw.githubusercontent.com/MiguelRodo/apt-miguelrodo/main/ ./" \
    > /etc/apt/sources.list.d/miguelrodo-repos.list
```

### Error: Package installation hangs waiting for input
**Solution**: Use non-interactive mode
```bash
export DEBIAN_FRONTEND=noninteractive
apt-get install -y package-name
```

Or for specific packages requiring configuration:
```bash
echo "tzdata tzdata/Areas select America" | debconf-set-selections
echo "tzdata tzdata/Zones/America select New_York" | debconf-set-selections
apt-get install -y tzdata
```

### Error: renv cache or library path issues (renv-cache feature)
**Cause**: renv paths need to persist across container rebuilds

**Solution**: The renv-cache feature uses a two-phase configuration:
1. **Build phase**: Cache in `/renv/cache` (persists in image)
2. **Runtime phase**: Cache in `/workspaces/.cache/renv:/renv/cache` (workspace + image)

Paths are configured via `Renviron.site` at `$R_HOME/lib/R/etc/Renviron.site`

See `src/renv-cache/NOTES.md` for detailed documentation.

## CI/CD Workflows

### Test Workflow (`.github/workflows/test.yaml`)
- **Triggers**: Push to main, pull requests, manual dispatch
- **What it does**: Runs `devcontainer features test --global-scenarios-only .`
- **Important**: Tests must pass before merging PRs

### Release Workflow (`.github/workflows/release.yaml`)
- **Triggers**: Manual workflow dispatch only
- **Requirements**: Must be on `main` branch
- **What it does**:
  1. Publishes features to GHCR
  2. Generates documentation
  3. Creates PR with documentation updates
- **Important**: Only run after testing and merging to main

### Validate Workflow (`.github/workflows/validate.yml`)
- **What it does**: Validates feature metadata and structure

## Feature-Specific Notes

### renv-cache
- Complex renv caching mechanism - see `src/renv-cache/NOTES.md`
- Requires R base image (e.g., `ghcr.io/rocker-org/devcontainer/r-ver:4.4`)
- Modifies system-wide R configuration files
- Uses `postCreateCommand` for package restoration

### repos
- Multi-OS support (APT for Debian/Ubuntu, source install for Alpine)
- Uses custom APT repository (`apt-miguelrodo`)
- Automatically runs on container start via `postStartCommand`
- Clones repositories from `repos.list` file

### mermaid
- Requires Node.js (installs if not present)
- Creates non-root user for Puppeteer
- Configures Puppeteer for headless rendering
- Complex dependency chain (Chromium + system libraries)

### apptainer
- HPC-focused container system
- Requires timezone configuration for proper mounting
- Uses PPA for installation

### fit-sne
- Compiles from source (takes several minutes)
- Requires FFTW 3.3.10 library
- Build dependencies: `build-essential`, `wget`, `git`

## Troubleshooting Tips

1. **Always check install script permissions**: `ls -l src/*/install.sh`
2. **Validate JSON files**: Use `jq` or a JSON validator on `devcontainer-feature.json` files
3. **Test locally before CI**: Run `devcontainer features test --global-scenarios-only .`
4. **Check logs carefully**: DevContainer CLI provides detailed error messages
5. **Test on multiple base images**: Ubuntu, Debian, and Alpine if applicable
6. **Review similar features**: Look at existing features for patterns and examples

## Additional Resources

- [DevContainer Features Specification](https://containers.dev/implementors/features/)
- [DevContainer CLI Documentation](https://github.com/devcontainers/cli)
- [Main Repository README](../README.md)
- Feature-specific NOTES.md files in each `src/<feature-name>/` directory
