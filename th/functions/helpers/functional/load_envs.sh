# Generic function to load config values
load_config() {
    local service_type="$1"  # kube, aws, db
    local env="$2"
    local field="$3"  # cluster, account, role, database, request_role
    local db_type="$4"  # optional, only for db service
    
    # Handle bash vs zsh differences for script directory detection
    if [[ -n "$ZSH_VERSION" ]]; then
        local script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
    else
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi

    local config_file="$script_dir/../../../config/th.config.json"
    
    if [[ ! -f "$config_file" ]]; then
        echo ""
        return 1
    fi
    
    case "$service_type" in
        "db")
            if [[ -n "$db_type" ]]; then
                jq -r ".db.${db_type}.${env}.${field} // empty" "$config_file"
            else
                echo ""
                return 1
            fi
            ;;
        "kube"|"aws")
            jq -r ".${service_type}.${env}.${field} // empty" "$config_file"
            ;;
        *)
            echo ""
            return 1
            ;;
    esac
}

# Convenience function for loading request roles (backward compatibility)
load_request_role() {
    local service_type="$1"
    local env="$2"
    local db_type="$3"

    load_config "$service_type" "$env" "request_role" "$db_type"
}

# Get config value by account name
load_config_by_account() {
    local service_type="$1"  # aws
    local account_name="$2"  # e.g., "yl-admin"
    local field="$3"  # role, account, etc

    # Handle bash vs zsh differences for script directory detection
    if [[ -n "$ZSH_VERSION" ]]; then
        local script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
    else
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi

    local config_file="$script_dir/../../../config/th.config.json"

    if [[ ! -f "$config_file" ]]; then
        echo ""
        return 1
    fi

    # Find the environment key for the given account name
    local env_key=$(jq -r ".${service_type} | to_entries[] | select(.value.account == \"${account_name}\") | .key" "$config_file")

    if [[ -n "$env_key" ]]; then
        load_config "$service_type" "$env_key" "$field"
    else
        echo ""
        return 1
    fi
}

# Check if sudo role is available by account name
check_sudo() {
    local account_name="$1"  # Account name (e.g., "yl-admin")
    local role_type="$2"     # "dev" or "platform"

    # Handle bash vs zsh differences for script directory detection
    if [[ -n "$ZSH_VERSION" ]]; then
        local script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
    else
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi

    local config_file="$script_dir/../../../config/th.config.json"

    if [[ ! -f "$config_file" ]]; then
        return 1
    fi

    # Find the environment key for the given account name
    local env_key=$(jq -r ".aws | to_entries[] | select(.value.account == \"${account_name}\") | .key" "$config_file")

    if [[ -n "$env_key" ]]; then
        local sudo_field="sudo_${role_type}"
        local sudo_available=$(jq -r ".aws.${env_key}.\"${sudo_field}\" // false" "$config_file")

        # Return 0 (success) if true, 1 (failure) if false
        if [[ "$sudo_available" == "true" ]]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}