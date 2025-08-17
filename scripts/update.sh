#!/bin/bash

# update.sh - Update installed packages and tools

set -euo pipefail

# Get script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source library functions
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/brew.sh"

# Initialize logging
init_logging

log_section "macpack Update - Updating installed packages and tools"

# Update Homebrew
if is_brew_installed; then
  log_info "Updating Homebrew packages..."
  update_homebrew
  upgrade_packages
  cleanup_homebrew
else
  log_warn "Homebrew not installed, skipping package updates"
fi

# Update Oh My Zsh
if [[ -d "${ZSH:-$HOME/.oh-my-zsh}" ]]; then
  log_info "Updating Oh My Zsh..."
  execute_command "cd ${ZSH:-$HOME/.oh-my-zsh} && git pull" "Updating Oh My Zsh"
  
  # Update plugins
  local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  for plugin_dir in "$custom_dir/plugins"/* "$custom_dir/themes"/*; do
    if [[ -d "$plugin_dir/.git" ]]; then
      local plugin_name=$(basename "$plugin_dir")
      execute_command "cd '$plugin_dir' && git pull" "Updating $plugin_name" || log_warn "Failed to update $plugin_name"
    fi
  done
else
  log_warn "Oh My Zsh not installed, skipping"
fi

# Update LunarVim
if command_exists lvim; then
  log_info "Updating LunarVim..."
  execute_command "lvim --headless +LvimUpdate +qa" "Updating LunarVim" || log_warn "LunarVim update failed"
else
  log_warn "LunarVim not installed, skipping"
fi

# Update Flutter
if command_exists flutter; then
  log_info "Updating Flutter..."
  execute_command "flutter upgrade" "Updating Flutter SDK"
  execute_command "flutter doctor" "Running Flutter doctor"
else
  log_warn "Flutter not installed, skipping"
fi

# Update Podman
if command_exists podman; then
  log_info "Updating Podman machine..."
  execute_command "podman machine stop" "Stopping Podman machine" || log_debug "Podman machine already stopped"
  execute_command "podman machine start" "Starting Podman machine" || log_warn "Failed to start Podman machine"
else
  log_warn "Podman not installed, skipping"
fi

log_info "Update completed! 🚀"
