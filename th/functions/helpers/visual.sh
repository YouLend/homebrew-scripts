wave_loader() {
    local pid=$1
    local message="${2:-"Loading.."}"
    printf '\033[?25l'

    # Dynamic wave pattern matching header width (65 chars - same as center_content default)
    local header_width=63
    local wave_len=$header_width
    # Handle zsh vs bash array indexing differences
    if [ -n "$ZSH_VERSION" ]; then
        # In zsh, arrays are 1-indexed, so we need an extra element at index 0
        local blocks=("" "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
    else
        local blocks=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
    fi
    local pos=0
    local direction=1
    
    local trap_cmd="printf '\\033[?25h\\n'; return"
    trap "$trap_cmd" INT TERM
    
    while kill -0 $pid 2>/dev/null; do
        local line=""
        local msg_len=${#message}
        local msg_with_spaces_len=$((msg_len + 2))
        local msg_start=$(((wave_len - msg_with_spaces_len) / 2))
        local msg_end=$((msg_start + msg_with_spaces_len))
        
        for i in $(seq 1 $wave_len); do
            if [ -n "$ZSH_VERSION" ]; then
                i=$((i))
            else
                i=$((i - 1))
            fi
            if [ $i -eq $pos ]; then
                local center=$((wave_len / 2))
                local distance_from_center=$((pos > center ? pos - center : center - pos))
                local max_distance=$((wave_len / 2))
                local height_boost=$((7 - (distance_from_center * 7 / max_distance)))
                if [ $height_boost -lt 0 ]; then
                    height_boost=0
                fi
                # Use consistent indexing - account for zsh vs bash array differences
                if [ -n "$ZSH_VERSION" ]; then
                    line="${line}\033[1;97m${blocks[$((height_boost + 1))]}\033[0m"
                else
                    line="${line}\033[1;97m${blocks[$height_boost]}\033[0m"
                fi
            elif [ $i -ge $msg_start ] && [ $i -lt $msg_end ]; then
                local char_idx=$((i - msg_start))
                if [ $char_idx -eq 0 ]; then
                    line="${line} "
                elif [ $char_idx -eq $((msg_with_spaces_len - 1)) ]; then
                    line="${line} "
                else
                    local msg_char_idx=$((char_idx - 1))
                    line="${line}${message:$msg_char_idx:1}"
                fi
            else
                line="${line}\033[38;5;245m \033[0m"
            fi
        done

        printf "\r\033[K$line" 

        pos=$((pos + direction))
        if [ $pos -lt 0 ] || [ $pos -ge $wave_len ]; then
            direction=$((-direction))
            pos=$((pos + direction))
        fi
        
        local center=$((wave_len / 2))
        local distance_from_center=$((pos > center ? pos - center : center - pos))
        local max_distance=$((wave_len / 2))
        
        # Animation speed control based on distance from center
        if [ $distance_from_center -gt $((max_distance * 9 / 10)) ]; then
            sleep 0.03  # Outermost edge - slow
        elif [ $distance_from_center -gt $((max_distance * 4 / 5)) ]; then
            sleep 0.02  # Near edge - slow
        elif [ $distance_from_center -gt $((max_distance * 3 / 4)) ]; then
            sleep 0.01  # Mid-distance - slowest
        elif [ $distance_from_center -gt $((max_distance / 2)) ]; then
            sleep 0.005 # Approaching center - fast
        else
            sleep 0.005 # Center - fastest
        fi
    done
    
    printf "\r\033[K"
    printf '\033[?25h'
}

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

print_help() {
    center_spaces=$(center_content)
    version="$1"

    print_logo "$version" "$center_spaces"
    create_header "Usage" "$center_spaces" 1
    printf "%s     ╚═ \033[1mth aws  [options] | a\033[0m   : AWS login.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth db   [options] | d\033[0m   : Database login.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth kube [options] | k\033[0m   : Kubernetes login.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth terra          | t\033[0m   : Quick log-in to yl-admin.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth login          | l\033[0m   : Simple log in to Teleport\033[0m\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth logout         | c\033[0m   : Clean up Teleport session.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth version        | v\033[0m   : Show the current version.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth update         | u\033[0m   : Check for th updates.\n" "$center_spaces"
    printf "%s     \033[0m\033[38;5;245m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\033[1;34m\033[0m\n" "$center_spaces"
    printf "%s     For help, and \033[1m[options]\033[0m info, run \033[1mth a/k/d etc.. -h\033[0m\n\n" "$center_spaces"
    create_header "Docs" "$center_spaces" 1
    printf "%s     Run the following commands to access the documentation pages: \n" "$center_spaces"
    printf "%s     ╚═ \033[1mDocs:             | th doc\033[0m\n" "$center_spaces"
    printf "%s     ╚═ \033[1mQuickstart:       | th qs\033[0m\n\n" "$center_spaces"
    create_header "Extras" "$center_spaces" 1
    printf "%s     Run the following commands to access the extra features: \n" "$center_spaces"
    printf "%s     ╚═ \033[1mth loader               \033[0m: Run loader animation.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth animate [options]    \033[0m: Run logo animation.\n" "$center_spaces"
    printf "%s        ╚═ \033[1myl\n" "$center_spaces"
    printf "%s        ╚═ \033[1mth\n" "$center_spaces"
    printf "%s          \033[0m\033[38;5;245m  ▁▁▁▁▁▁▁▁▁▁▁▁▁\033[0m\033[1;97m  ▄▄▄ ▄▁▄  \033[0m\033[38;5;245m▁▁▁▁▁▁▁▁▁▁▁▁▁▁\033[0m\033[1;34m\033[0m\n" "$center_spaces"
    printf "%s          \033[0m\033[38;5;245m ▔▔▔▔▔▔▔▔▔▔▔▔▔▔\033[0m\033[1;97m   ▀  ▀▔▀  \033[0m\033[38;5;245m▔▔▔▔▔▔▔▔▔▔▔▔▔\033[0m\033[1;34m\033[0m\n" "$center_spaces"
}

print_db_help() {
    print "\033c"
    create_header "th database | d"
    printf "\033[1mConnect to our databases (RDS and MongoDB)\033[0m\n\n"
    printf "Usage: \033[1mth database [options] | d\033[0m\n"
    printf " ╚═ \033[1mth d\033[0m                   : Open interactive database selection.\n"
    printf " ╚═ \033[1mth d <db-env> <port>\033[0m   : Quick database connect, Where:\n"
    printf "    ╚═ \033[1m<db-env>\033[0m is an abbreviation for an RDS or Mongo database, using the format:\n"
    printf "                <dbtype-env>. e.g. \033[1mr-dev\033[0m would connect to the \033[1mdev RDS cluster\033[0m\n"
    printf "    ╚═ \033[1m<port>\033[0m   is another optional arg that allows you to specify a\n"
    printf "                custom port for connection reuse in GUIs\n\n"
    printf "Examples:\n"
    printf " ╚═ $(ccode "th d r-dev")           : connects to the \033[0;32mdb-dev-aurora-postgres-1\033[0m.\n"
    printf " ╚═ $(ccode "th d m-prod 43000")    : connects to \033[0;32mmongodb-YLProd-Cluster-1\033[0m on port \033[0;32m43000\033[0m.\n"
}

print_aws_help() {
    print "\033c"
    create_header "th aws | a"
    printf "\033[1mLogin to our AWS accounts.\033[0m\n\n"
    printf "Usage: \033[1mth aws [options] | a\033[0m\n"
    printf " ╚═ \033[1mth a\033[0m                   : Open interactive login.\n"
    printf " ╚═ \033[1mth a <account> <s> <b>\033[0m : Quick aws log-in, Where:\n"
    printf "    ╚═ \033[1m<account>\033[0m is an abbreviated account name e.g. dev, cpg etc...\n"
    printf "    ╚═ \033[1m<s>\033[0m is an optional arg which logs you in with the account's sudo role\n"
    printf "    ╚═ \033[1m<b>\033[0m is another optional arg which opens the aws console.\n\n"
    printf "Examples:\n"
    printf " ╚═ $(ccode "th a dev")             : logs you into \033[0;32myl-development\033[0m as \033[1;4;32mdev\033[0m\n"
    printf " ╚═ $(ccode "th a dev s")           : logs you into \033[0;32myl-development\033[0m as \033[1;4;32msudo_dev\033[0m\n"
    printf " ╚═ $(ccode "th a dev s b")         : Opens the AWS console for the above account & role.\n"
}

print_kube_help() {
    print "\033c"
    create_header "th kube | k"
    printf "\033[1mLogin to our Kubernetes clusters.\033[0m\n\n"
    printf "Usage: \033[1mth kube [options] | k\033[0m\n"
    printf " ╚═ \033[1mth k\033[0m                   : Open interactive login.\n"
    printf " ╚═ \033[1mth k <cluster>\033[0m         : Quick kube log-in, Where:\n"
    printf "    ╚═ \033[1m<cluster>\033[0m is an abbreviated cluster name e.g. dev, cpg etc..\n\n"
    printf "Examples:\n"
    printf " ╚═ $(ccode "th k dev")             : logs you into \033[0;32maslive-dev-eks-blue.\033[0m\n"
}
# ========================================================================================================================
#                                                            Extras
# ========================================================================================================================

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

demo_wave_loader() {
    local message="${1:-"Demo Wave Loader"}"
    
    # Create a dummy background process that runs for a very long time (macOS compatible)
    sleep 99999 &
    local dummy_pid=$!
    
    # Set up trap to clean up when Ctrl+C is pressed
    trap "kill $dummy_pid 2>/dev/null; printf '\033[?25h\n'; exit 0" INT
    
    printf "\033c"

    printf "\nPress Ctrl+C to exit (Spam it, if it doesn't work first time!)\n\n"
    
    # Run the wave loader with the dummy process
    wave_loader $dummy_pid "$message"
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