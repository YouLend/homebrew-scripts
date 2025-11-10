aws_login() {
    th_login

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

    # Determine dev_type early for sudo checking
    local dev_type
    if [[ $(tsh status | grep "Platform") ]]; then
        dev_type="platform"
    else
        dev_type="dev"
    fi

    # Display enumerated names with yl- prefix removed and sudo indicators
    local account_names=($(echo "$filtered" | jq -r '.metadata.name'))
    local max_length=0

    # Find the longest account name (after removing yl- prefix)
    for account_name in "${account_names[@]}"; do
        local display_name="${account_name#yl-}"
        if [[ ${#display_name} -gt $max_length ]]; then
            max_length=${#display_name}
        fi
    done

    # Display accounts with right-aligned sudo indicators
    local counter=1
    for account_name in "${account_names[@]}"; do
        local display_name="${account_name#yl-}"
        local sudo_indicator=""

        # Check if sudo is available for this account by checking config
        local sudo_field="sudo_${dev_type}"
        local has_sudo=$(load_config_by_account "aws" "$account_name" "$sudo_field")
        if [[ "$has_sudo" == "true" ]]; then
            sudo_indicator="$(printf '\033[32m[S]\033[0m')"  # Green [S] for sudo available
        fi

        # Right-align the sudo indicator
        printf "%2d. %-${max_length}s %s\n" "$counter" "$display_name" "$sudo_indicator"
        ((counter++))
    done

    # Prompt for app selection
    printf "\033[A"
    create_note "Note: \033[32m[S]\033[0m indicates sudo role available. Append 's' "
    printf "\033[1A"
    printf "           to account number to request access; i.e. 5s\n\n"
    printf "Select account (number): \n"
    create_input 1 3 50 "Invalid input. " "numerical"
    local input_exit_code=$?
    app_choice="$user_input"

    if [ $input_exit_code -eq 130 ]; then
        return 130
    fi

    # Check for sudo flag and extract numeric part
    local use_sudo=false
    if [[ "$app_choice" =~ s$ ]]; then
        use_sudo=true
        app_choice="${app_choice%s}"  # Strip the 's'
    fi

    # Extract selected app name
    account=$(echo "$filtered" | jq -r ".metadata.name" | sed -n "${app_choice}p")
    local display_app="${app#yl-}"

    local aws_role # The role passed to tsh apps login & proxy (required due to differences in product dev & managemet roles)
    local teleport_role # The base role fetched from config

    teleport_role=$(load_config_by_account "aws" "$account" "role")

    aws_role=$(ternary $dev_type "platform" $teleport_role "teleport-dev")

    if [ "$use_sudo" = true ]; then
        local sudo_field="sudo_${dev_type}"
        local has_sudo=$(load_config_by_account "aws" "$account" "$sudo_field")
        if [[ "$has_sudo" == "true" ]]; then
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
            printf "\033[33m⚠️  No sudo role available for this account.\033[0m\n"
            sleep 2
        fi
    fi

    printf "\033c"
    create_header "$account"

    printf "Logging you into \033[1;32m$account\033[0m as \033[1;32m$aws_role\033[0m"
    tsh apps login "$account" --aws-role "$aws_role" > /dev/null 2>&1
    printf "\n\n✅\033[1;32m Logged in successfully!\033[0m\n" 
    create_proxy $account $aws_role
}