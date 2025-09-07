kube_quick_login() {
    local ql_arg="$1"

    local cluster_name
    cluster_name=$(load_config "kube" "$ql_arg" "cluster")
    
    if [[ -z "$cluster_name" ]]; then
        show_available_environments "kube" "Kube Login Error" "$ql_arg"
        return 1
    fi

    # Check for privileged environments requiring elevated access
    case "$ql_arg" in
        "prod"|"uprod")
            local request_role
            request_role=$(load_request_role "kube" "$ql_arg")
            if [[ -n "$request_role" ]]; then
                if ! tsh status | grep -q "$request_role"; then
                    kube_elevated_login "$cluster_name"
                fi
            fi
            ;;
    esac

    printf "\033c"
    create_header "Kube Login"
    
    printf "Logging you into:\033[0m \033[1;32m$cluster_name\033[0m\n"

    tsh kube login "$cluster_name" > /dev/null 2>&1
    
    printf "\n✅ Logged in successfully!\n\n"
}