center_content() {
    # Get terminal width and calculate centering
    local term_width=$(tput cols)
    content_width=${1:-65}
    local padding=$(( (term_width - content_width) / 2))
    local center_spaces=""
    
    # Create padding string
    for ((i=0; i<padding; i++)); do
        center_spaces+=" "
    done
    
    echo "$center_spaces"
}

cprintf() {
    local text="$1"
    local center_spaces=$(center_content)

    printf "$center_spaces$text"
}

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

create_note() {
    local note_text="$1"
    local note_length=${#note_text}

    printf "\n\n\033[0m\033[38;5;245m▄██▀ $note_text\033[0m\033[1;34m\033[0m\n\n"
}

print_logo() {
  local version="$1"
  local center_spaces="$2"

  printf "\n"
  printf "${center_spaces}                \033[0m\033[38;5;250m ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁\033[0m\033[1;34m\033[0m\n"
  printf "${center_spaces}                \033[0m\033[38;5;250m▕░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▏\033[0m\033[1;34m\033[0m\n"
  printf "${center_spaces}               \033[0m\033[38;5;250m▕░░░░░░░░░░░ \033[0m\033[1;97m████████╗ ██╗  ██╗\033[0m\033[38;5;250m ░░░░░░░░░░░░░▏\033[0m\033[1;34m\033[0m\n"
  printf "${center_spaces}              \033[0m\033[38;5;249m▕▒▒▒▒▒▒▒▒▒▒▒ \033[0m\033[1;97m╚══██╔══╝ ██║  ██║\033[0m\033[38;5;249m ▒▒▒▒▒▒▒▒▒▒▒▒▒▏\033[0m\033[1;34m\033[0m\n"
  printf "${center_spaces}             \033[0m\033[38;5;248m▕▓▓▓▓▓▓▓▓▓▓▓▓▓▓ \033[0m\033[1;97m█▉║    ███████║\033[0m\033[38;5;248m ▓▓▓▓▓▓▓▓▓▓▓▓▓▏\033[0m\033[1;34m\033[0m\n"
  printf "${center_spaces}            \033[0m\033[38;5;247m▕██████████████ \033[0m\033[1;97m█▉║    ██╔══██║\033[0m\033[38;5;247m █████████████▏\033[0m\033[1;34m\033[0m\n"
  printf "${center_spaces}           \033[0m\033[38;5;246m▕██████████████ \033[0m\033[1;97m██║    ██║  ██║\033[0m\033[38;5;246m █████████████▏\033[0m\033[1;34m\033[0m\n"
  printf "${center_spaces}          \033[0m\033[38;5;245m▕██████████████ \033[0m\033[1;97m██╝    ██╝  ██╝\033[0m\033[38;5;245m █████████████▏\033[0m\033[1;34m\033[0m\n"
  printf "${center_spaces}         \033[0m\033[38;5;245m▕██████████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄█████████████▏\033[0m\033[1;34m\033[0m\n"
  printf "${center_spaces}         \033[0m\033[38;5;245m ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔\033[0m\033[1;34m\033[0m\n"
  printf "${center_spaces}         \033[0m\033[38;5;245m■■■■■■■■■\033[0m\033[1m Teleport Helper - v$version \033[0m\033[38;5;245m■■■■■■■■■■\033[0m\033[1;34m\033[0m\n"
  printf "\n"
}

# Enhanced input function with configurable options
create_input() {
    local min_chars="${1:-15}"
    local max_chars="${2:-51}"
    local max_width="${3:-$max_chars}"  # Visual box width (defaults to max_chars if not specified)
    local error_message="${4:-Input too short. Please provide more detail.}"
    local input_type="${5:-text}"  # "text" or "numerical"

    local input=""
    local old_stty
    local first_run=true

    # Draw the input box once at the beginning
    local box_width=$((max_width + 2))  # Add 2 for padding (1 on each side)
    local top_bottom_line=$(printf '─%.0s' $(seq 1 $box_width))
    local middle_spaces=$(printf ' %.0s' $(seq 1 $((max_width + 2))))

    echo " ║  ╭${top_bottom_line}╮"
    echo " ╚═ │${middle_spaces}│"
    echo "    ╰${top_bottom_line}╯"

    while true; do
        # Move cursor into the box
        printf "\033[2A"  # Move up 2 lines
        printf "\033[6C"  # Move right 6 columns

        # Save terminal settings and set raw mode
        old_stty=$(stty -g)
        stty raw -echo

        if [ "$first_run" = true ]; then
            input=""
            first_run=false
        fi

        while true; do
            # Read single character
            char=$(dd bs=1 count=1 2>/dev/null)

            # Handle Ctrl+C (ASCII 3) - Exit gracefully
            if [[ "$char" == $'\003' ]]; then
                stty "$old_stty"
                printf "\n\n^C\n"
                return 130
            fi

            # Handle Option+Backspace (word delete) - starts with ESC
            if [[ "$char" == $'\033' ]]; then
                # Read next character to see what escape sequence this is
                next_char=$(dd bs=1 count=1 2>/dev/null)
                if [[ "$next_char" == $'\177' ]]; then
                    # Option+Backspace - delete all text
                    while [ ${#input} -gt 0 ]; do
                        input="${input%?}"
                        printf "\b \b"
                    done
                fi
                # Ignore other escape sequences for now
                continue
            fi

            # Handle Enter (ASCII 13 or 10)
            if [[ "$char" == $'\r' || "$char" == $'\n' ]]; then
                break
            fi

            # Handle Backspace (ASCII 127 or 8)
            if [[ "$char" == $'\177' || "$char" == $'\b' ]]; then
                if [ ${#input} -gt 0 ]; then
                    input="${input%?}"
                    printf "\b \b"
                fi
                continue
            fi

            # Handle printable characters with strict length limit and type validation
            if [[ ${#input} -lt $max_chars ]] && [[ "$char" =~ [[:print:]] ]]; then
                # Validate input based on type
                if [[ "$input_type" == "numerical" ]]; then
                    # For numerical: only allow digits and 's', but 's' cannot be first character
                    if [[ "$char" =~ [0-9] ]]; then
                        # Always allow digits
                        input="$input$char"
                        printf "%s" "$char"
                    elif [[ "$char" == "s" && ${#input} -gt 0 ]]; then
                        # Only allow 's' if there's already input (not first character)
                        input="$input$char"
                        printf "%s" "$char"
                    fi
                    # Silent rejection for invalid characters or 's' as first character
                else
                    # For text: allow all printable characters
                    input="$input$char"
                    printf "%s" "$char"
                fi
            fi
            # If at max chars, don't print anything (silent rejection)
        done

        # Restore terminal settings
        stty "$old_stty"

        # Move cursor down past the box
        printf "\033[2B"
        printf "\033[0G"

        # Check minimum length requirement
        if [ ${#input} -ge $min_chars ]; then
            user_input="$input"  # Set global variable
            return 0
        else
            # Clear and show error message, then redraw box
            printf "\033[4A"  # Move up 4 lines
            printf "\033[0G"  # Move to column 0
            printf "\033[0J"  # Clear from cursor to end of screen
            printf "\033[31m%s (%d/%d chars).\033[0m\n" "$error_message" "${#input}" "$min_chars"

            # Redraw the input box
            echo " ║  ╭${top_bottom_line}╮"
            echo " ╚═ │${middle_spaces}│"
            echo "    ╰${top_bottom_line}╯"
        fi
    done
}