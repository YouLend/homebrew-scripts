#===============================================
#=================== AWS =======================
#===============================================

# ========================
# Main - Interactive Login
# ========================
aws_login() {
    if [ "$reauth_aws" == "TRUE" ]; then
        # Once the user returns from the elevated login, re-authenticate with request id.
        printf "\n\033[1mRe-Authenticating\033[0m\n\n"
        tsh logout
        tsh login --auth=ad --proxy=youlend.teleport.sh:443 --request-id="$REQUEST_ID" > /dev/null 2>&1
        reauth_aws="FALSE"
        return 0
    else
        th_login
        echo
    fi

    local json_output filtered app
    tsh apps logout
    # Fetch JSON output from tsh
    json_output=$(tsh apps ls --format=json)

    # Filter and enumerate matching databases
    printf "\n\033[1;4mAvailable accounts:\033[0m\n\n"
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

    # Log out of the selected app to force fresh AWS role output.
    tsh apps logout > /dev/null 2>&1
    # Clear screen
    printf "\033c"

    # Run tsh apps login to capture the AWS roles listing.
    # (This command will error out because --aws-role is required, but it prints the available AWS roles.)
    local login_output
    login_output=$(tsh apps login "$app" 2>&1)

    # Extract the AWS roles section.
    # The section is expected to start after "Available AWS roles:" and end before the error message.
    local role_section
    role_section=$(echo "$login_output" | awk '/Available AWS roles:/{flag=1; next} /ERROR: --aws-role flag is required/{flag=0} flag')

    # Remove lines that contain "ERROR:" or that are empty.
    role_section=$(echo "$role_section" | grep -v "ERROR:" | sed '/^\s*$/d')

    if [ -z "$role_section" ]; then
        local default_role="$(echo "$login_output" | grep -o 'arn:aws:iam::[^ ]*' | awk -F/ '{print $NF}')"
        printf "\033c" 
        printf "\n====================== \033[1mPrivilege Request\033[0m =========================="
        printf "\n\nNo privileged roles found. Your only available role is: \033[1;32m%s\033[0m" $default_role
        while true; do
            printf "\n\n\033[1mWould you like to raise a privilege request?\033[0m"
            printf "\n\n\033[1mNote:\033[0m Entering (N/n) will log you in as \033[1;32m$default_role\033[0m. "
            printf "\n\n(Yy/Nn):\033[0m "
            read request
            if [[ $request =~ ^[Yy]$ ]]; then
                raise_request "$app"
            elif [[ $request =~ ^[Nn]$ ]]; then
                printf "\n\033[1mLogging you in to \033[1;32m$app\033[0m \033[1mas\033[0m \033[1;32m$default_role\033[0m" 
                tsh apps login "$app" > /dev/null 2>&1
                printf "\n\n✅\033[1;32m Logged in successfully!\033[0m\n" 
                create_proxy
                return
            else
                printf "\n\033[31mInvalid input. Please enter y or n.\033[0m\n"
            fi
        done
    fi

    # Assume the first 2 lines of role_section are headers.
    local roles_list
    roles_list=$(echo "$role_section" | tail -n +3 | awk '{print $1}' | sed '/^\s*$/d')

    printf "\n\033[1;4mAvailable roles:\033[0m\n\n"
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
    create_proxy
}

# ========================
# Helper - Get Credentials
# ========================
create_proxy() {
    # Enable nullglob in Zsh to avoid errors on unmatched globs
    if [ -n "$ZSH_VERSION" ]; then
        setopt NULL_GLOB
    fi

    local app
    app=$(tsh apps ls -f text | awk '$1 == ">" { print $2 }')

    if [ -z "$app" ]; then
        echo "No active app found. Run 'tsh apps login <app>' first."
        return 1
    fi

    local log_file="/tmp/tsh_proxy_${app}.log"
    # Try other methods to kill existing processes
    # pkill -f "tsh proxy aws" 2>/dev/null

    for f in /tmp/yl* /tmp/tsh* /tmp/admin_*; do
        [ -e "$f" ] && rm -f "$f"
    done

    printf "\nCleaned up existing credential files.\n"

    printf "\nStarting AWS proxy for \033[1;32m$app\033[0m... Process id: "

    tsh proxy aws --app "$app" > "$log_file" 2>&1 &

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
    echo "export ACCOUNT=$app" >> "$log_file"

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

    printf "\nCredentials exported, and made global, for app: \033[1;32m$app\033[0m"
} 

# ========================
# Helper - Create Request 
# ========================
raise_request(){
    local app="$1"
    printf "\n\033[1mEnter request reason:\033[0m "
    read reason
    if [[ $app == "yl-production" ]]; then
        request_output=$(tsh request create --roles sudo_prod_role --reason "$reason" 2>&1 | tee /dev/tty)

        # 2. Extract request ID
        REQUEST_ID=$(echo "$request_output" | grep "Request ID:" | awk '{print $3}')

        printf "\n\n✅ \033[1;32mAccess request sent!\033[0m\n\n"

        reauth_aws="TRUE"
        return 0
    elif [[ $app == "yl-usproduction" ]]; then
        request_output=$(tsh request create --roles sudo_usprod_role --reason "$reason" 2>&1 | tee /dev/tty)

        # 2. Extract request ID
        REQUEST_ID=$(echo "$request_output" | grep "Request ID:" | awk '{print $3}')

        printf "\n\n✅ \033[1;32mAccess request sent!\033[0m\n\n"

        reauth_aws="TRUE"
        return 0
    else
        printf "\nNo associated roles"
        return 1 
    fi
}

#===============================================
#================= Terraform ===================
#===============================================
terraform_login() {
    th_login     
    tsh apps logout > /dev/null 2>&1
    printf "\n\033[1mLogging into \033[1;32myl-admin\033[0m \033[1mas\033[0m \033[1;32msudo_admin\033[0m\n"
    tsh apps login "yl-admin" --aws-role "sudo_admin" > /dev/null 2>&1
    create_proxy
    printf "\n\n✅ \033[1;32mLogged in successfully!\033[0m"
}

