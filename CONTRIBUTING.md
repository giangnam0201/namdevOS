# Contributing to namdevOS

Thank you for your interest in contributing to namdevOS! This document provides guidelines for submitting changes.

## How to Contribute

### Reporting Issues

- Use GitHub Issues to report bugs or request features
- Include your build environment details (OS, live-build version)
- For build failures, include the relevant section of build.log

### Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Run validation: `bash scripts/validate.sh`
5. Commit with a descriptive message
6. Push to your fork and open a Pull Request

### Pull Request Guidelines

- Keep changes focused and atomic
- Include a clear description of what the change does
- Ensure all validation checks pass
- Update documentation if adding new features

## Coding Standards

### Shell Scripts

- Use `#!/bin/bash` shebang (not `#!/bin/sh`)
- Enable strict mode: `set -euo pipefail`
- All scripts must pass `shellcheck` with no errors
- Use descriptive variable names in UPPER_CASE for globals
- Quote all variable expansions: `"$variable"`
- Use `[[ ]]` for conditionals (not `[ ]`)
- Add comments for non-obvious logic

### Package Lists

- One package per line
- Comments start with `#`
- Group related packages with comment headers
- Verify package names exist in Ubuntu archives

### Build Hooks

- Name format: `NNNN-description.hook.chroot`
- Start with `set -euo pipefail`
- Include an echo statement describing what the hook does
- Keep hooks focused on a single task
- Test hooks individually when possible

### Branding and Configuration

- SVG files should be optimized (no unnecessary metadata)
- XML configs must be well-formed
- YAML files must be valid (test with `python3 -c "import yaml; yaml.safe_load(open('file'))"`)

## Testing

Before submitting a PR, ensure:

1. `bash scripts/validate.sh` passes all checks
2. `shellcheck` reports no errors on any .sh file
3. If you modified the build process, test with `bash build.sh --dry-run`
4. If you added packages, verify they exist: `apt-cache show package-name`

## Development Setup

Set up your development environment:

```bash
sudo bash scripts/setup-dev.sh
```

This installs shellcheck, live-build, and other tools needed for development.

## Architecture Decisions

- **XFCE over GNOME**: Lower resource usage, better for developers who want a fast desktop
- **live-build**: Standard Debian/Ubuntu tool for creating live/installable ISOs
- **Calamares**: Modern, user-friendly installer used by many distributions
- **Flatpak over Snap**: Better sandboxing, more distribution-agnostic

## License

By contributing to namdevOS, you agree that your contributions will be licensed under the GPL-3.0 license.
