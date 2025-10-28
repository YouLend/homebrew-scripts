db_quick_login() {
    local env_arg="$1"
    local port=""
    local cluster_type="rds"  # Default to RDS
    local env_name=""

    if [[ "$env_arg" == m-* ]]; then
        cluster_type="mongo"
        env_name="${env_arg#m-}"
    elif [[ "$env_arg" == r-* ]]; then
        cluster_type="rds"
        env_name="${env_arg#r-}"
    else
        # No valid prefix found - show error
        show_available_environments "db" "DB Login Error" "$env_arg"
        return 1
    fi
    
    # Validate that the extracted environment actually exists in config
    local cluster_name
    cluster_name=$(load_config "db" "$env_name" "database" "$cluster_type")
    
    if [[ -z "$cluster_name" ]]; then
        show_available_environments "db" "DB Login Error" "$env_arg"
        return 1
    fi
    
    # Validate port number if provided in any argument
    for arg in "$@"; do
        if [[ "$arg" =~ ^[0-9]+$ ]]; then
            if [[ "$arg" -lt 10000 || "$arg" -gt 50000 ]]; then
                printf "\033[31m❌ Port number must be between 10000 and 50000\033[0m\n"
                return 1
            fi
            # Check if port is already in use
            if nc -z localhost "$arg" &> /dev/null; then
                printf "\n\033[31m❌ Port $arg is already in use. Please specify a different port.\033[0m\n"
                return 1
            fi
            port="$arg"
            break
        fi
    done

    for arg in "$@"; do
        if [[ "$arg" =~ ^c$ ]]; then
            open_console="true"
            break
        fi
    done

    if [[ "$cluster_type" == "rds" ]]; then
        case "$env_name" in
            "prod"|"uprod"|"asb"|"dsb")
                local request_role
                request_role=$(load_request_role "db" "$env_name" "rds")
                if ! tsh status | grep -q "$request_role"; then
                    db_elevated_login "$request_role" "$cluster_name"
                    local input_exit_code=$?
                    if [ $input_exit_code -eq 130 ]; then
                        return 130
                    fi
                fi
                ;;
        esac
    elif [[ "$cluster_type" == "mongo" ]]; then
        case "$env_name" in
            "prod"|"uprod"|"sb")
                local request_role
                request_role=$(load_request_role "db" "$env_name" "mongo")
                if ! tsh status | grep -q "$request_role"; then
                    db_elevated_login "$request_role" "$cluster_name"
                    local input_exit_code=$?
                    if [ $input_exit_code -eq 130 ]; then
                        return 130
                    fi
                fi
                ;;
        esac
    fi

    if [[ -z "$port" ]]; then port=$(find_available_port); fi

    if [[ $open_console == "true" ]]; then
        if [[ "$cluster_type" == "rds" ]]; then
            list_postgres_databases "$cluster_name" "$port"
            
            local input_exit_code=$?
            if [ $input_exit_code -eq 130 ]; then
                return 130
            fi
            connect_psql "$cluster_name" "$database" "tf_teleport_rds_read_user"
            open_console="false"
        elif [[ "$cluster_type" == "mongo" ]]; then
            mongocli_connect "$cluster_name"
            open_console="false"
        fi        
    else
        printf "\033c"
        create_header "DB Quick Login"
        if [[ "$cluster_type" == "rds" ]]; then
            open_dbeaver "$cluster_name" "tf_teleport_rds_read_user" "$port"
        elif [[ "$cluster_type" == "mongo" ]]; then
            open_atlas "$cluster_name" "$port"
        fi
    fi
}