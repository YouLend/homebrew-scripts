#!/bin/bash
ccode() {
    local text="$1"
    printf "\033[37m\033[30;47m$text\033[0m\033[37m\033[0m"
}

ensure_teleport_installed() {
  if ! command -v tsh >/dev/null 2>&1; then
    echo "Teleport (tsh) is not installed."
    echo "Attempting to install Teleport using Homebrew..."

    if command -v brew >/dev/null 2>&1; then
      brew install teleport

      # Verify installation
      if command -v tsh >/dev/null 2>&1; then
	echo "Teleport installed successfully."
      else
	echo "Teleport installation failed. Please install it manually."
      fi
    else
      echo "Homebrew is not installed. Cannot install Teleport automatically."
      echo "Please install Homebrew first: https://brew.sh/"
    fi
  fi
  echo
  echo "Teleport already installed." 
  echo 
}

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