aws_elevated_login(){
    local app="$1"
    local default_role="$2"
    printf "\033c" 
    create_header "Privilege Request"
    printf "No privileged roles found. Your only available role is: \033[1;32m%s\033[0m" $default_role

    while true; do
        printf "\n\n\033[1mWould you like to raise a privilege request?\033[0m"
        create_note "Entering (N/n) will log you in as \033[1;32m$default_role\033[0m. "
        printf "(Yy/Nn):\033[0m "
        read request
        if [[ $request =~ ^[Yy]$ ]]; then
            printf "\n\033[1mEnter request reason:\033[0m "
            read reason

            request_role="sudo_${default_role}_role"
            
            echo
            tsh request create --roles $request_role --reason "$reason" --max-duration 4h  2>&1 
            
            reauth_aws="TRUE"
            return 0
        elif [[ $request =~ ^[Nn]$ ]]; then
            printf "\033c"
            create_header "AWS Login"
            printf "\033[1mLogging you in to \033[1;32m$app\033[0m \033[1mas\033[0m \033[1;32m$default_role\033[0m" 
            tsh apps login "$app" > /dev/null 2>&1
            printf "\n\n✅\033[1;32m Logged in successfully!\033[0m\n" 
            create_proxy "$app" "$default_role"
            reauth_aws="FALSE"
            return 0
        else
            printf "\n\033[31mInvalid input. Please enter y or n.\033[0m\n"
        fi
    done
}

# Create proxy & source credentials
create_proxy() {
    local app="$1"
    local role_name="$2"
    # Enable nullglob in Zsh to avoid errors on unmatched globs
    if [ -n "$ZSH_VERSION" ]; then
        setopt NULL_GLOB
    fi

    if [ -z "$app" ]; then
        echo "No active app found. Run 'tsh apps login <app>' first."
        return 1
    fi

    local log_file="/tmp/tsh_proxy_${app}.log"

    for f in /tmp/yl* /tmp/tsh* /tmp/admin_*; do
        [ -e "$f" ] && rm -f "$f"
    done

    printf "\nCleaned up existing credential files.\n"

    printf "\nStarting AWS proxy for \033[1;32m$app\033[0m...\n"

    {
        set +m
        tsh proxy aws --app "$app" > "$log_file" 2>&1 &
        disown
        set -m
    } > /dev/null 2>&1

    # Wait up to 10 seconds for credentials to appear
    local wait_time=0
    while ! grep -q '^  export AWS_ACCESS_KEY_ID=' "$log_file"; do
        sleep 0.5
        wait_time=$((wait_time + 1))
        if (( wait_time >= 20 )); then
        echo "Timed out waiting for AWS credentials."
        return 1
        fi
    done

    # Retain only export lines
    printf "%s\n" "$(grep -E '^[[:space:]]*export ' "$log_file")" > "$log_file"

    # Source all export lines into the shell
    while read -r line; do
        [[ $line == export* || $line == "  export"* ]] && eval "$line"
    done < "$log_file"

    export ACCOUNT=$app
    export ROLE=$role_name
    echo "export ACCOUNT=$app" >> "$log_file"
    echo "export ROLE=$role_name" >> "$log_file"

    # Determine shell and modify appropriate profile
    local shell_name shell_profile
    shell_name=$(basename "$SHELL")

    if [ "$shell_name" = "zsh" ]; then
        shell_profile="$HOME/.zshrc"
    elif [ "$shell_name" = "bash" ]; then
        shell_profile="$HOME/.bash_profile"
    else
        shell_profile="$HOME/.profile"  # fallback
    fi

    sed -i.bak '/^source \/tmp\/tsh/d' "$shell_profile"
    echo "source $log_file" >> "$shell_profile"

    # Set region based on app name
    if [[ $app =~ ^yl-us ]]; then
        export AWS_DEFAULT_REGION=us-east-2
        echo "export AWS_DEFAULT_REGION=us-east-2" >> "$log_file"
    else
        export AWS_DEFAULT_REGION=eu-west-1
        echo "export AWS_DEFAULT_REGION=eu-west-1" >> "$log_file"
    fi

    printf "\nCredentials exported, and made global, for app: \033[1;32m$app\033[0m\n\n"
} 