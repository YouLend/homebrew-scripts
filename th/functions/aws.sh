#===============================================
#=================== AWS =======================
#===============================================
aws_login() {
    th_login

    tsh apps logout > /dev/null 2>&1

    if [[ -n "$1" ]]; then
        aws_quick_login "$@"
        return 0
    fi
    
    local json_output filtered app
    # Fetch JSON output from tsh
    json_output=$(tsh apps ls --format=json)

    # Filter and enumerate matching databases
    printf "\033c"
    create_header "Available accounts"
    filtered=$(echo "$json_output" | jq '.[] | select(.metadata.name != null)')  # Optional filtering

    # Display enumerated names
    echo "$filtered" | jq -r '.metadata.name' | nl -w2 -s'. '

    # Prompt for app selection
    echo
    printf "\033[1mSelect account (number):\033[0m "
    read app_choice

    # Validate input: loop until valid number is entered
    while ! [[ "$app_choice" =~ ^[0-9]+$ ]]; do
        printf "\n\033[31mInvalid selection\033[0m\n"
        printf "\033[1mSelect account (number):\033[0m "
        read app_choice
    done

    # Extract selected app name
    app=$(echo "$filtered" | jq -r ".metadata.name" | sed -n "${app_choice}p")

    if [ -z "$app" ]; then
        echo -e "\033[31mNo app found at selection $app_choice. Exiting.\033[0m"
        return 1
    fi

    printf "\nSelected app: \033[1;32m$app\033[0m\n"
    sleep 1

    # Log out of the selected app to force fresh AWS role output.
    tsh apps logout > /dev/null 2>&1

    # Run tsh apps login to capture the AWS roles listing.
    # (This command will error out because --aws-role is required, but it prints the available AWS roles.)
    local login_output role_section 
    login_output=$(tsh apps login "$app" 2>&1)

    # Extract the AWS roles section.
    # The section is expected to start after "Available AWS roles:" and end before the error message.
    role_section=$(echo "$login_output" | awk '/Available AWS roles:/{flag=1; next} /ERROR: --aws-role flag is required/{flag=0} flag')

    # Remove lines that contain "ERROR:" or that are empty.
    role_section=$(echo "$role_section" | grep -v "ERROR:" | sed '/^\s*$/d')

    local default_role="$(echo "$login_output" | grep -o 'arn:aws:iam::[^ ]*' | awk -F/ '{print $NF}')"

    if [ -z "$role_section" ]; then
        aws_elevated_login "$app" "$default_role"
        if [ $? -eq 0 ]; then
            return 0
        fi
    fi

    if [[ "$reauth_aws" == "TRUE" ]]; then
        # Once the user returns from the elevated login, re-authenticate with request id.
        printf "\n\033[1mRe-Authenticating\033[0m\n\n"
        tsh logout
        tsh login --auth=ad --proxy=youlend.teleport.sh:443 --request-id="$REQUEST_ID" > /dev/null 2>&1
        reauth_aws="FALSE"

        # Refresh login output
        login_output=$(tsh apps login "$app" 2>&1)

        role_section=$(echo "$login_output" | awk '/Available AWS roles:/{flag=1; next} /ERROR: --aws-role flag is required/{flag=0} flag')

        role_section=$(echo "$role_section" | grep -v "ERROR:" | sed '/^\s*$/d')
    fi
   
    # Assume the first 2 lines of role_section are headers.
    local roles_list
    roles_list=$(echo "$role_section" | tail -n +3 | awk '{print $1}' | sed '/^\s*$/d')
    
    printf "\033c"
    create_header "Available Roles"
    echo "$roles_list" | nl -w2 -s'. '

    # Prompt for role selection.
    printf "\n\033[1mSelect role (number):\033[0m " 
    read role_choice

    local chosen_role_line role_name
    chosen_role_line=""
    while [ -z "$chosen_role_line" ]; do
        chosen_role_line=$(echo "$roles_list" | sed -n "${role_choice}p")
        if [ -z "$chosen_role_line" ]; then
        printf "\n\033[31mInvalid selection\033[0m\n"
        printf "\n\033[1mSelect role (number):\033[0m "
        read role_choice
        fi
    done

    role_name=$(echo "$chosen_role_line" | awk '{print $1}')

    printf "\nLogging you into \033[1;32m$app\033[0m as \033[1;32m$role_name\033[0m"
    tsh apps login "$app" --aws-role "$role_name" > /dev/null 2>&1
    printf "\n\n✅\033[1;32m Logged in successfully!\033[0m\n" 
    create_proxy $app $role_name
}

# AWS account mapping
load_aws_config() {
    local env="$1"
    # Handle bash vs zsh differences for script directory detection
    if [[ -n "$ZSH_VERSION" ]]; then
        local script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
    else
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    local config_file="$script_dir/../th.config.json"
    
    if [[ ! -f "$config_file" ]]; then
        echo ""
        return 1
    fi
    
    jq -r ".aws.${env}.account // empty" "$config_file"
}

# Load AWS role from config
load_aws_role() {
    local env="$1"
    # Handle bash vs zsh differences for script directory detection
    if [[ -n "$ZSH_VERSION" ]]; then
        local script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
    else
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    local config_file="$script_dir/../th.config.json"
    
    if [[ ! -f "$config_file" ]]; then
        echo ""
        return 1
    fi
    
    jq -r ".aws.${env}.role // empty" "$config_file"
}

# Quick AWS login
aws_quick_login() {
    local env_arg="$1"
    local open_browser=false
    local sudo_flag=""
    
    # Check args 2 onwards for 'b' flag and 's' flag
    shift  # Remove first argument (environment)
    for arg in "$@"; do
        if [[ "$arg" == "b" ]]; then
            open_browser=true
        elif [[ "$arg" == "s" ]]; then
            sudo_flag="s"
        fi
    done
    
    local account_name
    account_name=$(load_aws_config "$env_arg")
    
    # Check if the environment exists in config
    if [ -z "$account_name" ]; then
        printf "\033c"
        create_header "AWS Login Error"
        printf "\033[31m❌ Environment '$env_arg' not found in configuration.\033[0m\n\n"
        printf "Available environments:\n"
        
        # Get config file path
        if [[ -n "$ZSH_VERSION" ]]; then
            local script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
        else
            local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        fi
        local config_file="$script_dir/../th.config.json"
        
        # List available AWS environments
        if [[ -f "$config_file" ]]; then
            # First pass: find the longest key
            local max_key_len=0
            while read -r key; do
                if [ ${#key} -gt $max_key_len ]; then
                    max_key_len=${#key}
                fi
            done < <(jq -r '.aws | keys[]' "$config_file" 2>/dev/null)
            
            # Second pass: format with proper alignment
            jq -r '.aws | to_entries[] | "\(.key): \(.value.account)"' "$config_file" 2>/dev/null | while read -r line; do
                local key=$(echo "$line" | cut -d':' -f1)
                local account=$(echo "$line" | cut -d':' -f2- | sed 's/^ //')
                printf "• \033[1m%-${max_key_len}s\033[0m : %s\n" "$key" "$account"
            done
        fi
        printf "\n"
        return 1
    fi

    printf "\033c"
    create_header "AWS Login"
    
    local role_name
    local role_value
    role_value=$(load_aws_role "$env_arg")
    
    if [ -z "$role_value" ]; then
        role_value="${env_arg}"
    fi
    
    if [[ "$sudo_flag" == "s" ]]; then
        role_name="sudo_${role_value}" > /dev/null 2>&1
        printf "Logging you into: \033[1;32m$account_name\033[0m as \033[1;32m$role_name\033[0m\n"
    else
        role_name="${role_value}" > /dev/null 2>&1
        printf "Logging you into: \033[1;32m$account_name\033[0m as \033[1;32m$role_name\033[0m\n"
    fi
    

    printf "\nFinish"
    return 0

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

            role=$([ "$app" = "yl-production" ] && echo "sudo_prod_role" || echo "sudo_usprod_role")
            
            request_output=$(tsh request create --roles $role --reason "$reason" 2>&1 | tee /dev/tty)
            REQUEST_ID=$(echo "$request_output" | grep "Request ID:" | awk '{print $3}')
            
            printf "\n\n✅ \033[1;32mAccess request sent!\033[0m\n\n"
            reauth_aws="TRUE"
            return 
        elif [[ $request =~ ^[Nn]$ ]]; then
            printf "\n\033[1mLogging you in to \033[1;32m$app\033[0m \033[1mas\033[0m \033[1;32m$default_role\033[0m" 
            tsh apps login "$app" > /dev/null 2>&1
            printf "\n\n✅\033[1;32m Logged in successfully!\033[0m\n" 
            create_proxy "$app" "$default_role"
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

#===============================================
#================= Terraform ===================
#===============================================
terraform_login() {
    th_login     
    printf "\033c"
    create_header "Terragrunt Login"
    tsh apps logout > /dev/null 2>&1
    printf "\033[1mLogging into \033[1;32myl-admin\033[0m \033[1mas\033[0m \033[1;32msudo_admin\033[0m\n"
    tsh apps login "yl-admin" --aws-role "sudo_admin" > /dev/null 2>&1
    create_proxy "yl-admin" "sudo_admin"
}