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

demo_wave_loader() {
    local message="${1:-"Demo Wave Loader"}"
    
    sleep 99999 &
    local dummy_pid=$!
    
    trap "kill $dummy_pid 2>/dev/null; printf '\033[?25h\n'; exit 0" INT
    
    printf "\033c"

    printf "\nPress Ctrl+C to exit (Spam it, if it doesn't work first time!)\n\n"
    
    wave_loader $dummy_pid "$message"
}