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

