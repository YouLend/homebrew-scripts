# Quick AWS login
aws_quick_login() {
    local env_arg="$1"
    local flags="$2"
    local open_browser=false
    local use_sudo=false
    
    if [[ "$flags" == *"s"* ]]; then
        use_sudo=true
    fi
    
    if [[ "$flags" == *"b"* ]]; then
        open_browser=true
    fi
    
    local account
    account=$(load_config "aws" "$env_arg" "account")
    
    # Check if the environment exists in config
    if [ -z "$account" ]; then
        show_available_environments "aws" "AWS Login Error" "$env_arg"
        return 1
    fi

    local aws_role # The role passed to tsh apps login & proxy (required due to differences in product dev & management roles)
    local teleport_role # The base role fetched from config
    
    teleport_role=$(load_config_by_account "aws" "$account" "role")

    if [[ $(tsh status | grep "Platform") ]]; then
        aws_role=$teleport_role
        dev_type="platform"
    else
        aws_role="teleport-dev"
        dev_type="dev"
    fi

    # Check if user requested sudo (from 's' flag)
    if [ "$use_sudo" = true ]; then
        if check_sudo "$account" "$dev_type"; then
            case "$aws_role" in
                "management")
                    sudo_role="sudo_management_role"
                    aws_role="sudo_management"
                ;;
                "teleport-dev")
                    sudo_role="sudo-${teleport_role%-platform}-dev"
                    aws_role="sudo-teleport-dev"
                ;;
                *)
                    sudo_role="sudo-$teleport_role"
                    aws_role="$sudo_role"
                ;;
            esac
            aws_elevated_login "$account" "$sudo_role"
            # Exit if aws_elevated_login was cancelled (Ctrl+C)
            if [ $? -eq 130 ]; then
                return 130
            fi
        else
            printf "\033c"
            create_header "AWS Login"
            printf "\033[33m⚠️  No sudo role available for this account. Logging in with base role.\033[0m\n"
            sleep 2
        fi
    fi
    
    printf "\033c"
    create_header "AWS Login"

    printf "Logging you into: \033[1;32m$account\033[0m as \033[1;32m$aws_role\033[0m\n"
    
    #tsh apps logout > /dev/null 2>&1
    tsh apps login "$account" --aws-role "$aws_role" > /dev/null 2>&1

    printf "\n✅ Logged in successfully!\n"
    
    # Skip proxy creation if browser flag is set, open console instead
    if [[ "$open_browser" == "true" ]]; then
        printf "\n🌐 Opening AWS console in browser...\n"
        base_url="https://youlend.teleport.sh/web/launch"
        app_url=$(tsh apps config | grep URI | awk '{print $2}' | sed 's/https:\/\///')
        role=$(tsh apps config | grep "AWS ARN" | awk '{print $3}' | sed 's/\//%2F/g')
        url="$base_url/$app_url/youlend.teleport.sh/$app_url/$role"
        open "$url"
    else
        create_proxy "$account" "$aws_role"
    fi
}