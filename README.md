# darwin_dotfiles

Minimal Bash/Zsh shell configuration for macOS focused on Flutter development.

## Features

- **Shell Support**: Works with both Bash and Zsh
- **Architecture Support**: Handles both Apple Silicon (ARM64) and Intel (x86_64) Macs
- **Flutter/FVM Integration**: Proxy wrappers and tooling for Flutter Version Manager
- **Homebrew Integration**: Automatic detection and setup for both architectures
- **Managed Sections**: Updates preserve your custom shell configurations

## Prerequisites

- macOS (Darwin)
- Git
- Internet connection (for cloning and installing tools)

## Installation

### Quick Start

```bash
/bin/bash <(curl -fsSL https://raw.githubusercontent.com/jlaboll/darwin_dotfiles/main/setup/install.sh)
```

### Manual Installation

```bash
git clone git@github.com:jlaboll/darwin_dotfiles.git ~/.darwin_dotfiles
~/.darwin_dotfiles/setup/init.sh
```

Then restart your terminal or source your profile:

```bash
source ~/.bash_profile  # for Bash
source ~/.zsh_profile   # for Zsh
```

## Usage

### Functions

| Function | Description |
|----------|-------------|
| `up` | Update dotfiles from git and reinitialize |
| `dotfiles_init` | Reinitialize dotfiles (reapply managed sections) |
| `install_devtools` | Install Homebrew, jq, and FVM/Flutter |
| `bump_flutter` | Update Flutter and clear macOS quarantine flags |
| `unquarantine_flutter <path>` | Remove quarantine attributes from Flutter executables |
| `flutter_run_web <target>` | Run Flutter web with CORS disabled (for local dev) |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DOTFILES_ROOT` | Path to dotfiles directory | `$HOME/.darwin_dotfiles` |
| `FVM_CACHE_PATH` | FVM cache directory | Auto-detected from FVM |
| `HOMEBREW_PREFIX` | Homebrew install location | Auto-detected |

## Project Structure

```
darwin_dotfiles/
├── bin/                    # Executable wrappers
│   ├── dart                # FVM dart proxy
│   └── flutter             # FVM flutter proxy
├── lib/
│   ├── core/
│   │   ├── dotfiles.sh     # Shell detection and initialization
│   │   └── update.sh       # Update function
│   └── darwin/
│       ├── brew.sh         # Homebrew setup
│       ├── common.sh       # Utility functions (install_devtools, etc.)
│       └── flutter.sh      # Flutter/FVM configuration
├── links/                  # Template files (copied to ~/)
│   ├── bash_profile
│   ├── bashrc
│   ├── zsh_profile
│   └── zshrc
├── setup/
│   ├── install.sh          # Remote installation script
│   └── init.sh             # Local initialization
└── test/                   # Integration tests (Tart VMs)
```

## How It Works

The dotfiles use a **managed section** approach:

1. `init.sh` copies content from `links/` to your home directory (e.g., `links/bashrc` → `~/.bashrc`)
2. Content is wrapped in marker comments: `# >>> DOTFILES MANAGED SECTION ...`
3. Running `up` or `dotfiles_init` replaces only the managed section, preserving your custom configurations

## Testing

Integration tests use [Tart](https://github.com/cirruslabs/tart) to spin up clean macOS VMs:

```bash
# Setup (one-time)
./test/setup-tart.sh

# Run tests
./test/run-integration-tests.sh        # Test both shells
./test/run-integration-tests.sh bash   # Bash only
./test/run-integration-tests.sh zsh    # Zsh only

# Interactive VM for debugging
./test/run-interactive-vm.sh
```

See `test/README.md` for details.

## Troubleshooting

### Homebrew Not Found

The dotfiles auto-detect Homebrew location:
- Apple Silicon: `/opt/homebrew`
- Intel: `/usr/local`

If issues persist, ensure Homebrew is installed:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Flutter Quarantine Issues

macOS blocks downloaded executables. Run:
```bash
bump_flutter
```

### Shell Not Detected Correctly

Check your default shell:
```bash
dscl . -read /Users/$USER UserShell
```

## License

See [LICENSE](LICENSE) file.
