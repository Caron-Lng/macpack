#!/bin/bash

# backup.sh - Backup current package installations and configurations

set -euo pipefail

# Get script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source library functions
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/brew.sh"
source "$SCRIPT_DIR/lib/validation.sh"

# Default backup directory
readonly DEFAULT_BACKUP_DIR="$HOME/.macpack-backups"
BACKUP_DIR="$DEFAULT_BACKUP_DIR"

usage() {
  cat << EOF
macpack backup - Backup current installations and configurations

USAGE:
  $0 [OPTIONS]

OPTIONS:
  -d, --dir DIRECTORY    Backup directory (default: $DEFAULT_BACKUP_DIR)
  -h, --help            Show this help message

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--dir)
      BACKUP_DIR="$2"
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

# Initialize logging
init_logging

log_section "macpack Backup - Creating system backup"

# Create backup directory
validate_directory "$BACKUP_DIR" "Backup directory" true

# Create timestamped backup subdirectory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_SUBDIR="$BACKUP_DIR/backup_$TIMESTAMP"
mkdir -p "$BACKUP_SUBDIR"

log_info "Creating backup in: $BACKUP_SUBDIR"

# Backup Homebrew packages
if is_brew_installed; then
  log_info "Backing up Homebrew packages..."
  get_installed_packages "formula" > "$BACKUP_SUBDIR/brew_formulas.txt"
  get_installed_packages "cask" > "$BACKUP_SUBDIR/brew_casks.txt"
  execute_command "brew bundle dump --file='$BACKUP_SUBDIR/Brewfile' --force" "Creating Brewfile"
  log_info "Homebrew packages backed up"
else
  log_warn "Homebrew not installed, skipping package backup"
fi

# Backup shell configuration
log_info "Backing up shell configuration..."
for config_file in .zshrc .zprofile .bashrc .bash_profile; do
  if [[ -f "$HOME/$config_file" ]]; then
    cp "$HOME/$config_file" "$BACKUP_SUBDIR/$config_file"
    log_debug "Backed up: $config_file"
  fi
done

# Backup Git configuration
if [[ -f "$HOME/.gitconfig" ]]; then
  cp "$HOME/.gitconfig" "$BACKUP_SUBDIR/.gitconfig"
  log_debug "Backed up: .gitconfig"
fi

# Backup SSH configuration
if [[ -d "$HOME/.ssh" ]]; then
  mkdir -p "$BACKUP_SUBDIR/.ssh"
  # Only backup config and known_hosts, not private keys
  for ssh_file in config known_hosts; do
    if [[ -f "$HOME/.ssh/$ssh_file" ]]; then
      cp "$HOME/.ssh/$ssh_file" "$BACKUP_SUBDIR/.ssh/$ssh_file"
      log_debug "Backed up: .ssh/$ssh_file"
    fi
  done
fi

# Backup LunarVim configuration
if [[ -d "$HOME/.config/lvim" ]]; then
  cp -r "$HOME/.config/lvim" "$BACKUP_SUBDIR/lvim_config"
  log_debug "Backed up: LunarVim configuration"
fi

# Create backup manifest
cat > "$BACKUP_SUBDIR/manifest.txt" << EOF
macpack Backup Manifest
Created: $(date)
System: $(uname -a)
Homebrew: $(command_exists brew && brew --version | head -1 || echo "Not installed")
Shell: $SHELL
User: $(whoami)

Contents:
$(ls -la "$BACKUP_SUBDIR")
EOF

# Create restore script
cat > "$BACKUP_SUBDIR/restore.sh" << 'EOF'
#!/bin/bash
# Auto-generated restore script

echo "macpack Backup Restore"
echo "This script will restore packages and configurations from this backup."
echo "WARNING: This may overwrite your current configurations!"
read -p "Continue? (y/N): " confirm

# Convert to lowercase for compatibility
confirm_lower=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')
if [[ "$confirm_lower" != "y" && "$confirm_lower" != "yes" ]]; then
  echo "Restore cancelled"
  exit 0
fi

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Restore Homebrew packages
if [[ -f "$BACKUP_DIR/Brewfile" ]]; then
  echo "Restoring Homebrew packages..."
  brew bundle install --file="$BACKUP_DIR/Brewfile"
fi

# Restore shell configurations
for config in .zshrc .zprofile .bashrc .bash_profile .gitconfig; do
  if [[ -f "$BACKUP_DIR/$config" ]]; then
    echo "Restoring $config..."
    cp "$BACKUP_DIR/$config" "$HOME/$config"
  fi
done

# Restore SSH configuration
if [[ -d "$BACKUP_DIR/.ssh" ]]; then
  echo "Restoring SSH configuration..."
  mkdir -p "$HOME/.ssh"
  cp -r "$BACKUP_DIR/.ssh"/* "$HOME/.ssh/"
fi

# Restore LunarVim configuration
if [[ -d "$BACKUP_DIR/lvim_config" ]]; then
  echo "Restoring LunarVim configuration..."
  mkdir -p "$HOME/.config"
  cp -r "$BACKUP_DIR/lvim_config" "$HOME/.config/lvim"
fi

echo "Restore completed!"
echo "You may need to restart your terminal for changes to take effect."
EOF

chmod +x "$BACKUP_SUBDIR/restore.sh"

log_info "Backup completed successfully!"
log_info "Backup location: $BACKUP_SUBDIR"
log_info "To restore: $BACKUP_SUBDIR/restore.sh"

# Clean up old backups (keep last 10)
log_info "Cleaning up old backups..."
cd "$BACKUP_DIR"
ls -1t backup_* 2>/dev/null | tail -n +11 | xargs rm -rf 2>/dev/null || true
log_info "Backup cleanup completed"
