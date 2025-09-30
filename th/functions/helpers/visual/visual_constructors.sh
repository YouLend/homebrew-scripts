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