# Show available environments when config lookup fails
show_available_environments() {
    local service_type="$1"  # aws, kube, db
    local error_title="${2:-"Available Environments"}"   # "AWS Login Error", "Kube Login Error", etc.
    local env_arg="$3"       # The invalid environment argument (optional)
    
    # Get config file path from script location
    local config_file
    if [[ -n "$ZSH_VERSION" ]]; then
        local script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
    else
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    config_file="$script_dir/../../../config/th.config.json"
    
    printf "\033c"
    create_header "$error_title"
    
    if [[ -n "$env_arg" ]]; then
        if [[ "$service_type" == "db" ]]; then
            printf "\033[31m❌ Invalid environment format: '$env_arg'\033[0m\n\n"
        else
            printf "\033[31m❌ Environment '$env_arg' not found in configuration.\033[0m\n\n"
        fi
    fi
    
    printf "Available environments:\n"
    
    if [[ ! -f "$config_file" ]]; then
        printf "\033[31m❌ Configuration file not found: $config_file\033[0m\n"
        return 1
    fi
    
    case "$service_type" in
        "aws"|"kube")
            # Find longest key for alignment
            local max_key_len=0
            while read -r env_key; do
                if [ ${#env_key} -gt $max_key_len ]; then
                    max_key_len=${#env_key}
                fi
            done < <(jq -r ".${service_type} | keys[]" "$config_file" 2>/dev/null)
            
            # Display entries with proper alignment
            local field_name
            [[ "$service_type" == "aws" ]] && field_name="account" || field_name="cluster"
            
            jq -r ".${service_type} | to_entries[] | \"\(.key): \(.value.${field_name})\"" "$config_file" 2>/dev/null | while read -r line; do
                local env_key=$(echo "$line" | cut -d':' -f1)
                local value=$(echo "$line" | cut -d':' -f2- | sed 's/^ //')
                printf "• \033[1m%-${max_key_len}s\033[0m : %s\n" "$env_key" "$value"
            done
            ;;
        "db")
            # Collect all DB entries with prefixes
            local all_entries=()
            
            # Add RDS entries with r- prefix
            while read -r env; do
                all_entries+=("r-$env")
            done < <(jq -r '.db.rds | keys[]' "$config_file" 2>/dev/null)
            
            # Add MongoDB entries with m- prefix
            while read -r env; do
                all_entries+=("m-$env")
            done < <(jq -r '.db.mongo | keys[]' "$config_file" 2>/dev/null)
            
            # Find longest entry for alignment
            local max_key_len=0
            for entry in "${all_entries[@]}"; do
                if [ ${#entry} -gt $max_key_len ]; then
                    max_key_len=${#entry}
                fi
            done
            
            # Display RDS entries
            printf "\n\033[1mRDS:\033[0m\n"
            jq -r '.db.rds | to_entries[] | "r-\(.key): \(.value.database)"' "$config_file" 2>/dev/null | while read -r line; do
                local key=$(echo "$line" | cut -d':' -f1)
                local db=$(echo "$line" | cut -d':' -f2- | sed 's/^ //')
                printf "• \033[1m%-${max_key_len}s\033[0m : %s\n" "$key" "$db"
            done
            
            # Display MongoDB entries
            printf "\n\033[1mMongo:\033[0m\n"
            jq -r '.db.mongo | to_entries[] | "m-\(.key): \(.value.database)"' "$config_file" 2>/dev/null | while read -r line; do
                local key=$(echo "$line" | cut -d':' -f1)
                local db=$(echo "$line" | cut -d':' -f2- | sed 's/^ //')
                printf "• \033[1m%-${max_key_len}s\033[0m : %s\n" "$key" "$db"
            done
            ;;
        *)
            printf "\033[31m❌ Unsupported service type: $service_type\033[0m\n"
            return 1
            ;;
    esac
    
    printf "\n"
    return 1
}