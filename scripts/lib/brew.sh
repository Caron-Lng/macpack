#!/bin/bash

# brew.sh - Homebrew management functions for macpack

# Source required libraries
BREW_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BREW_LIB_DIR/logging.sh"

# Homebrew installation paths
HOMEBREW_PATHS=(
  "/opt/homebrew"           # Apple Silicon Macs
  "/usr/local/Homebrew"     # Intel Macs
  "/home/linuxbrew/.linuxbrew"  # Linux (if supported in future)
)

# Get Homebrew prefix
get_brew_prefix() {
  for path in "${HOMEBREW_PATHS[@]}"; do
    if [[ -d "$path" ]]; then
      echo "$path"
      return 0
    fi
  done
  return 1
}

# Check if Homebrew is installed
is_brew_installed() {
  command_exists brew || [[ -n "$(get_brew_prefix)" ]]
}

# Install Homebrew
install_homebrew() {
  if is_brew_installed; then
    log_info "Homebrew already installed"
    return 0
  fi
  
  log_info "Installing Homebrew..."
  
  # Set environment variable to avoid API issues
  export HOMEBREW_NO_INSTALL_FROM_API=1
  
  # Download and execute Homebrew installer
  if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    log_error "Failed to install Homebrew"
    return 1
  fi
  
  # Add Homebrew to PATH
  setup_brew_environment
  
  log_info "Homebrew installed successfully"
  return 0
}

# Setup Homebrew environment
setup_brew_environment() {
  local brew_prefix
  brew_prefix=$(get_brew_prefix)
  
  if [[ -z "$brew_prefix" ]]; then
    log_error "Homebrew installation not found"
    return 1
  fi
  
  # Add to current session
  eval "$($brew_prefix/bin/brew shellenv)"
  
  # Add to shell profile
  local shell_profile="$HOME/.zprofile"
  local brew_env_line='eval "$('$brew_prefix'/bin/brew shellenv)"'
  
  if [[ -f "$shell_profile" ]] && ! grep -q "brew shellenv" "$shell_profile"; then
    echo "$brew_env_line" >> "$shell_profile"
    log_debug "Added Homebrew to $shell_profile"
  elif [[ ! -f "$shell_profile" ]]; then
    echo "$brew_env_line" > "$shell_profile"
    log_debug "Created $shell_profile with Homebrew environment"
  fi
}

# Update Homebrew
update_homebrew() {
  if ! is_brew_installed; then
    log_error "Homebrew not installed"
    return 1
  fi
  
  log_info "Updating Homebrew..."
  
  if execute_command "brew update" "Updating Homebrew repositories"; then
    log_info "Homebrew updated successfully"
    return 0
  else
    log_error "Failed to update Homebrew"
    return 1
  fi
}

# Install a single package
install_package() {
  local package="$1"
  local package_type="${2:-formula}"  # formula or cask
  
  if [[ -z "$package" ]]; then
    log_error "Package name is required"
    return 1
  fi
  
  log_info "Installing $package_type: $package"
  
  local cmd="brew install"
  if [[ "$package_type" == "cask" ]]; then
    cmd="brew install --cask"
  fi
  
  if execute_command "$cmd $package" "Installing $package"; then
    log_info "Successfully installed: $package"
    return 0
  else
    log_error "Failed to install: $package"
    return 1
  fi
}

# Install multiple packages
install_packages() {
  local packages=("$@")
  local failed_packages=()
  local installed_count=0
  
  if [[ ${#packages[@]} -eq 0 ]]; then
    log_warn "No packages specified for installation"
    return 0
  fi
  
  log_info "Installing ${#packages[@]} packages: ${packages[*]}"
  
  for package in "${packages[@]}"; do
    if install_package "$package"; then
      ((installed_count++))
    else
      failed_packages+=("$package")
    fi
  done
  
  log_info "Installation complete: $installed_count/${#packages[@]} packages installed"
  
  if [[ ${#failed_packages[@]} -gt 0 ]]; then
    log_warn "Failed to install packages: ${failed_packages[*]}"
    return 1
  fi
  
  return 0
}

# Install cask applications
install_casks() {
  local casks=("$@")
  local failed_casks=()
  local installed_count=0
  
  if [[ ${#casks[@]} -eq 0 ]]; then
    log_warn "No casks specified for installation"
    return 0
  fi
  
  log_info "Installing ${#casks[@]} casks: ${casks[*]}"
  
  for cask in "${casks[@]}"; do
    if install_package "$cask" "cask"; then
      ((installed_count++))
    else
      failed_casks+=("$cask")
    fi
  done
  
  log_info "Cask installation complete: $installed_count/${#casks[@]} casks installed"
  
  if [[ ${#failed_casks[@]} -gt 0 ]]; then
    log_warn "Failed to install casks: ${failed_casks[*]}"
    return 1
  fi
  
  return 0
}

# Check if a package is installed
is_package_installed() {
  local package="$1"
  local package_type="${2:-formula}"
  
  if [[ "$package_type" == "cask" ]]; then
    brew list --cask "$package" >/dev/null 2>&1
  else
    brew list "$package" >/dev/null 2>&1
  fi
}

# Get list of installed packages
get_installed_packages() {
  local package_type="${1:-formula}"
  
  if [[ "$package_type" == "cask" ]]; then
    brew list --cask 2>/dev/null | sort
  else
    brew list --formula 2>/dev/null | sort
  fi
}

# Upgrade all packages
upgrade_packages() {
  log_info "Upgrading all Homebrew packages..."
  
  if execute_command "brew upgrade" "Upgrading packages"; then
    log_info "Package upgrade completed"
    return 0
  else
    log_error "Failed to upgrade packages"
    return 1
  fi
}

# Clean up Homebrew cache and old versions
cleanup_homebrew() {
  log_info "Cleaning up Homebrew..."
  
  local cleanup_commands=(
    "brew cleanup --prune=all"
    "brew doctor"
  )
  
  for cmd in "${cleanup_commands[@]}"; do
    if ! execute_command "$cmd" "Running: $cmd"; then
      log_warn "Cleanup command failed: $cmd"
    fi
  done
  
  log_info "Homebrew cleanup completed"
}

# Install packages from YAML configuration
install_from_yaml() {
  local yaml_file="$1"
  local package_type="${2:-packages}"  # packages or casks
  
  if [[ ! -f "$yaml_file" ]]; then
    log_error "Configuration file not found: $yaml_file"
    return 1
  fi
  
  # This is a simplified parser that extracts package names from categories.
  # For more complex YAML files, consider using a dedicated YAML parser.
  local packages=()
  
  # Extract packages from YAML (simplified approach)
  while IFS= read -r line; do
    # Skip comments and empty lines
    if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
      continue
    fi
    
    # Extract package names (lines starting with - followed by package name)
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*([a-zA-Z0-9_-]+) ]]; then
      packages+=("${BASH_REMATCH[1]}")
    fi
  done < "$yaml_file"
  
  if [[ ${#packages[@]} -eq 0 ]]; then
    log_warn "No packages found in $yaml_file"
    return 0
  fi
  
  log_info "Found ${#packages[@]} packages in $yaml_file"
  
  if [[ "$package_type" == "casks" ]]; then
    install_casks "${packages[@]}"
  else
    install_packages "${packages[@]}"
  fi
}

# Backup current package list
backup_package_list() {
  local backup_dir="${1:-$HOME/.macpack-backups}"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  
  mkdir -p "$backup_dir"
  
  local formula_backup="$backup_dir/brew_formulas_$timestamp.txt"
  local cask_backup="$backup_dir/brew_casks_$timestamp.txt"
  
  get_installed_packages "formula" > "$formula_backup"
  get_installed_packages "cask" > "$cask_backup"
  
  log_info "Package lists backed up:"
  log_info "  Formulas: $formula_backup"
  log_info "  Casks: $cask_backup"
}

# Restore packages from backup
restore_from_backup() {
  local formula_file="$1"
  local cask_file="$2"
  
  if [[ -f "$formula_file" ]]; then
    log_info "Restoring formulas from $formula_file"
    local formulas
    formulas=($(cat "$formula_file"))
    install_packages "${formulas[@]}"
  fi
  
  if [[ -f "$cask_file" ]]; then
    log_info "Restoring casks from $cask_file"
    local casks
    casks=($(cat "$cask_file"))
    install_casks "${casks[@]}"
  fi
}

# Check Homebrew health
check_brew_health() {
  log_info "Checking Homebrew health..."
  
  if ! is_brew_installed; then
    log_error "Homebrew is not installed"
    return 1
  fi
  
  execute_command "brew doctor" "Running Homebrew diagnostics"
}
