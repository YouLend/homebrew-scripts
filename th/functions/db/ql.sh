db_quick_login() {
    local env_arg="$1"
    local port=""
    local db_type="rds"  # Default to RDS
    local env_name=""

    if [[ "$env_arg" == m-* ]]; then
        db_type="mongo"
        env_name="${env_arg#m-}"
    elif [[ "$env_arg" == r-* ]]; then
        db_type="rds"
        env_name="${env_arg#r-}"
    else
        # No valid prefix found - show error
        show_available_environments "db" "DB Login Error" "$env_arg"
        return 1
    fi
    
    # Validate that the extracted environment actually exists in config
    local db_name
    db_name=$(load_config "db" "$env_name" "database" "$db_type")
    
    if [[ -z "$db_name" ]]; then
        show_available_environments "db" "DB Login Error" "$env_arg"
        return 1
    fi
    
    # Validate port number if provided in any argument
    for arg in "$@"; do
        if [[ "$arg" =~ ^[0-9]+$ ]]; then
            if [[ "$arg" -lt 30000 || "$arg" -gt 50000 ]]; then
                printf "\033[31m❌ Port number must be between 30000 and 50000\033[0m\n"
                return 1
            fi
            port="$arg"
            break
        fi
    done
    
    # Check for privileged environments requiring elevated access
    if [[ "$db_type" == "rds" ]]; then
        case "$env_name" in
            "pv"|"pb"|"upb"|"upv"|"prod"|"usprod")
                local request_role
                request_role=$(load_request_role "db" "$env_name" "rds")
                if ! tsh status | grep -q "$request_role"; then
                    db_elevated_login "$request_role" "$db_name"
                    if [[ $? -ne 0 ]]; then
                        return 0
                    fi
                fi
                ;;
        esac
    elif [[ "$db_type" == "mongo" ]]; then
        case "$env_name" in
            "prod"|"uprod"|"sand")
                local request_role
                request_role=$(load_request_role "db" "$env_name" "mongo")
                if ! tsh status | grep -q "$request_role"; then
                    db_elevated_login "$request_role" "$db_name"
                    if [[ $? -ne 0 ]]; then
                        return 0
                    fi
                fi
                ;;
        esac
    fi
    
    printf "\033c"
    create_header "DB Quick Login"

    if [[ -z "$port" ]]; then port=$(find_available_port); fi
    
    if [[ "$db_type" == "rds" ]]; then
        open_dbeaver "$db_name" "tf_teleport_rds_read_user" "$port"
    elif [[ "$db_type" == "mongo" ]]; then
        open_atlas "$db_name" "$port"
    fi
}