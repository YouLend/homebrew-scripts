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