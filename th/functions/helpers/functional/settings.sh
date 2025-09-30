th_config() {
    local th_dir="$HOME/.th"
    local version_file="$th_dir/version"

    # Create .th directory if it doesn't exist
    if [[ ! -d "$th_dir" ]]; then
        mkdir -p "$th_dir" 2>/dev/null
        # Make directory hidden (macOS/Linux compatible)
        if command -v chflags >/dev/null 2>&1; then
            chflags hidden "$th_dir" 2>/dev/null || true
        fi
    fi

    # Read existing configuration values
    local current_suppression

    # Extract suppression from version file
    if [[ -f "$version_file" ]]; then
        current_suppression=$(grep "^UPDATE_SUPPRESSION_HOURS:" "$version_file" 2>/dev/null | cut -d':' -f2 | tr -d ' ')
    fi
    [[ -z "$current_suppression" ]] && current_suppression="24"

    # If no arguments, show all current config
    if [[ $# -eq 0 ]]; then
        printf "\033c"
        create_header "th config"

        printf "Current configuration:\n"
        printf "\n"

        # Show update suppression
        printf "• update suppression (suppression): "
        printf "\033[32m%s hours\033[0m\n" "$current_suppression"

        printf "\n"
        return 0
    fi

    local option="$1"
    local value="$2"

    case "$(echo "$option" | tr '[:upper:]' '[:lower:]')" in
        "update-suppression"|"suppression")
            if [[ -z "$value" ]]; then
                printf "\033[31mL Missing value for update-suppression. Usage: th config update-suppression <hours>\033[0m\n"
                return 1
            fi

            # Validate input
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" -le 0 ]]; then
                printf "\033[31mL Invalid suppression value. Please enter a positive number.\033[0m\n"
                return 1
            fi

            # Update version file with new suppression
            local temp_file=$(mktemp)

            # Copy existing data except UPDATE_SUPPRESSION_HOURS
            if [[ -f "$version_file" ]]; then
                while IFS=': ' read -r key val || [[ -n "$key" ]]; do
                    if [[ -n "$key" && -n "$val" && "$key" != "UPDATE_SUPPRESSION_HOURS" ]]; then
                        printf "%s: %s\n" "$key" "$val" >> "$temp_file"
                    fi
                done < "$version_file"
            fi

            # Add new suppression value
            printf "UPDATE_SUPPRESSION_HOURS: %s\n" "$value" >> "$temp_file"

            # Replace version file
            mv "$temp_file" "$version_file"

            printf "\033c"
            create_header "th config"
            printf "Update suppression updated to "
            printf "\033[32m%s hour/s\033[0m\n" "$value"
            ;;
        *)
            printf "\033c"
            create_header "th config"
            printf "\033[31m❌ Unknown configuration option: %s\033[0m\n" "$option"
            printf "\n"
            printf "Available options:\n"
            printf "• update suppression (suppression) <hours> - Set update check suppression in hours.\n"
            return 1
            ;;
    esac
}