#!/bin/bash

# dependencies.sh - Self-contained dependency management for macpack

# Source required libraries
DEPS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DEPS_LIB_DIR/logging.sh"

# Prevent multiple sourcing
if [[ -n "${MACPACK_DEPENDENCIES_LOADED:-}" ]]; then
  return 0
fi
readonly MACPACK_DEPENDENCIES_LOADED=true

# Install Python packages without requiring pip to be pre-installed
install_python_package() {
  local package="$1"
  local install_user="${2:-true}"
  
  if [[ -z "$package" ]]; then
    log_error "Package name is required"
    return 1
  fi
  
  # Check if package is already installed
  if python3 -c "import $package" 2>/dev/null; then
    log_debug "Python package already installed: $package"
    return 0
  fi
  
  log_info "Installing Python package: $package"
  
  # Ensure pip is available
  if ! command_exists pip3; then
    log_info "pip3 not found, installing pip..."
    
    # Download and install pip if not available
    if ! python3 -m ensurepip --user 2>/dev/null; then
      # Alternative method: download get-pip.py
      local temp_dir
      temp_dir=$(mktemp -d)
      
      if curl -fsSL https://bootstrap.pypa.io/get-pip.py -o "$temp_dir/get-pip.py"; then
        if [[ "$install_user" == "true" ]]; then
          python3 "$temp_dir/get-pip.py" --user
        else
          python3 "$temp_dir/get-pip.py"
        fi
        rm -rf "$temp_dir"
      else
        log_error "Failed to download pip installer"
        rm -rf "$temp_dir"
        return 1
      fi
    fi
  fi
  
  # Install the package
  local pip_cmd="pip3 install"
  if [[ "$install_user" == "true" ]]; then
    pip_cmd="$pip_cmd --user"
  fi
  
  if $pip_cmd "$package" >/dev/null 2>&1; then
    log_info "Successfully installed Python package: $package"
    return 0
  else
    log_error "Failed to install Python package: $package"
    return 1
  fi
}

# Install Command Line Tools without requiring Xcode to be pre-installed
install_command_line_tools() {
  if xcode-select -p >/dev/null 2>&1; then
    log_info "Command Line Tools already installed"
    return 0
  fi
  
  log_info "Installing Command Line Tools..."
  
  # Touch the file that triggers the installation
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  
  # Find the Command Line Tools update
  local cmd_line_tools
  cmd_line_tools=$(softwareupdate -l 2>/dev/null | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^C]* //')
  
  if [[ -n "$cmd_line_tools" ]]; then
    log_info "Installing: $cmd_line_tools"
    if softwareupdate -i "$cmd_line_tools" --verbose; then
      log_info "Command Line Tools installed successfully"
      rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
      return 0
    else
      log_warn "Automated installation failed, trying interactive installation"
      rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    fi
  fi
  
  # Fall back to interactive installation
  log_info "Starting interactive Command Line Tools installation..."
  xcode-select --install
  
  # Wait for installation to complete
  log_info "Waiting for Command Line Tools installation to complete..."
  log_info "Please follow the prompts in the dialog box that appeared"
  
  while ! xcode-select -p >/dev/null 2>&1; do
    sleep 5
  done
  
  log_info "Command Line Tools installation completed"
  return 0
}

# Install Git if not available (required for many operations)
ensure_git() {
  if command_exists git; then
    log_debug "Git already available"
    return 0
  fi
  
  log_info "Git not found, installing via Command Line Tools..."
  install_command_line_tools
  
  if command_exists git; then
    log_info "Git is now available"
    return 0
  else
    log_error "Git installation failed"
    return 1
  fi
}

# Install curl if not available (should be available on macOS by default)
ensure_curl() {
  if command_exists curl; then
    log_debug "curl already available"
    return 0
  fi
  
  log_error "curl not found - this is unexpected on macOS"
  log_info "Attempting to install via Command Line Tools..."
  install_command_line_tools
  
  if command_exists curl; then
    log_info "curl is now available"
    return 0
  else
    log_fatal "curl installation failed - cannot proceed without curl"
  fi
}

# Ensure Python 3 is available
ensure_python3() {
  if command_exists python3; then
    log_debug "Python 3 already available"
    return 0
  fi
  
  log_info "Python 3 not found, installing via Command Line Tools..."
  install_command_line_tools
  
  if command_exists python3; then
    log_info "Python 3 is now available"
    return 0
  else
    log_warn "Python 3 not available after Command Line Tools installation"
    log_info "Python 3 will be installed via Homebrew later in the process"
    return 1
  fi
}

# Install essential dependencies required for the setup process
install_essential_dependencies() {
  # Core utilities that should be available on macOS
  ensure_curl
  
  # Git is essential for many operations
  ensure_git
  
  # Python 3 for enhanced validation (optional, but don't install extra packages)
  ensure_python3 >/dev/null 2>&1
}

# Check if all required system utilities are available
validate_system_utilities() {
  local missing_utilities=()
  local required_utilities=("curl" "grep" "sed" "awk" "tr" "sort" "uniq" "head" "tail")
  
  for utility in "${required_utilities[@]}"; do
    if ! command_exists "$utility"; then
      missing_utilities+=("$utility")
    fi
  done
  
  if [[ ${#missing_utilities[@]} -gt 0 ]]; then
    log_error "Missing required utilities: ${missing_utilities[*]}"
    log_info "Installing Command Line Tools..."
    install_command_line_tools
    
    # Re-check
    local still_missing=()
    for utility in "${missing_utilities[@]}"; do
      if ! command_exists "$utility"; then
        still_missing+=("$utility")
      fi
    done
    
    if [[ ${#still_missing[@]} -gt 0 ]]; then
      log_fatal "Still missing utilities after installation: ${still_missing[*]}"
    fi
  fi
}

# Bootstrap function to ensure the system is ready for setup
bootstrap_system() {
  # Validate basic system utilities
  validate_system_utilities
  
  # Install essential dependencies
  install_essential_dependencies
  
  log_info "System bootstrap completed"
}
