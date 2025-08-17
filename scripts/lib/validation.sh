#!/bin/bash

# validation.sh - Input validation and system checks for macpack

# Source logging functions
VALIDATION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$VALIDATION_LIB_DIR/logging.sh"

# Check if running on macOS
validate_macos() {
  if [[ "$(uname)" != "Darwin" ]]; then
    log_fatal "This script is designed for macOS only. Detected: $(uname)"
  fi
  log_debug "Validated: Running on macOS"
}

# Check macOS version compatibility
validate_macos_version() {
  local min_version="${1:-10.15}"
  local current_version
  current_version=$(sw_vers -productVersion)
  
  if ! command_exists python3; then
    log_warn "Python3 not available for version comparison, skipping version check"
    return 0
  fi
  
  if python3 -c "
import sys
from packaging import version
current = version.parse('$current_version')
minimum = version.parse('$min_version')
sys.exit(0 if current >= minimum else 1)
" 2>/dev/null; then
    log_debug "Validated: macOS version $current_version >= $min_version"
  else
    log_debug "macOS version $current_version may not be fully supported (minimum: $min_version)"
  fi
}

# Check available disk space
validate_disk_space() {
  local required_gb="${1:-5}"
  local available_gb
  
  # Get available space in GB
  available_gb=$(df -g / | awk 'NR==2 {print $4}')
  
  if [[ $available_gb -lt $required_gb ]]; then
    log_fatal "Insufficient disk space. Required: ${required_gb}GB, Available: ${available_gb}GB"
  fi
  
  log_debug "Validated: Sufficient disk space (${available_gb}GB available, ${required_gb}GB required)"
}

# Check internet connectivity
validate_internet() {
  local test_urls=("https://google.com" "https://github.com" "https://brew.sh")
  
  for url in "${test_urls[@]}"; do
    if curl -s --max-time 10 --head "$url" >/dev/null 2>&1; then
      log_debug "Validated: Internet connectivity to $url"
      return 0
    fi
  done
  
  log_fatal "No internet connectivity detected. Please check your network connection."
}

# Validate YAML file syntax
validate_yaml() {
  local file="$1"
  
  if [[ ! -f "$file" ]]; then
    log_error "YAML file not found: $file"
    return 1
  fi
  
  log_debug "Performing YAML syntax validation for $file"
  
  # Basic syntax validation (no external dependencies)
  local line_num=0
  local has_errors=false
  
  while IFS= read -r line; do
    ((line_num++))
    
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    
    # Check for tabs (YAML requires spaces)
    if [[ "$line" =~ $'\t' ]]; then
      log_error "YAML syntax error in $file:$line_num - Contains tabs (use spaces for indentation)"
      has_errors=true
    fi
    
    # Check for missing colons after keys (basic check)
    if [[ "$line" =~ ^[[:space:]]*[a-zA-Z0-9_-]+[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]]*-[[:space:]]+ ]]; then
      log_error "YAML syntax error in $file:$line_num - Missing colon after key: $line"
      has_errors=true
    fi
    
    # Check for empty list items
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*$ ]]; then
      log_error "YAML syntax error in $file:$line_num - Empty list item"
      has_errors=true
    fi
    
    # Check for basic indentation consistency (2 spaces per level)
    if [[ "$line" =~ ^([[:space:]]+) ]]; then
      local indent="${BASH_REMATCH[1]}"
      local indent_length=${#indent}
      if (( indent_length % 2 != 0 )); then
        log_warn "YAML style warning in $file:$line_num - Inconsistent indentation (use 2 spaces per level)"
      fi
    fi
    
  done < "$file"
  
  if [[ "$has_errors" == "true" ]]; then
    return 1
  fi
  
  # Enhanced validation with PyYAML if available (non-blocking)
  if command_exists python3 && python3 -c "import yaml" 2>/dev/null; then
    if python3 -c "
import yaml, sys
try:
    with open('$file', 'r') as f:
        yaml.safe_load(f)
    sys.exit(0)
except yaml.YAMLError as e:
    print(f'YAML syntax error: {e}')
    sys.exit(1)
except Exception as e:
    print(f'Error reading file: {e}')
    sys.exit(1)
" 2>/dev/null; then
      log_debug "Enhanced YAML validation passed for $file"
    else
      log_error "Enhanced YAML validation failed for $file"
      return 1
    fi
  else
    log_debug "Using basic YAML validation for $file (PyYAML not available)"
  fi
  
  log_debug "YAML validation completed successfully for $file"
  return 0
}

# Validate file exists and is readable
validate_file() {
  local file="$1"
  local description="${2:-file}"
  
  if [[ ! -f "$file" ]]; then
    log_error "$description not found: $file"
    return 1
  fi
  
  if [[ ! -r "$file" ]]; then
    log_error "$description is not readable: $file"
    return 1
  fi
  
  log_debug "Validated: $description exists and is readable: $file"
  return 0
}

# Validate directory exists and is writable
validate_directory() {
  local dir="$1"
  local description="${2:-directory}"
  local create_if_missing="${3:-false}"
  
  if [[ ! -d "$dir" ]]; then
    if [[ "$create_if_missing" == "true" ]]; then
      log_info "Creating $description: $dir"
      mkdir -p "$dir" || {
        log_error "Failed to create $description: $dir"
        return 1
      }
    else
      log_error "$description not found: $dir"
      return 1
    fi
  fi
  
  if [[ ! -w "$dir" ]]; then
    log_error "$description is not writable: $dir"
    return 1
  fi
  
  log_debug "Validated: $description exists and is writable: $dir"
  return 0
}

# Validate email format
validate_email() {
  local email="$1"
  local regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
  
  if [[ $email =~ $regex ]]; then
    log_debug "Validated: Email format: $email"
    return 0
  else
    log_error "Invalid email format: $email"
    return 1
  fi
}

# Validate Git configuration
validate_git_config() {
  local name="$1"
  local email="$2"
  
  if [[ -z "$name" ]]; then
    log_error "Git name cannot be empty"
    return 1
  fi
  
  if [[ -z "$email" ]]; then
    log_error "Git email cannot be empty"
    return 1
  fi
  
  if ! validate_email "$email"; then
    return 1
  fi
  
  log_debug "Validated: Git configuration - name: '$name', email: '$email'"
  return 0
}

# Check if user has admin privileges
validate_admin() {
  if ! sudo -n true 2>/dev/null; then
    log_info "This script may require administrator privileges for some operations"
    log_info "You may be prompted for your password"
    
    # Test sudo access
    if ! sudo -v; then
      log_fatal "Administrator privileges required but not available"
    fi
  fi
  
  log_debug "Validated: Administrator privileges available"
}

# Validate profile configuration
validate_profile() {
  local profile_file="$1"
  
  validate_file "$profile_file" "Profile file" || return 1
  validate_yaml "$profile_file" || return 1
  
  # Additional profile-specific validation could go here
  # e.g., check that required fields exist, validate component names, etc.
  
  log_debug "Validated: Profile configuration: $profile_file"
  return 0
}

# Run comprehensive system validation
validate_system() {
  validate_macos
  validate_macos_version
  validate_disk_space
  validate_internet
  
  # Optional validations based on requirements
  if [[ "${REQUIRE_ADMIN:-false}" == "true" ]]; then
    validate_admin
  fi
  
  log_info "System validation completed"
}

# Validate all configuration files in a directory
validate_config_files() {
  local config_dir="$1"
  local errors=0
  
  validate_directory "$config_dir" "Configuration directory" || return 1
  
  # Validate YAML files
  while IFS= read -r -d '' file; do
    if ! validate_yaml "$file"; then
      ((errors++))
    fi
  done < <(find "$config_dir" -name "*.yml" -o -name "*.yaml" -print0)
  
  if [[ $errors -gt 0 ]]; then
    log_error "Found $errors configuration file errors"
    return 1
  fi
  
  log_info "All configuration files validated successfully"
  return 0
}
