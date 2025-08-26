create_notification() {
    local current_version="$1"
    local latest_version="$2"
    local prompt="$3"  # Optional prompt for user input
    local changelog="$4"  # Optional changelog entries
    
    
    # Capture current terminal content to a temp file
    local temp_capture="/tmp/terminal_capture_$$"
    
    # Save current screen using terminal control sequences
    # This requests the terminal to send back the current screen content
    printf "\033[?1049h"  # Switch to alternate screen buffer (saves current screen)
    printf "\033[2J\033[H"  # Clear screen for notification
    
    local title="📦 Update Available!" 
    local message="Would you like to update now? \033[1;31m$current_version\033[37m >> \033[1;32m$latest_version\033[37m"
    local title_len=${#title}
    
    # Calculate visual length without ANSI codes for layout
    local message_display_text="Would you like to update now? $current_version >> $latest_version"
    local message_lines=("$message")
    local max_message_len=${#message_display_text}
    
    # Determine the width based on the longer content + 8 for padding (4 on each side) + 2 for borders
    local content_width=$(( title_len > max_message_len ? title_len : max_message_len ))
    local box_width=$((content_width + 10))  # 4 padding each side + 2 borders
    
    # Apply max width constraint of 65
    if [ $box_width -gt 65 ]; then
        box_width=65
    fi
    
    local padding="    "  # 4 spaces of padding
    local indent="    "  # 4 spaces indent for alignment
    
    # Calculate title centering for dashes
    local title_dash_count=$(( (box_width - title_len - 6) / 2 ))  # Account for spaces around title and extra spaces
    local title_left_dashes=""
    local title_right_dashes=""
    for ((i=0; i<title_dash_count; i++)); do title_left_dashes+="━"; done
    for ((i=0; i<title_dash_count; i++)); do title_right_dashes+="━"; done
    
    # Add spacing above notification
    printf "\n\n"
    
    # Top border with half bottom blocks
    printf "  ${indent}  "
    printf '%.0s\033[37;5m▁' $(seq 1 $((box_width - 2)))
    printf "\n"
    printf " ${indent}  "
    printf '%.0s\033[38;5;245m▄' $(seq 1 $((box_width - 2)))
    printf "\n"
    
    # Title section with grey background and centering
    local title_padding=$(( (box_width - title_len - 4) / 2 ))
    printf " ${indent} \033[48;5;245m\033[37m "
    printf '%.0s ' $(seq 1 $title_padding)
    printf "\033[1;5m${title}\033[22m"
    printf '%.0s ' $(seq 1 $((title_padding + 1)))
    printf "\033[0m\n"
    
    # Message section - multiple lines with grey background and centering
    for line in "${message_lines[@]}"; do
        local line_padding=$(( (box_width - max_message_len - 4) / 2 ))
        printf "${indent} \033[48;5;245m\033[37m"
        printf '%.0s ' $(seq 1 $line_padding)
        printf "${line}"
        printf '%.0s ' $(seq 1 $((line_padding + 2)))
        printf "\033[0m\n"
    done
    
    # Bottom border
    printf "    \033"
    printf '%.0s\033[38;5;245m▀\033[0m' $(seq 1 $((box_width - 2)))
    printf "\n   "
    printf '%.0s\033[37;5m▔\033[0m' $(seq 1 $((box_width - 2)))

    # If changelog is provided, add it below the notification box
    if [ -n "$changelog" ]; then
        printf "\n"
        
        # First pass: find the longest changelog line
        local max_changelog_len=0
        while IFS= read -r line || [ -n "$line" ]; do
            if [ -n "$line" ]; then
                # Remove markdown dashes and convert to bullet
                local clean_line=$(echo "$line" | sed 's/^- //')
                local changelog_line="• $clean_line"
                local changelog_len=${#changelog_line}
                if [ $changelog_len -gt $max_changelog_len ]; then
                    max_changelog_len=$changelog_len
                fi
            fi
        done <<< "$changelog"
        
        # Align with menu option text (2 spaces in from button edge)
        local option1_width=8  # Fixed width for "Yes" + padding
        local separator="                           "  # Fixed separator 
        local total_menu_width=$((option1_width + ${#separator} + 8))
        local menu_padding=$(( (box_width - total_menu_width) / 2 ))
        local changelog_spaces=""
        for ((i=0; i<menu_padding+2; i++)); do changelog_spaces+=" "; done
        
        # Second pass: display all lines with same left alignment
        while IFS= read -r line || [ -n "$line" ]; do
            if [ -n "$line" ]; then
                # Remove markdown dashes and convert to bullet
                local clean_line=$(echo "$line" | sed 's/^- //')
                local changelog_line="• $clean_line"
                printf "${indent}${changelog_spaces}${changelog_line}\n"
            fi
        done <<< "$changelog"
    fi
    
    # If prompt is provided, add menu underneath
    if [ -n "$prompt" ]; then
        printf "\n\n\n"  # Add space before menu
        
        # Call embedded horizontal menu (now works outside the box)
        embedded_horizontal_menu "$indent" "$box_width"
        local result=$?
        # Handle the update logic based on user selection
        case $result in
            0) # Yes selected - perform update
                printf "\n${indent}🔄 Updating th...\n\n"
                
                # Use load function with brew upgrade
                update_th() {
                    brew upgrade youlend/tools/th > /dev/null 2>&1
                }
                
                load update_th "Installing update..."
                if [ $? -eq 0 ]; then
                    # Cache the new version FIRST
                    local version_cache="$HOME/.cache/th_version"
                    mkdir -p "$(dirname "$version_cache")"
                    brew list --versions th 2>/dev/null | awk '{print $2}' > "$version_cache"
                    
                    # Then reload th
                    printf "${indent}🔄 Reloading th...\n"
                    local shell_name=$(basename "$SHELL")
                    if [ "$shell_name" = "zsh" ]; then
                        source "$HOME/.zshrc" 
                    elif [ "$shell_name" = "bash" ]; then
                        source "$HOME/.bash_profile" || source "$HOME/.bashrc"
                    fi
                    printf "\n${indent}✅ \033[1;32mth updated successfully!\033[0m\n\n"
                else
                    printf "\n${indent}❌ \033[1;31mUpdate failed. Please try manually.\033[0m\n\n"
                fi
                stty echo icanon
                printf "                  \033[4mPress \033[1;5menter\033[0;4m to return..."
                read -n 1
                ;;
            1) # No selected - mute notifications
                local daily_cache_file="$HOME/.cache/th_update_check"
                echo "MUTED_UNTIL_TOMORROW" > "$daily_cache_file"
                local mute_message="⏳ Update notifications muted for 1 hour."
                local mute_len=${#mute_message}
                local mute_padding=$(( (box_width - mute_len - 4) / 2 ))
                local mute_spaces=""
                for ((i=0; i<mute_padding; i++)); do mute_spaces+=" "; done
                printf "\n${indent}${mute_spaces}${mute_message}\n"
                sleep 1
                ;;
            255) # Quit
                printf "\n${indent}❌ Update check cancelled.\n"
                sleep 1
                ;;
        esac
        
        # Restore the original screen content after all update activity is complete
        printf "\033[?1049l"  # Switch back to main screen buffer
    else
        # Restore screen for non-prompt notifications
        printf "\033[?1049l"  # Switch back to main screen buffer
    fi
}