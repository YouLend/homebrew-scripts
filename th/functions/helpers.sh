# ========================================================================================================================
#                                                    Functional Helpers
# ========================================================================================================================
th_login() {
    printf "\033c"
    create_header "Login"
    printf "Checking login status...\n"
    # if ! tsh apps ls &>/dev/null; then
    #     printf "TSH connection failed. Cleaning up existing sessions & reauthenticating...\n\n"
    #     th_kill
    # fi
    if tsh status 2>/dev/null | grep -q 'Logged in as:'; then
        cprintf "\n✅ \033[1mAlready logged in to Teleport!\033[0m\n"
        sleep 1
        return 0
    fi
    printf "\nLogging you into Teleport...\n"
    tsh login --auth=ad --proxy=youlend.teleport.sh:443 > /dev/null 2>&1
    # Wait until login completes (max 15 seconds)
    for i in {1..30}; do
        if tsh status 2>/dev/null | grep -q 'Logged in as:'; then
        printf "\n\033[1;32mLogged in successfully!\033[0m\n"
        sleep 1
        return 0
        fi
        sleep 0.5
    done

    printf "\n❌ \033[1;31mTimed out waiting for Teleport login.\033[0m"
    return 1
}

th_kill() {
    printf "\033c"
    create_header "Cleanup"
    printf "🧹 \033[1mCleaning up Teleport session...\033[0m"

    # Enable nullglob in Zsh to prevent errors from unmatched globs
    if [ -n "$ZSH_VERSION" ]; then
        setopt NULL_GLOB
    fi

    # Remove temp credential files
    for f in /tmp/yl* /tmp/tsh* /tmp/admin_*; do
        [ -e "$f" ] && rm -f "$f"
    done

    # Determine which shell profile to clean
    local shell_name shell_profile
    shell_name=$(basename "$SHELL")

    if [ "$shell_name" = "zsh" ]; then
        shell_profile="$HOME/.zshrc"
    elif [ "$shell_name" = "bash" ]; then
        shell_profile="$HOME/.bash_profile"
    else
        echo "Unsupported shell: $shell_name. Skipping profile cleanup."
        shell_profile=""
    fi

    # Remove any lines sourcing proxy envs from the profile
    if [ -n "$shell_profile" ] && [ -f "$shell_profile" ]; then
        sed -i.bak '/[[:space:]]*source \/tmp\/tsh_proxy_/d' "$shell_profile"
        printf "\n\n✏️ \033[0mRemoving source lines from $shell_profile...\033[0m"
    fi

    printf "\n📃 \033[0mRemoving ENVs...\033[0m"

    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_CA_BUNDLE
    unset HTTPS_PROXY
    unset ACCOUNT
    unset AWS_DEFAULT_REGION

    printf "\n💀 \033[0mKilling all running tsh proxies...\033[0m\n\n"
    # Kill all tsh proxy aws processes
    ps aux | grep '[t]sh proxy aws' | awk '{print $2}' | xargs kill 2>/dev/null
    ps aux | grep '[t]sh proxy db' | awk '{print $2}' | xargs kill 2>/dev/null
    
    tsh logout > /dev/null 2>&1
    tsh apps logout > /dev/null 2>&1
    
    printf "\n✅ \033[1;32mLogged out of all apps, clusters & proxies\033[0m\n\n"
}

find_available_port() {
    local port
    for i in {1..100}; do
        port=$((RANDOM % 20000 + 40000))
        if ! nc -z localhost $port &> /dev/null; then
            echo $port
            return 0
        fi
    done
    echo 50000
}

spinner() {
    local pid=$1
    local message=${2:-"Loading.."}
    local spin_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0

    printf '\033[?251'

    while kill -0 $pid 2>/dev/null; do
        local char=${spin_chars:$((i % ${#spin_chars})):1}
        printf "\r\033[K%s %s" "$char" "$message"
        sleep 0.1
        ((i++))
    done

    printf "\r\033[K"
    printf '\033[?25h'
}

load() {
    local job="$1"
    local message="${2:-"Loading.."}"
    {
        set +m
        $job &
        wave_loader $! "$message"
        wait
        set -m
    }   2>/dev/null
}

wave_loader() {
    local pid=$1
    local message="${2:-"Loading.."}"
    printf '\033[?25l'

    # Dynamic wave pattern matching header width (65 chars - same as center_content default)
    local header_width=65
    local wave_len=$header_width
    local blocks=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
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
        
        for i in $(seq 0 $((wave_len - 1))); do
            if [ $i -eq $pos ]; then
                local center=$((wave_len / 2))
                local distance_from_center=$((pos > center ? pos - center : center - pos))
                local max_distance=$((wave_len / 2))
                local height_boost=$((7 - (distance_from_center * 7 / max_distance)))
                if [ $height_boost -lt 0 ]; then
                    height_boost=0
                fi
                line="${line}\033[1;97m${blocks[$height_boost]}\033[0m"
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

# ========================================================================================================================
#                                                       Visual Helpers
# ========================================================================================================================

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

create_header() {
    local header_text="$1"
    local center_spaces="$2"
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
    create_header "Usage" "$center_spaces"
    printf "%s     ╚═ \033[1mth kube       | k\033[0m   : Kubernetes login.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth aws        | a\033[0m   : AWS login.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth db         | d\033[0m   : Log into our various databases.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth terra      | t\033[0m   : Quick log-in to Terragrunt.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth logout     | l\033[0m   : Clean up Teleport session.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth login      | li\033[0m  : Simple log in to Teleport\033[0m\n" "$center_spaces"
    printf "%s     \033[0m\033[38;5;245m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\033[1;34m\033[0m\n" "$center_spaces"
    printf "%s     For specific instructions, run \033[1mth <option> -h\033[0m\n\n" "$center_spaces"

    create_header "Docs" "$center_spaces"
    printf "%s     Run the following commands to access the documentation pages: \n" "$center_spaces"
    printf "%s     ╚═ \033[1mQuickstart:   | th qs\033[0m\n" "$center_spaces"
    printf "%s     ╚═ \033[1mDocs:         | th doc\033[0m\n\n" "$center_spaces"
    create_header "Extras" "$center_spaces"
    printf "%s     Run the following commands to access the extra features: \n" "$center_spaces"
    printf "%s     ╚═ \033[1mth loader            \033[0m: Run loader animation.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth animate [options] \033[0m: Run logo animation.\n" "$center_spaces"
    printf "%s        ╚═ \033[1myl\n" "$center_spaces"
    printf "%s        ╚═ \033[1mth\n" "$center_spaces"
    printf "%s          \033[0m\033[38;5;245m  ▁▁▁▁▁▁▁▁▁▁▁▁▁\033[0m\033[1;97m  ▄▄▄ ▄▁▄  \033[0m\033[38;5;245m▁▁▁▁▁▁▁▁▁▁▁▁▁▁\033[0m\033[1;34m\033[0m\n" "$center_spaces"
    printf "%s          \033[0m\033[38;5;245m ▔▔▔▔▔▔▔▔▔▔▔▔▔▔\033[0m\033[1;97m   ▀  ▀▔▀  \033[0m\033[38;5;245m▔▔▔▔▔▔▔▔▔▔▔▔▔\033[0m\033[1;34m\033[0m\n" "$center_spaces"
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