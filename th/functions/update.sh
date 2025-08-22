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
                local mute_message="⏳ Update notifications muted until tomorrow."
                local mute_len=${#mute_message}
                local mute_padding=$(( (box_width - mute_len - 4) / 2 ))
                for ((i=0; i<mute_padding; i++)); do mute_spaces+=" "; done
                printf "\n${indent}${mute_message}\n"
                sleep 2
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

embedded_horizontal_menu() {
    local center_spaces="$1"
    local box_width="$2"
    local option1="Yes"
    local option2="No"
    local selected=0
    local confirm_count=0
    
    # Terminal control
    local hide_cursor='\033[?25l'
    local show_cursor='\033[?25h'
    local clear_line='\033[2K'
    local move_up='\033[1A'
    local move_to_col='\033[1G'
    
    # Colors
    local reset='\033[0m'
    local bold='\033[1m'
    local blue='\033[5;94m'
    local green='\033[5;4;92m'
    local whitebold='\033[1;5;4m'
    local highlight='\033[47m\033[30m'  # White background, black text
    
    # Hide cursor
    printf "$hide_cursor"
    
    draw_embedded_menu() {
        # Clear the current position and move up to overwrite previous menu
        printf "${clear_line}${move_up}${clear_line}${move_up}${clear_line}${move_to_col}"
        
        # Calculate fixed positions for consistent spacing
        local option1_width=8  # Fixed width for "Yes" + padding
        local option2_width=8  # Fixed width for "No" + padding
        local separator="                           "  # Fixed separator with ▞ (tripled spacing)
        local total_menu_width=$((option1_width + ${#separator} + option2_width))
        local menu_padding=$(( (box_width - total_menu_width) / 2 ))
        local menu_spaces=""
        for ((i=0; i<menu_padding; i++)); do menu_spaces+=" "; done
        
        # Draw horizontal options with fixed positioning
        printf "${center_spaces}${menu_spaces}"
        
        # Option 1 with fixed width
        if [ $selected -eq 0 ]; then
            printf "▄${highlight}${bold} ${option1} ${reset}▀"
        else
            printf "  ${option1}  "
        fi
        
        # Fixed separator
        printf "${separator}"
        
        # Option 2 with fixed width  
        if [ $selected -eq 1 ]; then
            printf "▄${highlight}${bold} ${option2} ${reset}▀"
        else
            printf "  ${option2}  "
        fi
        printf "\n\n"
        
        # Instructions line centered relative to notification box
        printf "${clear_line}"
        local instruction_text
        if [ $confirm_count -eq 0 ]; then
            instruction_text="Use ←→ arrows to navigate, press twice to confirm"
        else
            instruction_text="       ${whitebold}Press again to confirm selection"
        fi
        local inst_width=${#instruction_text}
        local inst_padding=$(( (box_width - inst_width) / 2 ))
        local inst_spaces=""
        for ((i=0; i<inst_padding; i++)); do inst_spaces+=" "; done
        printf "${center_spaces}${inst_spaces}${instruction_text}${reset}"
    }
    
    draw_embedded_menu
    
    # Set up terminal for raw input
    stty -echo -icanon min 0 time 1
    
    # Main input loop
    while true; do
        key=$(dd bs=1 count=1 2>/dev/null)
        
        case "$key" in
            $'\x1b')  # ESC sequence  
                key2=$(dd bs=1 count=1 2>/dev/null)
                if [ "$key2" = "[" ]; then
                    key3=$(dd bs=1 count=1 2>/dev/null)
                    case "$key3" in
                        'C')  # Right arrow
                            if [ $selected -eq 0 ] && [ $confirm_count -eq 0 ]; then
                                selected=1
                                confirm_count=0
                                draw_embedded_menu
                            elif [ $selected -eq 1 ] && [ $confirm_count -eq 0 ]; then
                                # First press on right option
                                confirm_count=1
                                draw_embedded_menu
                            elif [ $selected -eq 1 ] && [ $confirm_count -eq 1 ]; then
                                # Second press - confirm selection
                                # Clear the instruction line, extra newlines, and bottom border
                                printf "${clear_line}${move_up}${clear_line}${move_up}${clear_line}${move_up}"
                                stty echo icanon
                                printf "$show_cursor"
                                return 1
                            elif [ $selected -eq 0 ] && [ $confirm_count -eq 1 ]; then
                                # In confirmation mode on left, but pressed right - move to right and reset
                                selected=1
                                confirm_count=0
                                draw_embedded_menu
                            fi
                            ;;
                        'D')  # Left arrow
                            if [ $selected -eq 1 ] && [ $confirm_count -eq 0 ]; then
                                selected=0
                                confirm_count=0
                                draw_embedded_menu
                            elif [ $selected -eq 0 ] && [ $confirm_count -eq 0 ]; then
                                # First press on left option
                                confirm_count=1
                                draw_embedded_menu
                            elif [ $selected -eq 0 ] && [ $confirm_count -eq 1 ]; then
                                # Second press - confirm selection
                                # Clear the instruction line, extra newlines, and bottom border
                                printf "${clear_line}${move_up}${clear_line}${move_up}${clear_line}${move_up}"
                                stty echo icanon
                                printf "$show_cursor"
                                return 0
                            elif [ $selected -eq 1 ] && [ $confirm_count -eq 1 ]; then
                                # In confirmation mode on right, but pressed left - move to left and reset
                                selected=0
                                confirm_count=0
                                draw_embedded_menu
                            fi
                            ;;
                    esac
                fi
                ;;
            'q'|'Q')  # Quit
                # Clear the instruction line, extra newlines, and bottom border
                printf "${clear_line}${move_up}${clear_line}${move_up}${clear_line}${move_up}${clear_line}${move_up}${clear_line}"
                stty echo icanon
                printf "$show_cursor"
                return 255
                ;;
        esac
    done
}

# Background update checker
check_th_updates_background() {
    local daily_cache_file="$HOME/.cache/th_update_check"
    local session_cache_file="/tmp/.th_update_check_$$"
    local tap_name="youlend/tools"
    local package_name="th"
    
    # Create cache directory if it doesn't exist
    mkdir -p "$(dirname "$daily_cache_file")"
    
    # Check if we already checked today
    if [ -f "$daily_cache_file" ]; then
        local cache_time=$(stat -c %Y "$daily_cache_file" 2>/dev/null || stat -f %m "$daily_cache_file" 2>/dev/null)
        local current_time=$(date +%s)
        local time_diff=$((current_time - cache_time))
        
        # If cache is less than 24 hours old, use cached result
        if [ $time_diff -lt 10 ]; then
            local cached_result=$(cat "$daily_cache_file" 2>/dev/null)
            # If muted, keep it muted until 24 hours pass
            if [[ "$cached_result" == "MUTED_UNTIL_TOMORROW" ]]; then
                cp "$daily_cache_file" "$session_cache_file" 2>/dev/null
                echo "$session_cache_file"
                return
            else
                cp "$daily_cache_file" "$session_cache_file" 2>/dev/null
                echo "$session_cache_file"
                return
            fi
        fi
    fi
    
    # Start background process like create_proxy does
    {
        set +m
        if command -v brew >/dev/null 2>&1; then
            # Use brew outdated to check for updates - it handles everything for us
            local outdated_info=$(brew outdated $tap_name/$package_name 2>/dev/null)
            
            if [ -n "$outdated_info" ]; then
                # Get current version from brew list
                local current_version=$(brew list --versions $package_name 2>/dev/null | awk '{print $2}' | head -1)
                # Get latest version from brew info - extract version number after package name
                local latest_version=$(brew info $tap_name/$package_name 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
                
                if [ -n "$current_version" ] && [ -n "$latest_version" ]; then
                    echo "UPDATE_AVAILABLE:$current_version:$latest_version" | tee "$daily_cache_file" > "$session_cache_file"
                else
                    echo "UP_TO_DATE" | tee "$daily_cache_file" > "$session_cache_file"
                fi
            else
                # Either up to date or not installed via brew
                local installed_version=$(brew list --versions $package_name 2>/dev/null | awk '{print $2}' | head -1)
                if [ -n "$installed_version" ]; then
                    echo "UP_TO_DATE" | tee "$daily_cache_file" > "$session_cache_file"
                else
                    echo "NOT_INSTALLED_VIA_BREW" | tee "$daily_cache_file" > "$session_cache_file"
                fi
            fi
        else
            echo "BREW_NOT_FOUND" | tee "$daily_cache_file" > "$session_cache_file"
        fi
        disown
        set -m
    } > /dev/null 2>&1 &
    
    echo "$session_cache_file"
}

# Check for update results and display notification
show_update_notification() {
    local update_cache_file="$1"
    
    # Don't wait - just check if file exists
    if [ -f "$update_cache_file" ]; then
        local result=$(cat "$update_cache_file")
        rm -f "$update_cache_file" 2>/dev/null
        
        # Check if notifications are muted
        if [[ "$result" == "MUTED_UNTIL_TOMORROW" ]]; then
            return 0  # Skip notification silently
        elif [[ "$result" == UPDATE_AVAILABLE:* ]]; then
            local current_version=$(echo "$result" | cut -d':' -f2)
            local latest_version=$(echo "$result" | cut -d':' -f3)

            # Get changelog from GitHub release
            local changelog=""
            changelog=$(get_changelog "$latest_version")
            
            create_notification "$current_version" "$latest_version" "prompt" "$changelog"

            return 0
        fi
    fi
}

# Get changelog from GitHub release
get_changelog() {
    local version="$1"
    local repo="youlend/homebrew-scripts"  # Update with your actual repo
    
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        # Fetch changelog from GitHub releases API
        local changelog_body=$(curl -s "https://api.github.com/repos/$repo/releases/tags/th-v$version" | jq -r '.body // empty' 2>/dev/null)
        
        if [[ -n "$changelog_body" && "$changelog_body" != "null" ]]; then
            echo "$changelog_body"
        else
            # Fallback: try without 'v' prefix
            changelog_body=$(curl -s "https://api.github.com/repos/$repo/releases/tags/$version" | jq -r '.body // empty' 2>/dev/null)
            if [[ -n "$changelog_body" && "$changelog_body" != "null" ]]; then
                echo "$changelog_body"
            else
                echo "No changelog available for version $version"
            fi
        fi
    else
        echo "curl or jq not available - changelog unavailable"
    fi
}