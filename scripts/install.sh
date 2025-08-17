#!/bin/bash

# install.sh - Modular macOS development environment setup script
# Version: 2.0.0

# Ensure we're running with bash and handle older versions
if [ -z "$BASH_VERSION" ]; then
  echo "This script requires Bash. Re-running with bash..."
  exec bash "$0" "$@"
fi

set -euo pipefail

# Script metadata
readonly SCRIPT_VERSION="0.5.0"
readonly SCRIPT_NAME="macpack"

# Get script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source library functions
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/dependencies.sh"
source "$SCRIPT_DIR/lib/validation.sh"
source "$SCRIPT_DIR/lib/brew.sh"

# Default configuration
readonly DEFAULT_PROFILE="minimal"
readonly CONFIG_DIR="$PROJECT_ROOT/config"
readonly PROFILES_DIR="$PROJECT_ROOT/profiles"

# Global variables
PROFILE=""
COMPONENTS=()
DRY_RUN=false
VERBOSE=false
CONTINUE_ON_ERROR=true

# Display usage information
usage() {
  cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION - macOS Development Environment Setup

USAGE:
  $0 [OPTIONS]

OPTIONS:
  -p, --profile PROFILE     Use predefined profile (minimal, full-stack)
  -c, --components LIST     Install specific components only (comma-separated)
  -d, --dry-run            Show what would be installed without executing
  -v, --verbose            Enable verbose output
  -h, --help               Show this help message
      --no-error-exit      Continue installation even if some components fail
      --log-level LEVEL    Set log level (debug, info, warn, error)

EXAMPLES:
  $0                                    # Install minimal profile
  $0 --profile full-stack              # Install comprehensive development environment
  $0 --components brew,cli,zsh         # Install specific components only
  $0 --dry-run --profile full-stack    # Preview full-stack installation

AVAILABLE PROFILES:
  minimal      Essential development tools with LunarVim
  full-stack   Comprehensive development environment with all tools

AVAILABLE COMPONENTS:
  homebrew     Install and configure Homebrew
  xcode_tools  Install Xcode Command Line Tools
  cli_tools    Install CLI packages from configuration
  cask_apps    Install GUI applications via Homebrew Cask
  zsh_setup    Configure Zsh with Oh My Zsh and plugins
  nerd_fonts   Install Nerd Fonts helper
  lunarvim     Install and configure LunarVim
  flutter      Install Flutter SDK
  git_ssh      Configure Git and SSH
  podman       Setup Podman container runtime

EOF
}

# Parse command line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -p|--profile)
        PROFILE="$2"
        shift 2
        ;;
      -c|--components)
        IFS=',' read -ra COMPONENTS <<< "$2"
        shift 2
        ;;
      -d|--dry-run)
        DRY_RUN=true
        shift
        ;;
      -v|--verbose)
        VERBOSE=true
        set_log_level debug
        shift
        ;;
      --no-error-exit)
        CONTINUE_ON_ERROR=true
        shift
        ;;
      --log-level)
        set_log_level "$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
  
  # Set default profile if none specified
  if [[ -z "$PROFILE" ]] && [[ ${#COMPONENTS[@]} -eq 0 ]]; then
    PROFILE="$DEFAULT_PROFILE"
  fi
}

# Load profile configuration
load_profile() {
  local profile_file="$PROFILES_DIR/${PROFILE}.yml"
  
  if [[ ! -f "$profile_file" ]]; then
    log_fatal "Profile not found: $PROFILE (expected: $profile_file)"
  fi
  
  validate_profile "$profile_file"
  
  log_info "Loading profile: $PROFILE"
  
  # This is a simplified profile loader
  # In a real implementation, you'd want a proper YAML parser
  
  # Extract components from profile if not specified via command line
  if [[ ${#COMPONENTS[@]} -eq 0 ]]; then
    # Simple extraction of components from YAML
    while IFS= read -r line; do
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*([a-zA-Z_]+)[[:space:]]*$ ]]; then
        COMPONENTS+=("${BASH_REMATCH[1]}")
      fi
    done < <(sed -n '/^components:/,/^[^[:space:]]/p' "$profile_file" | grep '^[[:space:]]*-')
  fi
  
  log_debug "Profile loaded with components: ${COMPONENTS[*]}"
}

# Install Xcode Command Line Tools
install_xcode_tools() {
  log_info "Installing Xcode Command Line Tools..."
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY RUN] Would install Xcode Command Line Tools"
    return 0
  fi
  
  install_command_line_tools
}

# Install CLI tools from configuration
install_cli_tools() {
  log_info "Installing CLI tools..."
  
  local packages_file="$CONFIG_DIR/packages.yml"
  
  if [[ ! -f "$packages_file" ]]; then
    log_warn "Packages configuration not found: $packages_file"
    return 0
  fi
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY RUN] Would install CLI tools from $packages_file"
    return 0
  fi
  
  install_from_yaml "$packages_file" "packages"
}

# Install GUI applications from configuration
install_cask_apps() {
  log_info "Installing GUI applications..."
  
  local casks_file="$CONFIG_DIR/casks.yml"
  
  if [[ ! -f "$casks_file" ]]; then
    log_warn "Casks configuration not found: $casks_file"
    return 0
  fi
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY RUN] Would install GUI applications from $casks_file"
    return 0
  fi
  
  install_from_yaml "$casks_file" "casks"
}

# Setup Zsh with Oh My Zsh
setup_zsh() {
  log_info "Setting up Zsh environment..."
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY RUN] Would setup Zsh with Oh My Zsh and plugins"
    return 0
  fi
  
  # Install Oh My Zsh if not present
  if [[ ! -d "${ZSH:-$HOME/.oh-my-zsh}" ]]; then
    log_info "Installing Oh My Zsh..."
    ZSH="$HOME/.oh-my-zsh" RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended
  else
    log_info "Oh My Zsh already installed"
  fi
  
  # Install plugins
  local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  
  git clone https://github.com/zsh-users/zsh-autosuggestions "$custom_dir/plugins/zsh-autosuggestions" 2>/dev/null || log_debug "zsh-autosuggestions already installed"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$custom_dir/plugins/zsh-syntax-highlighting" 2>/dev/null || log_debug "zsh-syntax-highlighting already installed"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$custom_dir/themes/powerlevel10k" 2>/dev/null || log_debug "powerlevel10k already installed"
  
  log_info "Zsh setup completed"
}

# Install Nerd Fonts helper
install_nerd_fonts() {
  log_info "Installing Nerd Fonts helper..."
  
  if command_exists getnf; then
    log_info "getnf already installed"
    return 0
  fi
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY RUN] Would install getnf for Nerd Fonts"
    return 0
  fi
  
  execute_command "curl -fsSL https://raw.githubusercontent.com/getnf/getnf/main/install.sh | bash" "Installing getnf"
  log_info "Run 'getnf' to install Nerd Fonts"
}

# Install LunarVim
install_lunarvim() {
  log_info "Installing LunarVim..."
  
  if command_exists lvim; then
    log_info "LunarVim already installed"
    return 0
  fi
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY RUN] Would install LunarVim"
    return 0
  fi
  
  export LV_BRANCH='release-1.4/neovim-0.9'
  execute_command "bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh)" "Installing LunarVim"
}

# Setup Flutter SDK
setup_flutter() {
  log_info "Setting up Flutter SDK..."
  
  local flutter_dir="$HOME/flutterSDK/flutter"
  
  if [[ -d "$flutter_dir" ]]; then
    log_info "Flutter SDK already installed"
    return 0
  fi
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY RUN] Would install Flutter SDK"
    return 0
  fi
  
  mkdir -p "$(dirname "$flutter_dir")"
  execute_command "git clone https://github.com/flutter/flutter.git -b stable '$flutter_dir'" "Installing Flutter SDK"
  
  # Add to PATH
  local shell_profile="$HOME/.zprofile"
  if ! grep -q "flutter/bin" "$shell_profile" 2>/dev/null; then
    echo 'export PATH="$HOME/flutterSDK/flutter/bin:$PATH"' >> "$shell_profile"
  fi
  
  log_info "Run 'flutter doctor' to complete Flutter setup"
}

# Configure Git and SSH
setup_git_ssh() {
  log_info "Configuring Git and SSH..."
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY RUN] Would configure Git and SSH"
    return 0
  fi
  
  # Git configuration (interactive)
  read -p "Enter your Git username (or press Enter to skip): " git_name
  read -p "Enter your Git email (or press Enter to skip): " git_email
  
  if [[ -n "$git_name" ]]; then
    git config --global user.name "$git_name"
    log_info "Set Git username: $git_name"
  fi
  
  if [[ -n "$git_email" ]]; then
    git config --global user.email "$git_email"
    log_info "Set Git email: $git_email"
  fi
  
  # SSH key generation
  read -p "Generate SSH key? (y/N): " generate_ssh
  # Convert to lowercase for compatibility with older Bash versions
  generate_ssh=$(echo "$generate_ssh" | tr '[:upper:]' '[:lower:]')
  if [[ "$generate_ssh" == "y" || "$generate_ssh" == "yes" ]]; then
    local ssh_email="${git_email:-$(whoami)@$(hostname)}"
    read -p "SSH key email [$ssh_email]: " ssh_input
    ssh_email="${ssh_input:-$ssh_email}"
    
    if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
      execute_command "ssh-keygen -t ed25519 -C '$ssh_email' -f '$HOME/.ssh/id_ed25519' -N ''" "Generating SSH key"
      log_info "SSH key generated. Add to GitHub: pbcopy < ~/.ssh/id_ed25519.pub"
    else
      log_info "SSH key already exists"
    fi
  fi
}

# Setup Podman
setup_podman() {
  log_info "Setting up Podman..."
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY RUN] Would setup Podman container runtime"
    return 0
  fi
  
  execute_command "podman machine init" "Initializing Podman machine" || log_debug "Podman machine already initialized"
  execute_command "podman machine start" "Starting Podman machine" || log_debug "Podman machine already running"
  
  if command_exists sudo; then
    execute_command "sudo $(brew --prefix)/bin/podman-mac-helper install" "Installing podman-mac-helper" || log_debug "podman-mac-helper already installed"
  fi
}

# Execute a component installation
execute_component() {
  local component="$1"
  
  log_section "Installing component: $component"
  
  case "$component" in
    homebrew)
      install_homebrew && update_homebrew
      ;;
    xcode_tools)
      install_xcode_tools
      ;;
    cli_tools)
      install_cli_tools
      ;;
    cask_apps)
      install_cask_apps
      ;;
    zsh_setup)
      setup_zsh
      ;;
    nerd_fonts)
      install_nerd_fonts
      ;;
    lunarvim)
      install_lunarvim
      ;;
    flutter)
      setup_flutter
      ;;
    git_ssh)
      setup_git_ssh
      ;;
    podman)
      setup_podman
      ;;
    *)
      log_error "Unknown component: $component"
      return 1
      ;;
  esac
}

# Main installation process
main() {
  # Initialize logging
  init_logging
  
  # Parse command line arguments
  parse_arguments "$@"
  
  # Display banner
  log_section "$SCRIPT_NAME v$SCRIPT_VERSION - macOS Development Environment Setup"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY RUN MODE - No changes will be made"
  fi
  
  # Bootstrap system dependencies first
  if [[ "$DRY_RUN" != "true" ]]; then
    bootstrap_system
  else
    log_info "[DRY RUN] Would bootstrap system dependencies"
  fi
  
  # System validation
  validate_system
  
  # Load profile if specified
  if [[ -n "$PROFILE" ]]; then
    load_profile
  fi
  
  # Validate components
  if [[ ${#COMPONENTS[@]} -eq 0 ]]; then
    log_fatal "No components specified for installation"
  fi
  
  log_info "Components to install: ${COMPONENTS[*]}"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "Dry run completed - no changes made"
    exit 0
  fi
  
  # Execute installation
  local failed_components=()
  
  for component in "${COMPONENTS[@]}"; do
    if execute_component "$component"; then
      log_info "✓ Component completed: $component"
    else
      log_error "✗ Component failed: $component"
      failed_components+=("$component")
      
      if [[ "$CONTINUE_ON_ERROR" != "true" ]]; then
        log_fatal "Installation stopped due to component failure: $component"
      fi
    fi
  done
  
  # Summary
  log_section "Installation Summary"
  
  local successful_count=$((${#COMPONENTS[@]} - ${#failed_components[@]}))
  log_info "Components completed: $successful_count/${#COMPONENTS[@]}"
  
  if [[ ${#failed_components[@]} -gt 0 ]]; then
    log_warn "Failed components: ${failed_components[*]}"
  fi
  
  # Post-installation instructions
  log_info ""
  log_info "Post-installation steps:"
  log_info "1. Restart your terminal or run: source ~/.zprofile && source ~/.zshrc"
  log_info "2. Configure Powerlevel10k: p10k configure"
  log_info "3. Install Nerd Fonts: getnf"
  log_info "4. Check Flutter setup: flutter doctor"
  
  if [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
    log_info "5. Add SSH key to GitHub: pbcopy < ~/.ssh/id_ed25519.pub"
  fi
  
  log_info ""
  log_info "Installation completed! 🎉"
  
  # Exit with error if any components failed
  if [[ ${#failed_components[@]} -gt 0 ]]; then
    exit 1
  fi
}

# Run main function with all arguments
main "$@"
