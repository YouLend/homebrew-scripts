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