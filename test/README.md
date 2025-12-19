# Integration Testing with Tart

This directory contains integration tests for darwin_dotfiles using [Tart](https://github.com/cirruslabs/tart) macOS VMs.

## Prerequisites

Install Tart via Homebrew:

```bash
brew install cirruslabs/cli/tart
```

## Quick Start

### 1. Pull a base macOS image

```bash
# Pull a pre-built macOS image (Sequoia recommended)
tart clone ghcr.io/cirruslabs/macos-sequoia-base:latest dotfiles-test-base
```

### 2. Run the tests

```bash
# Test both Bash and Zsh installations
./test/run-integration-tests.sh

# Or test individually
./test/run-integration-tests.sh bash
./test/run-integration-tests.sh zsh
```

## Test Structure

```
test/
├── README.md                    # This file
├── run-integration-tests.sh     # Main test runner
├── scripts/
│   ├── setup-vm.sh              # One-time VM setup script
│   ├── test-bash.sh             # Bash-specific tests
│   ├── test-zsh.sh              # Zsh-specific tests
│   └── common-tests.sh          # Shared test functions
└── fixtures/
    └── expected-outputs.sh      # Expected command outputs
```

## What Gets Tested

### Installation Tests
- [ ] `install.sh` clones repository correctly
- [ ] `init.sh` creates profile files
- [ ] Profile files have correct managed sections

### Shell Tests (run for both Bash and Zsh)
- [ ] Shell detection works correctly (`is_shell_bash`)
- [ ] Profile files are sourced on login
- [ ] `DOTFILES_ROOT` is set correctly
- [ ] `PATH` includes `$DOTFILES_ROOT/bin`

### DevTools Tests
- [ ] `install_devtools` installs Homebrew
- [ ] `install_devtools` installs jq
- [ ] `install_devtools` installs FVM/Flutter
- [ ] `brew` command available after install

### Function Tests
- [ ] `up` updates dotfiles
- [ ] `dotfiles_init` reinitializes correctly
- [ ] Git aliases work (`ga`, `gb`, `gc`, `gs`, `gp`)
- [ ] `bump_flutter` executes without error

## Manual VM Testing

For interactive debugging:

```bash
# Start VM with GUI
tart run dotfiles-test-base

# SSH into VM (default credentials: admin/admin)
ssh admin@$(tart ip dotfiles-test-base)
```

## CI/CD Integration

See `.github/workflows/integration-test.yml` for GitHub Actions setup.

## Troubleshooting

### VM Won't Start
```bash
# Check Tart status
tart list

# Delete and recreate VM
tart delete dotfiles-test-base
tart clone ghcr.io/cirruslabs/macos-sequoia-base:latest dotfiles-test-base
```

### Tests Hang
- Ensure the VM has network access
- Check VM memory allocation (default 4GB recommended)

### SSH Connection Refused
```bash
# Wait for VM to fully boot
sleep 30

# Verify IP address
tart ip dotfiles-test-base
```

