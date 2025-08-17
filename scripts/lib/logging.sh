#!/bin/bash

# logging.sh - Centralized logging functions for macpack

# Prevent multiple sourcing
if [[ -n "${MACPACK_LOGGING_LOADED:-}" ]]; then
  return 0
fi
readonly MACPACK_LOGGING_LOADED=true

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Log levels
readonly LOG_DEBUG=0
readonly LOG_INFO=1
readonly LOG_WARN=2
readonly LOG_ERROR=3

# Current log level (can be overridden)
LOG_LEVEL=${LOG_LEVEL:-$LOG_INFO}

# Log file location
LOG_FILE=${LOG_FILE:-"$HOME/.macpack.log"}

# Get timestamp
get_timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

# Write to log file
write_log() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(get_timestamp)
  
  echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Log debug messages
log_debug() {
  if [[ $LOG_LEVEL -le $LOG_DEBUG ]]; then
    echo -e "${BLUE}[DEBUG]${NC} $1" >&2
    write_log "DEBUG" "$1"
  fi
}

# Log info messages
log_info() {
  if [[ $LOG_LEVEL -le $LOG_INFO ]]; then
    echo -e "${GREEN}[INFO]${NC} $1"
    write_log "INFO" "$1"
  fi
}

# Log warning messages
log_warn() {
  if [[ $LOG_LEVEL -le $LOG_WARN ]]; then
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
    write_log "WARN" "$1"
  fi
}

# Log error messages
log_error() {
  if [[ $LOG_LEVEL -le $LOG_ERROR ]]; then
    echo -e "${RED}[ERROR]${NC} $1" >&2
    write_log "ERROR" "$1"
  fi
}

# Log error and exit
log_fatal() {
  log_error "$1"
  exit 1
}

# Log a separator line
log_separator() {
  local char="${1:-=}"
  local length="${2:-60}"
  local line
  line=$(printf "%*s" "$length" | tr ' ' "$char")
  log_info "$line"
}

# Log a section header
log_section() {
  log_separator
  log_info "$1"
  log_separator
}

# Initialize logging
init_logging() {
  local log_dir
  log_dir=$(dirname "$LOG_FILE")
  
  # Create log directory if it doesn't exist
  mkdir -p "$log_dir"
  
  # Rotate log file if it's too large (> 10MB)
  if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0) -gt 10485760 ]]; then
    mv "$LOG_FILE" "$LOG_FILE.old"
  fi
  
  log_info "Logging initialized - log file: $LOG_FILE"
}

# Set log level from string
set_log_level() {
  local level_lower
  level_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  case "$level_lower" in
    debug) LOG_LEVEL=$LOG_DEBUG ;;
    info) LOG_LEVEL=$LOG_INFO ;;
    warn|warning) LOG_LEVEL=$LOG_WARN ;;
    error) LOG_LEVEL=$LOG_ERROR ;;
    *) log_warn "Unknown log level: $1, using INFO" ;;
  esac
}

# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Validate a required command exists
require_command() {
  if ! command_exists "$1"; then
    log_fatal "Required command '$1' not found. Please install it first."
  fi
}

# Execute a command with logging
execute_command() {
  local cmd="$1"
  local description="${2:-$cmd}"
  
  log_info "Executing: $description"
  log_debug "Command: $cmd"
  
  if eval "$cmd"; then
    log_debug "Command succeeded: $cmd"
    return 0
  else
    local exit_code=$?
    log_error "Command failed with exit code $exit_code: $cmd"
    return $exit_code
  fi
}

# Execute a command with output capture
execute_with_output() {
  local cmd="$1"
  local description="${2:-$cmd}"
  local output
  
  log_info "Executing: $description"
  log_debug "Command: $cmd"
  
  if output=$(eval "$cmd" 2>&1); then
    log_debug "Command output: $output"
    echo "$output"
    return 0
  else
    local exit_code=$?
    log_error "Command failed with exit code $exit_code: $cmd"
    log_error "Output: $output"
    return $exit_code
  fi
}
