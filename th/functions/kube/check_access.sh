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

        # Extract everything before -eks, then add color back
        # aslive-staging-eks-blue-us-east-2-973302516471 -> aslive-staging-blue
        prefix="${cluster_name%-eks-*}"
        
        # Strip region-account suffix (pattern: -region-number)
        prefix=$(echo "$prefix" | sed 's/-[a-z][a-z]-[a-z]*-[0-9]-[0-9]*$//')
        
        if [[ "$cluster_name" == *"-eks-blue"* ]]; then
            display_name="$prefix-blue"
        elif [[ "$cluster_name" == *"-eks-green"* ]]; then
            display_name="$prefix-green"
        else
            display_name="$prefix"
        fi

        echo "$cluster_name" >> "$temp_cluster_file"
        echo "$display_name" >> "$temp_cluster_display_file"
        
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