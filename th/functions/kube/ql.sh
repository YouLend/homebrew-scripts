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
            local request_role=$(load_request_role "kube" "$ql_arg")
            if [[ -n "$request_role" ]] && ! tsh status | grep -q "$request_role"; then
                kube_elevated_login "$cluster_name" "$ql_arg"
                if [[ "$reauth_kube" == "true" ]]; then
                    printf "\n\033[1mRe-Authenticating\033[0m\n\n"
                    tsh logout
                    tsh login --auth=ad --proxy=youlend.teleport.sh:443 --request-id="$REQUEST_ID" > /dev/null 2>&1
                    reauth_kube="false"
                    return 0
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