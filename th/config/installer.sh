#!/bin/bash
ccode() {
    local text="$1"
    printf "\033[37m\033[30;47m$text\033[0m\033[37m\033[0m"
}

ensure_teleport_installed() {
  echo "Fetching latest Teleport version..."
  
  # Get latest version from GitHub releases
  local teleport_version
  teleport_version=$(curl -fsSL "https://api.github.com/repos/gravitational/teleport/releases/latest" | \
    grep '"tag_name":' | \
    sed -E 's/.*"tag_name": "v?([^"]+)".*/\1/' | \
    head -n1)

  if [[ -z "$teleport_version" ]]; then
    echo "Failed to fetch latest version, using fallback version 18.1.7"
    teleport_version="18.1.7"
  else
    printf "\nLatest Teleport version: \033[1;32m$teleport_version\033[0m"
  fi
  
  local pkg_url="https://cdn.teleport.dev/teleport-tools-${teleport_version}.pkg"
  local pkg_file="$HOME/Downloads/teleport-tools-${teleport_version}.pkg"
  
  # Find all tsh installations using which -a
  local existing_paths=()
  
  # Get all tsh binaries in PATH
  if command -v tsh >/dev/null 2>&1; then
    while IFS= read -r path; do
      if [[ -n "$path" ]]; then
        existing_paths+=("$path")
      fi
    done < <(which -a tsh 2>/dev/null)
  fi
  
  if [[ ${#existing_paths[@]} -gt 0 ]]; then
    printf "\n\nFound existing Teleport installations:\n\n"
    for path in "${existing_paths[@]}"; do
      echo "  - $path"
    done
    
    printf "\nWould you like to remove existing versions and install Teleport ${teleport_version}? (y/N): "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
      # Remove Homebrew installation
      if command -v brew >/dev/null 2>&1 && brew list teleport >/dev/null 2>&1; then
        echo "Uninstalling Teleport via Homebrew..."
        brew uninstall teleport 2>/dev/null || true
      fi
      
      echo
      # Remove any remaining binaries
      for path in "${existing_paths[@]}"; do
        if [[ -f "$path" && "$path" != *".app"* ]]; then
          if sudo rm -f "$path"; then
            printf "\n✅ Successfully removed $path"
          else
            printf "\n❌ Failed to remove $path (incorrect password or permission denied)"
            printf "\nYou may need to manually remove: $path"
          fi
        fi
      done
    else
      echo "Keeping existing installation."
      return 0
    fi
  fi
  
  printf "\n\nInstalling Teleport \033[1;32m${teleport_version}\033[0m...\n\n"
  
  # Download the package
  if ! curl -# -fL -o "$pkg_file" "$pkg_url"; then
    printf "\n\n❌ Failed to download Teleport package from $pkg_url"
    return 1
  fi

  echo
  if sudo installer -pkg "$pkg_file" -target / 2>&1; then
    printf "\nTeleport installed successfully."
    
    # Clean up
    rm -f "$pkg_file"
    
    # Verify installation
    echo 
    if command -v tsh >/dev/null 2>&1; then
      local installed_version=$(tsh version --skip-version-check --client | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1)
      if [[ -n "$installed_version" ]]; then
        printf "\nTeleport version: $installed_version"
        printf "\n\n\033[1mNote:\033[0m"
        printf "\nClient automatically re-executes at proxy server version for compatibility."
        printf "\nYour newer version is installed but runtime version matches proxy."
        printf "\nThis ensures compatibility and won't affect usage.\n"
      fi
    else
      echo "❌ Warning: tsh command not found in PATH after installation"
    fi
  else
    echo "Teleport installation failed."
    rm -f "$pkg_file"
    return 1
  fi
}

ensure_teleport_installed
exit 0

ensure_jq_installed() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is not installed."
    echo "Attempting to install jq using Homebrew..."

    if command -v brew >/dev/null 2>&1; then
      brew install jq

      # Verify installation
      if command -v jq >/dev/null 2>&1; then
	echo "jq installed successfully."
      else
	echo "jq installation failed. Please install it manually."
      fi
    else
      echo "Homebrew is not installed. Cannot install jq automatically."
      echo "Please install Homebrew first: https://brew.sh/"
    fi
  else
    echo "jq already installed."
    echo
  fi
}

ensure_mongosh_installed() {
  if ! command -v mongosh >/dev/null 2>&1; then
    echo "mongosh is not installed."
    echo "Attempting to install mongosh using Homebrew..."

    if command -v brew >/dev/null 2>&1; then
      brew install mongosh

      # Verify installation
      if command -v mongosh >/dev/null 2>&1; then
	echo "mongosh installed successfully."
      else
	echo "mongosh installation failed. Please install it manually."
      fi
    else
      echo "Homebrew is not installed. Cannot install mongosh automatically."
      echo "Please install Homebrew first: https://brew.sh/"
    fi
  else
    echo "mongosh already installed."
    echo
  fi
}

ensure_postgresql_installed() {
  if ! command -v psql >/dev/null 2>&1; then
    echo "PostgreSQL (psql) is not installed."
    echo "Attempting to install PostgreSQL using Homebrew..."

    if command -v brew >/dev/null 2>&1; then
      brew install postgresql@14

      # Verify installation
      if command -v psql >/dev/null 2>&1; then
	echo "PostgreSQL installed successfully."
      else
	echo "PostgreSQL installation failed. Please install it manually."
      fi
    else
      echo "Homebrew is not installed. Cannot install PostgreSQL automatically."
      echo "Please install Homebrew first: https://brew.sh/"
    fi
  else
    echo "PostgreSQL already installed."
    echo
  fi
}

# Run the checks
ensure_teleport_installed
ensure_jq_installed
ensure_mongosh_installed
ensure_postgresql_installed
# ================================================================
# 2. Add source command to shell profile
# ================================================================
# Detect brew prefix properly
brew_prefix=$(brew --prefix)

# Define install location
install_location="$brew_prefix/share/th"
helper_script="$install_location/th.sh"

# Detect the current shell
shell_name=$(basename "$SHELL")

if [ "$shell_name" == "zsh" ]; then
    shell_profile="$HOME/.zshrc" 
else [ "$shell_name" == "bash" ];
    shell_profile="$HOME/.bash_profile"
fi

line_to_add="source $helper_script"

# Only add if not already present
if ! grep -Fxq "$line_to_add" "$shell_profile"; then
    echo "$line_to_add" >> "$shell_profile"
    echo "Added source line to $shell_profile"
else
    echo "Source line already exists in $shell_profile"
    echo
fi

echo "th installed successfully!"
echo "source $shell_profile && th" | pbcopy
printf "\n\033[37m\033[30;47msource $shell_profile && th\033[0m\033[37m\033[0m has been copied to clipboard.\n"
printf "\nPress "
ccode "Crtl + V"
printf " then hit "
ccode "Enter" 
printf " to get started!.\n"