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
    temp_cluster_status_file=$(mktemp)

    printf "\033c"
    create_header "Available Clusters"
    load check_cluster_access "Checking cluster access..."
    
    # Read results back into arrays
    local cluster_lines=()
    local login_status=()

    while IFS= read -r line; do
        cluster_lines+=("$line")
    done < "$temp_cluster_file"
    
    while IFS= read -r line; do
        login_status+=("$line")
    done < "$temp_cluster_status_file"
    
    # Clean up temp files
    rm -f "$temp_cluster_file" "$temp_cluster_status_file"

    local i
    i=0
    for line in "${cluster_lines[@]}"; do
        local cluster_status="${login_status[$i]:-n/a}"

        case "$cluster_status" in
            ok)
                printf "%2s. %s\n" "$(($i + 1))" "$line"
                ;;
            fail)
                printf "\033[90m%2s. %s\033[0m\n" "$(($i + 1))" "$line"
                ;;
            n/a)
                printf "%2s. %s\n" "$(($i + 1))" "$line"
                ;;
        esac
        i=$((i + 1))
    done

    printf "\n\033[1mSelect cluster (number):\033[0m "
    read choice

    if [[ -z "$choice" ]]; then
        echo "No selection made. Exiting."
        return 1
    fi

    selected_index=$((choice - 1))
    if [[ -z "${cluster_lines[$selected_index]}" ]]; then
        printf "\n\033[31mInvalid selection\033[0m\n"
        return 1
    fi

    selected_cluster="${cluster_lines[$selected_index]}"
    selected_cluster_status="${login_status[$selected_index]}"

    if [[ "$selected_cluster_status" == "fail" ]]; then
        kube_elevated_login "$selected_cluster"
    fi

    if [[ "$reauth_kube" == "true" ]]; then
        printf "\n\033[1mRe-Authenticating\033[0m\n\n"
        tsh logout
        tsh login --auth=ad --proxy=youlend.teleport.sh:443 --request-id="$REQUEST_ID" > /dev/null 2>&1
        reauth_kube="false"
        return 0   
    fi

    printf "\n\033[1mLogging you into:\033[0m \033[1;32m$selected_cluster\033[0m\n"
    tsh kube login "$selected_cluster" > /dev/null 2>&1
    #export NO_PROXY="oidc.eks.eu-west-1.amazonaws.com,${NO_PROXY:-}"
    printf "\n✅ \033[1mLogged in successfully!\033[0m\n\n"
}
