kube_login() {
    # Enable bash-compatible array indexing for zsh
    [[ -n "$ZSH_VERSION" ]] && setopt KSH_ARRAYS
    
    th_login

    # Direct login if environment argument provided
    if [[ -n "$1" ]]; then 
        kube_quick_login "$1"
        return 0
    fi

    # Temp file for load function used below
    temp_cluster_file=$(mktemp)
    temp_cluster_display_file=$(mktemp)
    temp_cluster_status_file=$(mktemp)
    temp_elevated_access_file=$(mktemp)

    printf "\033c"
    create_header "Available Clusters"
    load check_cluster_access "Checking cluster access..."
    
    # Read results back into arrays
    local cluster_lines=()
    local cluster_display_lines=()
    local login_status=()

    while IFS= read -r line; do
        cluster_lines+=("$line")
    done < "$temp_cluster_file"
    
    while IFS= read -r line; do
        cluster_display_lines+=("$line")
    done < "$temp_cluster_display_file"
    
    while IFS= read -r line; do
        login_status+=("$line")
    done < "$temp_cluster_status_file"

    # Read elevated access status
    local has_elevated_access="false"
    if [[ -f "$temp_elevated_access_file" ]]; then
        has_elevated_access=$(cat "$temp_elevated_access_file")
    fi

    # Clean up temp files
    rm -f "$temp_cluster_file" "$temp_cluster_display_file" "$temp_cluster_status_file" "$temp_elevated_access_file"

    # Find the longest cluster display name for alignment
    local max_length=0
    for line in "${cluster_display_lines[@]}"; do
        if [[ ${#line} -gt $max_length ]]; then
            max_length=${#line}
        fi
    done

    local i
    i=0
    for line in "${cluster_display_lines[@]}"; do
        local cluster_status="${login_status[$i]:-n/a}"
        local cluster_name="${cluster_lines[$i]}"
        local sudo_indicator=""

        # Check if cluster has request role available (only show if user doesn't have elevated access)
        if [[ "$has_elevated_access" == "false" ]]; then
            local clean_cluster_name=$(echo "$cluster_name" | sed 's/-[a-z]*-[a-z]*-[0-9]-[0-9]*$//')
            local request_role=$(load_config_by_account "kube" "$clean_cluster_name" "request_role")
            if [[ -n "$request_role" && "$request_role" != "" ]]; then
                sudo_indicator="$(printf '\033[32m[S]\033[0m')"
            fi
        fi

        case "$cluster_status" in
            ok)
                printf "%2s. %-${max_length}s %s\n" "$(($i + 1))" "$line" "$sudo_indicator"
                ;;
            fail)
                printf "\033[90m%2s. %-${max_length}s %s\033[0m\n" "$(($i + 1))" "$line" "$sudo_indicator"
                ;;
            n/a)
                printf "%2s. %-${max_length}s %s\n" "$(($i + 1))" "$line" "$sudo_indicator"
                ;;
        esac
        i=$((i + 1))
    done

    # Only show the note if user doesn't have elevated access (and thus might see [S] indicators)
    if [[ "$has_elevated_access" == "false" ]]; then
        printf "\033[1A"
        create_note "Note: \033[32m[S]\033[0m indicates cluster requires elevated access."
        printf "\033[1A"
        printf "           Selecting one will start an access request.\n"
    fi
    printf "\n\033[1mSelect cluster (number):\033[0m\n"
    create_input 1 3 50 "Invalid input. " "numerical"
    local input_exit_code=$?
    choice="$user_input"

    if [ $input_exit_code -eq 130 ]; then
        return 130
    fi

    selected_index=$((choice - 1))
    if [[ -z "${cluster_lines[$selected_index]}" ]]; then
        printf "\n\033[31mInvalid selection\033[0m\n"
        return 1
    fi

    selected_cluster="${cluster_lines[$selected_index]}"

    selected_cluster_status="${login_status[$selected_index]}"

    selected_cluster_display="${cluster_display_lines[$selected_index]}"

    if [[ "$selected_cluster_status" == "fail" ]]; then
        kube_elevated_login "$selected_cluster_display"
        local input_exit_code=$?
        if [ $input_exit_code -eq 130 ]; then
            return 130
        fi
    fi

    printf "\033c"
    create_header "Kube Login"
    printf "\033[1mLogging you into:\033[0m \033[1;32m$selected_cluster_display\033[0m\n"
    tsh kube login "$selected_cluster" > /dev/null 2>&1
    printf "\n✅ \033[1mLogged in successfully!\033[0m\n\n"
}