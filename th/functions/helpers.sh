# ========================
# Helper - Teleport Login
# ========================
th_login() {
    printf "\033c"
    create_header "Login"
    printf "Checking login status...\n"
    # if ! tsh apps ls &>/dev/null; then
    #     printf "TSH connection failed. Cleaning up existing sessions & reauthenticating...\n\n"
    #     th_kill
    # fi
    if tsh status 2>/dev/null | grep -q 'Logged in as:'; then
        printf "\n✅ \033[1mAlready logged in to Teleport!\033[0m\n"
        sleep 1
        return 0
    fi
    printf "\nLogging you into Teleport...\n"
    #tsh login --proxy=youlend.teleport.sh:443 --auth=local --user=oladele.oloruntimilehin@gmail.com youlend.teleport.sh
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

  
# ========================
# Helper - Teleport Logout
# ========================
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

create_header() {
    local header_text="$1"
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
    
    printf "\033[0m\033[38;5;245m    ▄███████▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀███████████▀\033[0m\033[1;34m\033[0m\n"
    printf "\033[0m\033[38;5;245m  %s\033[0m\033[1m %s \033[0m\033[38;5;245m%s\033[0m\033[1;34m\033[0m\n" "$left_dash_str" "$header_text" "$right_dash_str"
    printf "\033[0m\033[38;5;245m▄███████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄███████▀\033[0m\033[1;34m\033[0m\n\n"
}

create_note() {
    local note_text="$1"
    local note_length=${#note_text}

    printf "\n\n\033[0m\033[38;5;245m▄██▀ $note_text\033[0m\033[1;34m\033[0m\n\n"
}

