animate_th() {
    local center_spaces=$(center_content)
    local version="1.3.7"
    
    printf "\033c"
    printf "\033[?25l"  # Hide cursor
    
    printf "\n\033[1mTeleport Helper - Press Enter to continue...\033[0m\n\n"
    
    # Create a flag file for key detection
    local flag_file="/tmp/animate_stop_$$"
    rm -f "$flag_file"
    
    # Smoother shimmer with more color steps
    local colors=(232 233 234 235 236 237 238 239 240 241 242 243 244 245 246 247 248 249 250 251 252 253 254 255 254 253 252 251 250 249 248 247 246 245 244 243 242 241 240 239 238 237 236 235 234 233)
    local frame=0
    
    # Save cursor position and clear screen properly
    printf "\033[s\033[2J\033[H"
    
    # Animation sequence - infinite loop
    while true; do
        # Check if flag file exists (Enter was pressed)
        if [ -f "$flag_file" ]; then
            rm -f "$flag_file"
            break
        fi
        
        # Move cursor to home without clearing (smoother)
        printf "\033[H"
        
        # Bottom to top shimmer wave
        local line1_color=${colors[$(((frame + 0) % ${#colors[@]}))]}
        local line2_color=${colors[$(((frame + 1) % ${#colors[@]}))]}
        local line3_color=${colors[$(((frame + 2) % ${#colors[@]}))]}
        local line4_color=${colors[$(((frame + 3) % ${#colors[@]}))]}
        local line5_color=${colors[$(((frame + 4) % ${#colors[@]}))]}
        local line6_color=${colors[$(((frame + 5) % ${#colors[@]}))]}
        local line7_color=${colors[$(((frame + 6) % ${#colors[@]}))]}
        local line8_color=${colors[$(((frame + 7) % ${#colors[@]}))]}
        local line9_color=${colors[$(((frame + 8) % ${#colors[@]}))]}
        local line10_color=${colors[$(((frame + 9) % ${#colors[@]}))]}
        local line11_color=${colors[$(((frame + 10) % ${#colors[@]}))]}
        
        printf "${center_spaces}        \033[38;5;${line11_color}m ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁\033[0m\n"
        printf "${center_spaces}        \033[38;5;${line10_color}m▕░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▏\033[0m\n"
        printf "${center_spaces}       \033[38;5;${line9_color}m▕░░░░░░░░░░░░░░░░░ \033[1;97m███████████╗ ███╗  ███╗\033[38;5;${line9_color}m ░░░░░░░░░░░░░░░░░░░░▏\033[0m\n"
        printf "${center_spaces}      \033[38;5;${line8_color}m▕▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ \033[1;97m╚══███╔══╝  ███║  ███║\033[38;5;${line8_color}m ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▏\033[0m\n"
        printf "${center_spaces}     \033[38;5;${line7_color}m▕▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ \033[1;97m███║     █████████║\033[38;5;${line7_color}m ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▏\033[0m\n"
        printf "${center_spaces}    \033[38;5;${line6_color}m▕█████████████████████ \033[1;97m███║     ███╔══███║\033[38;5;${line6_color}m ████████████████████▏\033[0m\n"
        printf "${center_spaces}   \033[38;5;${line5_color}m▕█████████████████████ \033[1;97m███║     ███║  ███║\033[38;5;${line5_color}m ████████████████████▏\033[0m\n"
        printf "${center_spaces}  \033[38;5;${line4_color}m▕█████████████████████ \033[1;97m███╝     ███╝  ███╝\033[38;5;${line4_color}m ████████████████████▏\033[0m\n"
        printf "${center_spaces} \033[38;5;${line4_color}m▕█████████████████████ \033[1;97m███╝     ███╝  ███╝\033[38;5;${line4_color}m ████████████████████▏\033[0m\n"
        printf "${center_spaces}\033[38;5;${line3_color}m▕█████████████████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄████████████████████▏\033[0m\n"
        printf "${center_spaces}\033[38;5;${line2_color}m ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔\033[0m\n"
        printf "\n"
        
        frame=$((frame + 1))
        sleep 0.08
    done
    
    # Clean up background process
    kill $bg_pid 2>/dev/null
    wait $bg_pid 2>/dev/null
    
    printf "\033[?25h"  # Show cursor
    printf "\n\033[1;32m✓ Ready!\033[0m\n\n"
}

animate_youlend() {
    local center_spaces=$(center_content 92)
    
    printf "\033c"
    printf "\033[?25l"  # Hide cursor
    
    # Smoother shimmer with more color steps
    local colors=(232 233 234 235 236 237 238 239 240 241 242 243 244 245 246 247 248 249 250 251 252 253 254 255 254 253 252 251 250 249 248 247 246 245 244 243 242 241 240 239 238 237 236 235 234 233)
    local frame=0
    
    # Save cursor position and clear screen properly
    printf "\033[s\033[2J\033[H"
    
    # Animation sequence - infinite loop
    while true; do
        
        # Move cursor to home without clearing (smoother)
        printf "\033[H"
        
        # Bottom to top shimmer wave
        local line1_color=${colors[$(((frame + 0) % ${#colors[@]}))]}
        local line2_color=${colors[$(((frame + 1) % ${#colors[@]}))]}
        local line3_color=${colors[$(((frame + 2) % ${#colors[@]}))]}
        local line4_color=${colors[$(((frame + 3) % ${#colors[@]}))]}
        local line5_color=${colors[$(((frame + 4) % ${#colors[@]}))]}
        local line6_color=${colors[$(((frame + 5) % ${#colors[@]}))]}
        local line7_color=${colors[$(((frame + 6) % ${#colors[@]}))]}
        local line8_color=${colors[$(((frame + 7) % ${#colors[@]}))]}
        local line9_color=${colors[$(((frame + 8) % ${#colors[@]}))]}
        local line10_color=${colors[$(((frame + 9) % ${#colors[@]}))]}
        local line11_color=${colors[$(((frame + 10) % ${#colors[@]}))]}
        
        printf "${center_spaces}       \033[38;5;${line11_color}m ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁\033[0m\n"
        printf "${center_spaces}       \033[38;5;${line10_color}m▕░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▏\033[0m\n"
        printf "${center_spaces}      \033[38;5;${line9_color}m▕░░░░░░░░░░ \033[1;97m██╗   ██╗ ██████╗  ██╗   ██╗ ██╗      ███████╗ ███╗   ██╗ ██████╗\033[38;5;${line9_color}m  ░░░░░░░░▏\033[0m\n"
        printf "${center_spaces}     \033[38;5;${line8_color}m▕▒▒▒▒▒▒▒▒▒▒ \033[1;97m╚██╗ ██╔╝██╔═══██╗ ██║   ██║ ██║      ██╔════╝ ████╗  ██║ ██╔══██╗\033[38;5;${line8_color}m ▒▒▒▒▒▒▒▒▏\033[0m\n"
        printf "${center_spaces}    \033[38;5;${line7_color}m▕▓▓▓▓▓▓▓▓▓▓ \033[1;97m ╚████╔╝ ██║   ██║ ██║   ██║ ██║      █████╗   ██╔██╗ ██║ ██║  ██║\033[38;5;${line7_color}m ▓▓▓▓▓▓▓▓▏\033[0m\n"
        printf "${center_spaces}   \033[38;5;${line6_color}m▕██████████ \033[1;97m  ╚██╔╝  ██║   ██║ ██║   ██║ ██║      ██╔══╝   ██║╚██╗██║ ██║  ██║\033[38;5;${line6_color}m ████████▏\033[0m\n"
        printf "${center_spaces}  \033[38;5;${line5_color}m▕██████████ \033[1;97m   ██║   ╚██████╔╝ ╚██████╔╝ ███████╗ ███████╗ ██║ ╚████║ ██████╔╝\033[38;5;${line5_color}m ████████▏\033[0m\n"
        printf "${center_spaces} \033[38;5;${line4_color}m ██████████ \033[1;97m   ╚═╝    ╚═════╝   ╚═════╝  ╚══════╝ ╚══════╝ ╚═╝  ╚═══╝ ╚═════╝\033[38;5;${line4_color}m  ████████▏\033[0m\n"
        printf "${center_spaces}\033[38;5;${line3_color}m▕██████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄████████▏\033[0m\n"
        printf "${center_spaces}\033[38;5;${line2_color}m ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔\033[0m\n"
        printf "\n"

        frame=$((frame + 1))
        sleep 0.08
    done
}