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
    
    # Check for privileged environments requiring elevated access (only for RDS)
    if [[ "$db_type" == "rds" ]]; then
        case "$env_name" in
            "pv"|"pb"|"upb"|"upv"|"prod"|"usprod")
                if ! tsh status | grep -q "sudo_teleport_rds_read_role"; then
                    db_elevated_login "sudo_teleport_rds_read_role" "$env_name"
                fi
                ;;
        esac
    fi

    if [[ "$reauth_db" == "TRUE" ]]; then
        # Once the user returns from the elevated login, re-authenticate with request id.
        printf "\033c"
        printf "Re-Authenticating"
        tsh logout
        tsh login --auth=ad --proxy=youlend.teleport.sh:443 --request-id="$REQUEST_ID" > /dev/null 2>&1
        reauth_db="FALSE"
    fi
    
    local db_name
    db_name=$(load_config "db" "$env_name" "database" "$db_type")
    
    if [[ -z "$db_name" ]]; then
        printf "\033c"
        create_header "DB Login Error"
        printf "\n\033[31m❌ Environment '$env_name' not found for $db_type.\033[0m\n\n"
        return 1
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