# Quick AWS login
aws_quick_login() {
    local env_arg="$1"
    local flags="$2"
    local open_browser=false
    local sudo_flag=""
    local super_sudo=false
    
    # Parse combined flags
    if [[ "$flags" == *"ss"* ]]; then
        super_sudo=true
        sudo_flag="ss"
    elif [[ "$flags" == *"s"* ]]; then
        sudo_flag="s"
    fi
    
    if [[ "$flags" == *"b"* ]]; then
        open_browser=true
    fi
    
    local account_name
    account_name=$(load_config "aws" "$env_arg" "account")
    
    # Check if the environment exists in config
    if [ -z "$account_name" ]; then
        show_available_environments "aws" "AWS Login Error" "$env_arg"
        return 1
    fi
    
    local role_value
    role_value=$(load_config "aws" "$env_arg" "role")
    
    if [ -z "$role_value" ]; then
        role_value="${env_arg}"
    fi
    
    if [[ "$sudo_flag" == "ss" ]]; then
        # Super sudo requires TeamLead role
        if ! tsh apps login $account_name 2>&1 > /dev/null | grep -q super_sudo_$role_value ; then
            printf "\n\033[31m❌ Error: You don't have access to super_sudo roles.\033[0m\n"
            return 1
        fi
    elif [[ "$sudo_flag" == "s" ]]; then
        # Regular sudo check
        local required_role="sudo_${role_value}_role"
        if ! tsh apps login $account_name 2>&1 > /dev/null | grep -q sudo_$role_value ; then
            aws_elevated_login "$account_name" "$role_value"
            if [ "$reauth_aws" == "FALSE" ]; then
                return 0
            fi
        fi
    fi
    
    printf "\033c"
    create_header "AWS Login"
    
    local role_name
    if [[ "$sudo_flag" == "ss" ]]; then
        role_name="super_sudo_${role_value}" > /dev/null 2>&1
        printf "Logging you into: \033[1;32m$account_name\033[0m as \033[1;32m$role_name\033[0m\n"
    elif [[ "$sudo_flag" == "s" ]]; then
        role_name="sudo_${role_value}" > /dev/null 2>&1
        printf "Logging you into: \033[1;32m$account_name\033[0m as \033[1;32m$role_name\033[0m\n"
    else
        role_name="${role_value}" > /dev/null 2>&1
        printf "Logging you into: \033[1;32m$account_name\033[0m as \033[1;32m$role_name\033[0m\n"
    fi

    tsh apps logout > /dev/null 2>&1
    tsh apps login "$account_name" --aws-role "$role_name" > /dev/null 2>&1

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
        create_proxy "$account_name" "$role_name"
    fi
    
    return 0
}