# darwin_dotfiles

Bash/Zsh profile configuration for macOS (Darwin) based devices. This repository provides a comprehensive set of dotfiles for macOS development environments, with extensive support for Dart/Flutter development.

## Features

- **Shell Support**: Works with both Bash and Zsh
- **Architecture Support**: Handles both Apple Silicon (ARM64) and Intel (x86_64) Macs
- **Development Tools**: Pre-configured for:
  - Flutter/FVM
- **Git Integration**: Custom aliases and helper functions
- **Custom Prompt**: Git-aware PS1 with branch and dirty status
- **Homebrew Integration**: Automatic detection and setup

## Prerequisites

- macOS (Darwin)
- Git (for installation)
- Internet connection (for cloning repository and installing tools)

## Installation

### Quick Start

Run the installation script:

```bash
/bin/bash <(curl -fsSL https://raw.githubusercontent.com/jlaboll/darwin_dotfiles/main/setup/install.sh)
```

Or manually:

```bash
git clone git@github.com:jlaboll/darwin_dotfiles.git ~/.darwin_dotfiles
~/.darwin_dotfiles/setup/init.sh
```

### Manual Installation

1. Clone the repository:
   ```bash
   git clone git@github.com:jlaboll/darwin_dotfiles.git ~/.darwin_dotfiles
   ```

2. Run initialization:
   ```bash
   ~/.darwin_dotfiles/setup/init.sh
   ```

3. Restart your terminal or source your profile:
   ```bash
   source ~/.bash_profile  # for bash
   # or
   source ~/.zsh_profile   # for zsh
   ```

## Configuration

### Environment Variables

The dotfiles use several environment variables to control behavior:

- `DOTFILES_ROOT`: Path to dotfiles directory (default: `$HOME/.darwin_dotfiles`)
- `DOTFILES_PS1`: If set to `0`, enables custom prompt (default: disabled)
- `DOTFILE_EXPORTS`: If set to `0`, forces custom exports for `VISUAL`, `CLICOLOR`, `LSCOLORS`, `PAGER`, and `LESS` (default: disabled)

### Flags (Optional)

Set these variables in your `~/.profile` or `~/.zprofile`:

```bash
# Disable custom prompt
export DOTFILES_PS1=1

# Enable custom exports
export DOTFILE_EXPORTS=0
```

## Usage

### Available Functions

#### `dotfiles_init`
Reinitializes dotfiles by copying files from `links/` to your home directory.

```bash
dotfiles_init
```

#### `up`
Updates dotfiles from git repository and reinitializes.

```bash
up
```

#### `install_devtools`
Installs development tools via Homebrew (Homebrew, Flutter/FVM, jq).

```bash
install_devtools        # add `-v` for verbose
```

#### `bump_flutter`
Updates Flutter installation and clears macOS quarantine flags.

```bash
bump_flutter
```

#### `unquarantine_flutter`
Removes macOS quarantine attributes from Flutter executables.

```bash
unquarantine_flutter "/path/to/flutter/root"
```

### Git Aliases

- `ga` - `git add -A` (stage all changes)
- `gb` - `git branch --list` (list branches)
- `gc` - `git commit -am` (commit all changes with message)
- `gs` - `git status` (show status)
- `gp` - `git push` (push to remote)

### Git Functions

- `gi "git@github.com:user/repo.git"` - Initialize new git repo with standard setup
- `grm "path/to/file"` - Remove file from git tracking
- `gu` - Update repository (pull and fetch with submodule support)

## Project Structure

```
darwin_dotfiles/
├── bin/                    # Executable wrappers (dart, flutter)
├── lib/
│   ├── core/              # Core functions
│   │   ├── dotfiles.sh    # Shell detection and initialization
│   │   ├── exports.sh      # Environment variable exports
│   │   ├── git.sh         # Git aliases and functions
│   │   └── update.sh      # Update function
│   └── darwin/            # macOS-specific configurations
│       ├── brew.sh        # Homebrew setup
│       ├── common.sh      # Common utility functions
│       ├── flutter.sh     # Flutter/FVM configuration
│       ├── ps1.sh         # Custom prompt
├── links/                 # Template files copied to home directory
│   ├── bash_profile
│   ├── bashrc
│   ├── zsh_profile
│   └── zshrc
├── setup/                 # Installation scripts
│   ├── install.sh        # Main installation script
│   └── init.sh           # Initialization script
└── README.md
```

## Troubleshooting

### Installation Fails

**Problem**: Git clone fails with SSH error  
**Solution**: The installer automatically falls back to HTTPS. If both fail, check your internet connection and GitHub access.

**Problem**: `DOTFILES_ROOT` not found  
**Solution**: Ensure the repository was cloned successfully. Check that `~/.darwin_dotfiles` exists.

### Shell Detection Issues

**Problem**: Wrong profile file is sourced  
**Solution**: The script uses macOS Directory Services to detect your default shell. Check with:
```bash
dscl . -read /Users/$USER UserShell
```

### Homebrew Not Found

**Problem**: Homebrew commands fail  
**Solution**: The dotfiles automatically detect Homebrew location. If issues persist:
1. Ensure Homebrew is installed: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
2. Check architecture: Apple Silicon uses `/opt/homebrew`, Intel uses `/usr/local`

### PATH Issues

**Problem**: Commands not found after installation  
**Solution**: 
1. Restart your terminal
2. Or source your profile: `source ~/.bash_profile` or `source ~/.zsh_profile`
3. Check that `DOTFILES_ROOT` is set correctly

### Flutter Quarantine Issues

**Problem**: Flutter commands blocked by macOS  
**Solution**: Run `bump-flutter` to update Flutter and clear quarantine flags.

## Customization

### Adding Custom Configuration

1. Edit files in `links/` directory
2. Run `dotfiles-init` to apply changes
3. Or edit files directly in `~/.bashrc` or `~/.zshrc`

### Modifying Prompt

Edit `lib/darwin/ps1.sh` to customize the prompt appearance.

### Adding New Tools

1. Create a new file in `lib/darwin/` for your tool
2. Add sourcing to `links/bashrc` and `links/zshrc`
3. Run `dotfiles-init`

## Updating

To update your dotfiles:

```bash
up
```

This will pull the latest changes from the repository and reinitialize your dotfiles.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on both bash and zsh
5. Submit a pull request

## License

See [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or contributions, please open an issue on GitHub.
