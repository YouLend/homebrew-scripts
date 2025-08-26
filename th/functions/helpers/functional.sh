# Get cached th version (updated only on th updates)
get_th_version() {
    local version_cache="$HOME/.cache/th_version"
    if [ -f "$version_cache" ]; then
        cat "$version_cache"
    else
        # First time or cache missing - create it
        mkdir -p "$(dirname "$version_cache")"
        brew list --versions th 2>/dev/null | awk '{print $2}' > "$version_cache"
        cat "$version_cache" 2>/dev/null || echo "unknown"
    fi
}

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

    local config_file="$script_dir/../../config/th.config.json"
    
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

# Show available environments when config lookup fails
show_available_environments() {
    local service_type="$1"  # aws, kube, db
    local error_title="${2:-"Available Environments"}"   # "AWS Login Error", "Kube Login Error", etc.
    local env_arg="$3"       # The invalid environment argument (optional)
    
    # Get config file path using git root
    local config_file
    if git rev-parse --show-toplevel &>/dev/null; then
        config_file="$(git rev-parse --show-toplevel)/th/th.config.json"
    else
        # Fallback to relative path
        if [[ -n "$ZSH_VERSION" ]]; then
            local script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
        else
            local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        fi
        config_file="$script_dir/../../config/th.config.json"
    fi
    
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
            while read -r key; do
                if [ ${#key} -gt $max_key_len ]; then
                    max_key_len=${#key}
                fi
            done < <(jq -r ".${service_type} | keys[]" "$config_file" 2>/dev/null)
            
            # Display entries with proper alignment
            local field_name
            [[ "$service_type" == "aws" ]] && field_name="account" || field_name="cluster"
            
            jq -r ".${service_type} | to_entries[] | \"\(.key): \(.value.${field_name})\"" "$config_file" 2>/dev/null | while read -r line; do
                local key=$(echo "$line" | cut -d':' -f1)
                local value=$(echo "$line" | cut -d':' -f2- | sed 's/^ //')
                printf "• \033[1m%-${max_key_len}s\033[0m : %s\n" "$key" "$value"
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

th_login() {
    printf "\033c"
    create_header "Login"
    printf "Checking login status...\n"
    # Check if already logged in
    if tsh status 2>/dev/null | grep -q 'Logged in as:'; then
        cprintf "\n✅ \033[1mAlready logged in to Teleport!\033[0m\n"
        sleep 1
        return 0
    fi
    printf "\nLogging you into Teleport...\n"
    tsh login --auth=ad --proxy=youlend.teleport.sh:443 > /dev/null 2>&1
    # Wait until login completes (max 15 seconds)
    for i in {1..30}; do
        if tsh status 2>/dev/null | grep -q 'Logged in as:'; then
        printf "\n\033[1;32mLogged in successfully!\033[0m\n"
        sleep 1
        return 0
        fi
        sleep 0.5
    done

    printf "\n❌ \033[1;31mTimed out waiting for Teleport login.\033[0m"
    return 1
}

th_kill() {
    printf "\033c"
    create_header "Cleanup"
    printf "🧹 \033[1mCleaning up Teleport session...\033[0m"

    # Enable nullglob in Zsh to prevent errors from unmatched globs
    if [ -n "$ZSH_VERSION" ]; then
        setopt NULL_GLOB
    fi

    # Remove temp credential files
    for f in /tmp/yl* /tmp/tsh* /tmp/admin_*; do
        [ -e "$f" ] && rm -f "$f"
    done

    # Determine which shell profile to clean
    local shell_name shell_profile
    shell_name=$(basename "$SHELL")

    if [ "$shell_name" = "zsh" ]; then
        shell_profile="$HOME/.zshrc"
    elif [ "$shell_name" = "bash" ]; then
        shell_profile="$HOME/.bash_profile"
    else
        echo "Unsupported shell: $shell_name. Skipping profile cleanup."
        shell_profile=""
    fi

    # Remove any lines sourcing proxy envs from the profile
    if [ -n "$shell_profile" ] && [ -f "$shell_profile" ]; then
        sed -i.bak '/[[:space:]]*source \/tmp\/tsh_proxy_/d' "$shell_profile"
        printf "\n\n✏️ \033[0mRemoving source lines from $shell_profile...\033[0m"
    fi

    printf "\n📃 \033[0mRemoving ENVs...\033[0m"

    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_CA_BUNDLE
    unset HTTPS_PROXY
    unset ACCOUNT
    unset ROLE
    unset AWS_DEFAULT_REGION

    printf "\n💀 \033[0mKilling all running tsh proxies...\033[0m\n\n"
    # Kill all tsh proxy aws processes
    ps aux | grep '[t]sh proxy aws' | awk '{print $2}' | xargs kill 2>/dev/null
    ps aux | grep '[t]sh proxy db' | awk '{print $2}' | xargs kill 2>/dev/null
    
    tsh logout > /dev/null 2>&1
    tsh apps logout > /dev/null 2>&1
    
    printf "\n✅ \033[1;32mLogged out of all apps, clusters & proxies\033[0m\n\n"
}

find_available_port() {
    local port
    for i in {1..100}; do
        port=$((RANDOM % 20000 + 40000))
        if ! nc -z localhost $port &> /dev/null; then
            echo $port
            return 0
        fi
    done
    echo 50000
}

load() {
    local job="$1"
    local message="${2:-"Loading.."}"
    {
        set +m
        $job &
        wave_loader $! "$message"
        wait
        set -m
    }   2>/dev/null
}