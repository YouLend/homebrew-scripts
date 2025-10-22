#!/bin/bash
# Helpers
ccode() {
    local text="$1"
    printf "\033[37m\033[30;47m$text\033[0m\033[37m\033[0m"
}

create_header() {
    local header_text="$1"
    local center_spaces="$2"
    local remove_new_line="$3"
    local header_length=${#header_text}

    local total_dash_count=$((52))
    local available_dash_count=$((total_dash_count - (header_length - 5)))
    
    # If text is longer than original, use minimum dashes
    if [ $available_dash_count -lt 2 ]; then
        available_dash_count=2
    fi
    
    local left_dashes=$((available_dash_count / 2))
    local right_dashes=$((available_dash_count - left_dashes))
    
    local left_dash_str=$(printf '━%.0s' $(seq 1 $left_dashes))
    local right_dash_str=$(printf '━%.0s' $(seq 1 $right_dashes))
    if [[ -z $remove_new_line ]]; then printf "\n"; fi
    printf "\033[0m\033[38;5;245m%s    ▄███████▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀███████████▀\033[0m\033[1;34m\033[0m\n" "$center_spaces"
    printf "\033[0m\033[38;5;245m%s  \033[0m\033[1m%s %s\033[0m\033[38;1m %s \033[0m\033[1;34m\033[0m\n" "$center_spaces" "$left_dash_str" "$header_text" "$right_dash_str"
    printf "\033[0m\033[38;5;245m%s▄███████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄███████▀\033[0m\033[1;34m\033[0m\n\n" "$center_spaces"
}

show_progress_bar() {
    local current=$1
    local total=$2
    local width=30
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r"
    printf "%*s" $completed | tr ' ' '█'
    printf "%*s" $remaining | tr ' ' '░'
    printf " %d%%" $percentage
}

install_with_progress() {
    local package_name="$1"
    local display_name="$2"
    local temp_file=$(mktemp)
    
    # Clear the current line and show installing status
    printf "\033[2K\r  • %-15s " "$display_name"
    show_progress_bar 0 100
    
    # Start brew install and capture ALL output (stdout and stderr)
    if HOMEBREW_NO_ENV_HINTS=1 brew install "$package_name" >/dev/null 2>&1; then
        # Update with completion
        printf "\033[2K\r  • %-15s " "$display_name"
        show_progress_bar 100 100
        printf " ✅"
    else
        printf "\033[2K\r  • %-15s ❌" "$display_name"
    fi
    
    rm -f "$temp_file"
}

install_with_progress_at_position() {
    local package_name="$1"
    local display_name="$2"
    local max_length="$3"
    
    # Clear the current line and show tool name with progress bar
    printf "\033[2K\r  • %-*s " $max_length "$display_name"
    show_progress_bar 0 100
    
    # Start brew install and capture ALL output (stdout and stderr)
    if HOMEBREW_NO_ENV_HINTS=1 brew install "$package_name" >/dev/null 2>&1; then
        # Update with completion - preserve tool name and show completed progress
        printf "\033[2K\r  • %-*s " $max_length "$display_name"
        show_progress_bar 100 100
        printf " ✅"
    else
        # Show error - preserve tool name
        printf "\033[2K\r  • %-*s ❌" $max_length "$display_name"
    fi
}

# Dependency downloaders
ensure_tsh_installed() {
  if ! command -v tsh >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
      install_with_progress "teleport" "tsh"
    else
      printf "• %-15s ❌ (Homebrew not found)\n" "tsh"
    fi
  else
    printf "• %-15s ✅\n" "tsh"
  fi
}

ensure_jq_installed() {
  if ! command -v jq >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
      install_with_progress "jq" "jq"
    else
      printf "• %-15s ❌ (Homebrew not found)\n" "jq"
    fi
  else
    printf "• %-15s ✅\n" "jq"
  fi
}

ensure_mongosh_installed() {
  if ! command -v mongosh >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
      install_with_progress "mongosh" "mongosh"
    else
      printf "• %-15s ❌ (Homebrew not found)\n" "mongosh"
    fi
  else
    printf "• %-15s ✅\n" "mongosh"
  fi
}

ensure_postgresql_installed() {
  if ! command -v psql >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
      install_with_progress "postgresql@14" "postgresql"
    else
      printf "• %-15s ❌ (Homebrew not found)\n" "postgresql"
    fi
  else
    printf "• %-15s ✅\n" "postgresql"
  fi
}

ensure_dbeaver_installed() {
  if ! ls /Applications/DBeaver* >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
      install_with_progress "--cask dbeaver-community" "dbeaver"
    else
      printf "• %-15s ❌ (Homebrew not found)\n" "dbeaver"
    fi
  else
    printf "• %-15s ✅\n" "dbeaver"
  fi
}

ensure_mongodb_compass_installed() {
  if ! ls /Applications/MongoDB\ Compass* >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
      install_with_progress "--cask mongodb-compass" "mongodb-compass"
    else
      printf "• %-15s ❌ (Homebrew not found)\n" "mongodb-compass"
    fi
  else
    printf "• %-15s ✅\n" "mongodb-compass"
  fi
}

ensure_kubectl_installed() {
  if ! command -v kubectl >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
      install_with_progress "kubernetes-cli" "kubectl"
    else
      printf "• %-15s ❌ (Homebrew not found)\n" "kubectl"
    fi
  else
    printf "• %-15s ✅\n" "kubectl"
  fi
}

# Check if required dependencies are installed
check_required_dependencies() {
    local available_deps=()
    
    # Check jq
    if ! command -v jq >/dev/null 2>&1; then
        available_deps+=("jq:JSON processor")
    fi
    
    # Check tsh
    if ! command -v tsh >/dev/null 2>&1; then
        available_deps+=("tsh:Teleport client")
    fi
    
    echo "${available_deps[@]}"
}

# Check if optional dependencies are installed
check_optional_dependencies() {
    local available_deps=()
    
    # Check mongosh
    if ! command -v mongosh >/dev/null 2>&1; then
        available_deps+=("mongosh:MongoDB Shell")
    fi
    
    # Check PostgreSQL
    if ! command -v psql >/dev/null 2>&1; then
        available_deps+=("postgresql:PostgreSQL client")
    fi
    
    # Check DBeaver (look for app in Applications)
    if ! ls /Applications/DBeaver* >/dev/null 2>&1; then
        available_deps+=("dbeaver:Database GUI")
    fi
    
    # Check MongoDB Compass (look for app in Applications)
    if ! ls /Applications/MongoDB\ Compass* >/dev/null 2>&1; then
        available_deps+=("mongodb-compass:MongoDB GUI")
    fi
    
    # Check kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
        available_deps+=("kubectl:Kubernetes CLI")
    fi
    
    echo "${available_deps[@]}"
}


# ================================================================
# Dependencies
# ================================================================
printf "\033c"
create_header "Dependencies"

# Check what dependencies need to be installed
available_required_deps=($(check_required_dependencies))
available_optional_deps=($(check_optional_dependencies))

# Required Dependencies Section
if [ ${#available_required_deps[@]} -gt 0 ]; then
    echo "Required Dependencies:"
    
    for dep in "${available_required_deps[@]}"; do
        IFS=':' read -r name description <<< "$dep"
        case "$name" in
            "jq") ensure_jq_installed ;;
            "tsh") ensure_tsh_installed ;;
        esac
    done
    echo
fi

# Optional Dependencies Section
if [ ${#available_optional_deps[@]} -gt 0 ]; then
    printf "Optional Dependencies:\n"
    
    for dep in "${available_optional_deps[@]}"; do
        if [[ -n "$dep" ]]; then
            IFS=':' read -r name description <<< "$dep"
            if [[ -n "$description" ]]; then
                printf "\n  • $description"
            fi
        fi
    done
    echo

    printf "\nInstall optional dependencies? (a)ll / (i)ndividually / (n)o: "
    read -r install_choice

    case "$install_choice" in
        [Aa])
            echo
            
            # Find the longest tool name for proper spacing
            max_length=0
            dep_names=()
            for dep in "${available_optional_deps[@]}"; do
                if [[ -n "$dep" ]]; then
                    IFS=':' read -r name description <<< "$dep"
                    dep_names+=("$name")
                    if [[ ${#name} -gt $max_length ]]; then
                        max_length=${#name}
                    fi
                fi
            done
            
            # Install each dependency with progress bars
            for name in "${dep_names[@]}"; do
                case "$name" in
                    "mongosh") install_with_progress_at_position "mongosh" "$name" $max_length ;;
                    "postgresql") install_with_progress_at_position "postgresql@14" "$name" $max_length ;;
                    "dbeaver") install_with_progress_at_position "--cask dbeaver-community" "$name" $max_length ;;
                    "mongodb-compass") install_with_progress_at_position "--cask mongodb-compass" "$name" $max_length ;;
                    "kubectl") install_with_progress_at_position "kubernetes-cli" "$name" $max_length ;;
                esac
                echo
            done
            ;;
        [Ii])
            echo
            
            for dep in "${available_optional_deps[@]}"; do
                IFS=':' read -r name description <<< "$dep"
                
                case "$name" in
                    "mongosh")
                        printf "\033c"
                        create_header "MongoDB Shell"
                        printf "Install mongosh (MongoDB Shell)? (y/N): "
                        read -r response
                        if [[ "$response" =~ ^[Yy]$ ]]; then
                            ensure_mongosh_installed
                        fi
                        echo
                        ;;
                    "postgresql")
                        printf "\033c"
                        create_header "PostgreSQL"
                        printf "Install PostgreSQL client? (y/N): "
                        read -r response
                        if [[ "$response" =~ ^[Yy]$ ]]; then
                            ensure_postgresql_installed
                        fi
                        echo
                        ;;
                    "dbeaver")
                        printf "\033c"
                        create_header "DBeaver"
                        printf "Install DBeaver (Database GUI)? (y/N): "
                        read -r response
                        if [[ "$response" =~ ^[Yy]$ ]]; then
                            ensure_dbeaver_installed
                        fi
                        echo
                        ;;
                    "mongodb-compass")
                        printf "\033c"
                        create_header "MongoDB Compass"
                        printf "Install MongoDB Compass (MongoDB GUI)? (y/N): "
                        read -r response
                        if [[ "$response" =~ ^[Yy]$ ]]; then
                            ensure_mongodb_compass_installed
                        fi
                        echo
                        ;;
                    "kubectl")
                        printf "\033c"
                        create_header "Kubernetes CLI"
                        printf "Install kubectl (Kubernetes CLI)? (y/N): "
                        read -r response
                        if [[ "$response" =~ ^[Yy]$ ]]; then
                            ensure_kubectl_installed
                        fi
                        echo
                        ;;
                esac
            done
            ;;
        *)
            echo "Skipping optional dependencies."
            echo
            ;;
    esac
fi

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