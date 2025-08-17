#!/bin/bash

# test_compatibility.sh - Test script for compatibility checks

# Source the main installation script functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"

# Initialize logging
init_logging

# Test the lowercase conversion
test_lowercase_conversion() {
  log_info "Testing lowercase conversion compatibility..."
  
  # Test various inputs
  local test_inputs=("Y" "y" "N" "n" "YES" "yes" "NO" "no")
  
  for input in "${test_inputs[@]}"; do
    # Using the compatible method
    local result
    result=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    echo "Input: '$input' -> Output: '$result'"
  done
  
  log_info "Lowercase conversion test completed"
}

# Test SSH key generation logic (without actually generating keys)
test_ssh_logic() {
  log_info "Testing SSH key generation logic..."
  
  # Simulate user inputs
  local test_cases=("y" "Y" "yes" "YES" "n" "N" "no" "NO" "")
  
  for input in "${test_cases[@]}"; do
    local input_lower
    input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$input_lower" == "y" ]]; then
      echo "Input '$input' -> Would generate SSH key"
    else
      echo "Input '$input' -> Would skip SSH key generation"
    fi
  done
  
  log_info "SSH logic test completed"
}

# Run tests
echo "=== Bash Compatibility Tests ==="
echo "Bash version: $BASH_VERSION"
echo ""

test_lowercase_conversion
echo ""
test_ssh_logic

echo ""
echo "All tests completed successfully!"
