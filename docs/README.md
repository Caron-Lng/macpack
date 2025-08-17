# macpack Documentation

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Profiles](#profiles)
5. [Components](#components)
6. [Troubleshooting](#troubleshooting)

## Overview

macpack is a comprehensive macOS development environment setup tool that automates the installation and configuration of essential development tools, applications, and environments.

### Key Features

- **Profile-based installations**: Choose from predefined profiles or create custom ones
- **Modular components**: Install only what you need
- **YAML configuration**: Easy-to-read and maintain configuration files
- **Dry run support**: Preview installations before executing
- **Backup and restore**: Backup current installations and restore from backups
- **Comprehensive logging**: Detailed logs for troubleshooting

## Installation

### Prerequisites

- macOS 10.15 (Catalina) or later
- Internet connection
- At least 5GB of free disk space

### Quick Start

```bash
# Clone the repository
git clone <your-repo-url> macpack
cd macpack

# Run with minimal profile (default)
./scripts/install.sh

# Or choose a specific profile
# Install with a specific profile
./scripts/install.sh --profile full-stack
```

## Configuration

### Configuration Files

- `config/packages.yml` - CLI tools and dependencies
- `config/casks.yml` - GUI applications
- `config/settings.yml` - General configuration options

### Customizing Packages

Edit `config/packages.yml` to add or remove CLI tools:

```yaml
# Add new category
databases:
  - postgresql
  - redis

# Comment out unwanted packages
# system_info:
#   - macchina
```

### Customizing Applications

Edit `config/casks.yml` to add or remove GUI applications:

```yaml
# Add new applications
browsers:
  - firefox
  - safari-technology-preview

# Comment out unwanted apps
# security:
#   - lulu
```

## Profiles

### Available Profiles

| Profile | Description | Components |
|---------|-------------|------------|
| minimal | Essential development setup with LunarVim | Homebrew, Xcode tools, basic CLI tools, VS Code, iTerm2, LunarVim |
| full-stack | Comprehensive development environment | All tools including web dev, mobile dev, DevOps, databases, and more |

### Creating Custom Profiles

Create a new YAML file in `profiles/` directory:

```yaml
name: "My Custom Profile"
description: "Custom development environment"

settings:
  development:
    install_lunarvim: true
    install_flutter: false

packages:
  version_control:
    - git
  languages:
    - python
    - node

components:
  - homebrew
  - cli_tools
  - zsh_setup
```

## Components

### Available Components

- **homebrew**: Install and configure Homebrew package manager
- **xcode_tools**: Install Xcode Command Line Tools
- **cli_tools**: Install CLI packages from configuration
- **cask_apps**: Install GUI applications via Homebrew Cask
- **zsh_setup**: Configure Zsh with Oh My Zsh and plugins
- **nerd_fonts**: Install Nerd Fonts helper (getnf)
- **lunarvim**: Install and configure LunarVim
- **flutter**: Install Flutter SDK
- **git_ssh**: Configure Git and SSH
- **podman**: Setup Podman container runtime

### Installing Specific Components

```bash
# Install only Homebrew and CLI tools
./scripts/install.sh --components homebrew,cli_tools

# Install multiple components
./scripts/install.sh --components brew,zsh_setup,git_ssh
```

## Advanced Usage

### Dry Run

Preview what would be installed without making changes:

```bash
./scripts/install.sh --dry-run --profile full-stack
```

### Verbose Output

Enable detailed logging:

```bash
./scripts/install.sh --verbose --profile web-dev
```

### Backup and Restore

Create a backup of your current setup:

```bash
./scripts/backup.sh
```

Restore from a backup:

```bash
# Automatic restore script is created with each backup
~/.macpack-backups/backup_YYYYMMDD_HHMMSS/restore.sh
```

### Update Installed Packages

Update all installed packages and tools:

```bash
./scripts/update.sh
```

## Troubleshooting

### Common Issues

1. **Permission errors**: Some operations require administrator privileges
   ```bash
   sudo ./scripts/install.sh
   ```

2. **Network timeouts**: Check your internet connection and retry

3. **Disk space**: Ensure you have at least 5GB of free space

4. **Homebrew conflicts**: Clean up existing Homebrew installation
   ```bash
   brew cleanup
   brew doctor
   ```

### Log Files

Check the log file for detailed error information:

```bash
tail -f ~/.macpack.log
```

### Getting Help

1. Check this documentation
2. Review the log file
3. Run with verbose output: `--verbose`
4. Use dry run to preview: `--dry-run`

### Resetting Installation

If you need to start fresh:

1. Create a backup: `./scripts/backup.sh`
2. Uninstall packages manually or restore from a clean backup
3. Delete log file: `rm ~/.macpack.log`
4. Run installation again

## File Structure

```
macpack/
├── README.md                 # Main documentation
├── scripts/
│   ├── install.sh           # Main installation script
│   ├── update.sh            # Update installed packages
│   ├── backup.sh            # Backup current setup
│   └── lib/                 # Shared library functions
│       ├── logging.sh       # Logging utilities
│       ├── validation.sh    # Input validation
│       └── brew.sh          # Homebrew functions
├── config/
│   ├── packages.yml         # CLI tools configuration
│   ├── casks.yml           # GUI apps configuration
│   └── settings.yml        # General settings
├── profiles/
│   ├── minimal.yml         # Basic profile
│   ├── web-dev.yml         # Web development
│   ├── mobile-dev.yml      # Mobile development
│   └── full-stack.yml      # Complete environment
├── templates/              # Configuration templates
└── docs/                   # Additional documentation
```
