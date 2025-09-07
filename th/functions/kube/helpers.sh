kube_elevated_login() {
    local cluster="$1"
    
    while true; do
        printf "\033c" 
        create_header "Privilege Request"
        printf "You don't have write access to \033[1;32m$cluster\033[0m."
        printf "\n\n\033[1mWould you like to raise a request?\033[0m"
        create_note "Entering (N/n) will log you in as a read-only user."
        printf "(Yy/Nn): "
        read elevated
        if [[ "$elevated" =~ ^[Yy]$ ]]; then
        printf "\n\033[1mEnter your reason for request: \033[0m"
        read reason

        echo
        tsh request create --roles "production-eks-clusters" --reason "$reason" --max-duration 4h

        reauth_kube="true"
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