# macpack

A simple macOS development environment setup tool that automates the installation and configuration of essential development tools and applications.

## Features

- 🍺 Automated Homebrew and package management
- 🛠️ Essential development tools and utilities  
- 📱 GUI applications for development
- 🐚 Zsh with Oh My Zsh configuration
- ✨ LunarVim text editor setup
- 🔐 Git and SSH configuration
- 📝 Clean, minimal logging
- 🚀 Two simple profiles: minimal or full-stack

## Quick Start

1. **Clone and setup:**

   ```bash
   cd macpack
   chmod +x scripts/install.sh
   ```
2. **Choose your setup:**
   - **Minimal**: Essential tools + LunarVim
   - **Full-stack**: Everything you need for development

3. **Install:**

   ```bash
   # Minimal setup
   ./scripts/install.sh --profile minimal
   
   # Full development environment
   ./scripts/install.sh --profile full-stack
   
   # See what would be installed first
   ./scripts/install.sh --dry-run --profile full-stack
   ```

## Configuration

Customize your setup by editing files in the `config/` directory:

- `config/packages.yml` - CLI tools and utilities
- `config/casks.yml` - GUI applications
- `config/settings.yml` - General settings

## Design Philosophy

- **Simple and clean**: Minimal, focused logging without verbose output
- **Self-contained**: No external dependencies - everything needed is installed automatically
- **Basic validation**: Uses built-in tools for configuration validation
- **Two clear choices**: Minimal for essentials, full-stack for everything

## Advanced Usage

```bash
# Install specific components only
./scripts/install.sh --components homebrew,cli_tools,zsh_setup

# Update existing installation
./scripts/update.sh

# Get help
./scripts/install.sh --help
```

## Contributing

See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines on contributing to this project.

## License

MIT License - see LICENSE file for details.
