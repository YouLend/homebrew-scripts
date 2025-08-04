#===============================================
#================ Kubernetes ===================
#===============================================
kube_login() {
    # Enable bash-compatible array indexing for zsh
    [[ -n "$ZSH_VERSION" ]] && setopt KSH_ARRAYS
    
    if [[ "$reauth_kube" == "true" ]]; then
        printf "\n\033[1mRe-Authenticating\033[0m\n\n"
        tsh logout
        tsh login --auth=ad --proxy=youlend.teleport.sh:443 --request-id="$REQUEST_ID" > /dev/null 2>&1
        reauth_kube="false"
        return 0
    else
        th_login
    fi

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
        printf "\n\033[1mLogging you into:\033[0m \033[1;32m$selected_cluster\033[0m\n"
        tsh kube login "$selected_cluster" > /dev/null 2>&1 
        printf "\n✅ \033[1mLogged in successfully!\033[0m\n\n"
    else
        printf "\n\033[1mLogging you into:\033[0m \033[1;32m$selected_cluster\033[0m\n"
        tsh kube login "$selected_cluster" > /dev/null 2>&1
        printf "\n✅ \033[1mLogged in successfully!\033[0m\n\n"
    fi
}

kube_quick_login() {
    # ql_arg = quick login arg
    local ql_arg="$1"

    local cluster_name
    cluster_name=$(load_kube_config "$ql_arg")
    
    if [[ -z "$cluster_name" ]]; then
        printf "\n\033[31mUnknown environment: $ql_arg\033[0m\n"
        printf "Available environments: dev, sandbox, staging, usstaging, admin, prod, usprod, corepgblue, corepggreen\n"
        return 1
    fi

    printf "\033c"
    create_header "Kube Login"
    
    printf "Logging you into:\033[0m \033[1;32m$cluster_name\033[0m\n"

    tsh kube login "$cluster_name" > /dev/null 2>&1
    
    printf "\n✅ Logged in successfully!\n\n"
}

# Load cluster env mapping for kube quick login
load_kube_config() {
    local env="$1"
    # Handle bash vs zsh differences for script directory detection
    if [[ -n "$ZSH_VERSION" ]]; then
        local script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
    else
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    local config_file="$script_dir/../th.config"
    
    if [[ ! -f "$config_file" ]]; then
        echo ""
        return 1
    fi
    
    source "$config_file"
    local var_name="kube_${env}"
    # Handle indirect variable expansion for zsh vs bash
    if [[ -n "$ZSH_VERSION" ]]; then
        echo "${(P)var_name}"
    else
        echo "${!var_name}"
    fi
}

# Teleport privileged access flow
kube_elevated_login() {
    local cluster="$1"
    while true; do
        printf "\033c" 
        create_header "Privilege Request"
        printf "\n\nYou don't have write access to \033[1m$cluster\033[0m."
        printf "\n\n\033[1mWould you like to raise a request?\033[0m"
        printf "\n\n\033[1mNote:\033[0m Entering (N/n) will log you in as a read-only user."
        printf "\n\n(Yy/Nn): "
        read elevated
        if [[ "$elevated" =~ ^[Yy]$ ]]; then
        printf "\n\033[1mEnter your reason for request: \033[0m"
        read reason

        if [[ "$cluster" == 'live-prod-eks-blue' ]]; then
            request_output=$(tsh request create --roles sudo_prod_eks_cluster --reason "$reason")
        elif [[ "$cluster" == 'live-usprod-eks-blue' ]]; then
            request_output=$(tsh request create --roles sudo_usprod_eks_cluster --reason "$reason")
        else
            printf "\nCluster doesn't exist"
        fi

        # 2. Extract request ID
        REQUEST_ID=$(echo "$request_output" | grep "Request ID:" | awk '{print $3}')

        printf "\n\n✅ \033[1;32mAccess request sent!\033[0m\n\n"
        return 0

        elif [[ "$elevated" =~ ^[Nn]$ ]]; then
        echo
        echo "Request creation skipped."
        return 0
        else
        printf "\n\033[31mInvalid input. Please enter y or n.\033[0m\n"
        fi
    done
}

# Log into *prod* clusters & check write privilege
check_cluster_access() {
    local output clusters
    output=$(tsh kube ls -f json)
    clusters=$(echo "$output" | tr -d '\000-\037' | jq -r '.[].kube_cluster_name' | grep -v '^$')

    if [[ -z "$clusters" ]]; then
        echo "No Kubernetes clusters available."
        return 1
    fi

    # Write to predetermined temp files that parent shell can read
    local access_status="unknown"
    local test_cluster=""
    
    # First pass: write all cluster names and find a test cluster
    while IFS= read -r cluster_name; do
        if [[ -z "$cluster_name" ]]; then
            continue
        fi

        echo "$cluster_name" >> "$temp_cluster_file"
        
        # Find first prod cluster to test with
        if [[ -z "$test_cluster" && "$cluster_name" == *prod* ]]; then
            test_cluster="$cluster_name"
        fi
    done <<< "$clusters"
    
    # Test access with one prod cluster if we found one
    if [[ -n "$test_cluster" ]]; then
        if tsh kube login "$test_cluster" > /dev/null 2>&1; then
            if kubectl auth can-i create pod > /dev/null 2>&1; then
                access_status="ok"
            else
                access_status="fail"
            fi
        else
            access_status="fail"
        fi
    fi
    
    # Second pass: write status for all clusters based on single test
    while IFS= read -r cluster_name; do
        if [[ -z "$cluster_name" ]]; then
            continue
        fi

        if [[ "$cluster_name" == *prod* ]]; then
            echo "$access_status" >> "$temp_cluster_status_file"
        else
            echo "n/a" >> "$temp_cluster_status_file"
        fi
    done <<< "$clusters"
}