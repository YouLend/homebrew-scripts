
#===============================================
#================== databases ==================
#===============================================
db_login() {
    th_login

    if [[ -n "$1" ]]; then
        db_quick_login "$@"
        return 0
    fi

    printf "\033c"
    create_header "DB"
    printf "Which database would you like to connect to?"
    printf "\n\n1. \033[1mRDS\033[0m"
    printf "\n2. \033[1mMongoDB\033[0m\n"
    local db_type
    local selected_db
    while true; do
        printf "\nSelect option (number): "
        read db_choice
        case "$db_choice" in
            1)
                printf "\n\033[1mRDS\033[0m selected.\n"
                db_type="rds"

                temp_db_file=$(mktemp)
                temp_status_file=$(mktemp)

                printf "\033c" 
                create_header "Available Databases"
                
                load check_rds_login "Checking cluster access..."

                # Read results back into global arrays
                db_lines=()
                login_status=()

                while IFS= read -r line; do
                    db_lines+=("$line")
                done < "$temp_db_file"
                
                while IFS= read -r line; do
                    login_status+=("$line")
                done < "$temp_status_file"
                
                # Clean up temp files
                rm -f "$temp_db_file" "$temp_status_file"

                local i
                i=0
                for line in "${db_lines[@]}"; do
                    # Handle bash (0-indexed) vs zsh (1-indexed) arrays
                    local array_index=$i
                    if [[ -n "$ZSH_VERSION" ]]; then
                        array_index=$((i + 1))
                    fi
                    local db_status="${login_status[$array_index]:-n/a}"

                    case "$db_status" in
                        ok)
                            printf "%2s. %s\n" "$(($i + 1))" "$line"
                            ;;
                        fail)
                            printf "\033[90m%2s. %s\033[0m\n" "$(($i + 1))" "$line"
                            ;;
                        n/a)
                            printf "%2s. %s\n" "$(($i + 1))" "$line"
                            ;;
                    esac
                    i=$((i + 1))
                done

                echo
                printf "\033[1mSelect database (number):\033[0m "
                read db_choice
                if [ -z "$db_choice" ]; then
                    echo "No selection made. Exiting."
                    return 1
                fi

                selected_index=$((db_choice - 1))
                # Handle bash (0-indexed) vs zsh (1-indexed) arrays for selection
                local db_array_index=$selected_index
                local status_array_index=$selected_index
                if [[ -n "$ZSH_VERSION" ]]; then
                    db_array_index=$((selected_index + 1))
                    status_array_index=$((selected_index + 1))
                fi
                
                if [[ $db_choice -gt 0 && $db_choice -le ${#db_lines} ]]; then
                    selected_db="${db_lines[$db_array_index]}"
                    
                    # Check if the selected database has failed login status
                    local selected_status="${login_status[$status_array_index]:-n/a}"
                    if [[ "$selected_status" == "fail" ]]; then
                        db_elevated_login "sudo_teleport_rds_read_role" $selected_db
                    fi
                else
                    printf "\n\033[31mInvalid selection here\033[0m\n"
                    return 1
                fi
                break
                ;;
            2)
                printf "\n\033[1mMongoDB\033[0m selected.\n"
                db_type="mongo"

                printf "\033c"
                create_header "Available Databases"

                local has_atlas_access json_output
                
                temp_atlas_file=$(mktemp)
                temp_json_file=$(mktemp)
                
                check_atlas_access() {
                    tsh status | grep -q "atlas-can-read" && echo "true" > "$temp_atlas_file" || echo "false" > "$temp_atlas_file"
                    tsh db ls --format=json > "$temp_json_file"
                }

                load check_atlas_access "Checking MongoDB access..."
                
                # Read results back from temp files
                has_atlas_access=$(cat "$temp_atlas_file")
                json_output=$(cat "$temp_json_file")
                
                # Clean up temp files
                rm -f "$temp_atlas_file" "$temp_json_file"

                filtered_dbs=$(echo "$json_output" | tr -d '\000-\037' | jq -r '[.[] | select(.metadata.labels.db_type != "rds")]')
                # Display databases with color coding based on access
                local i=1
                while IFS= read -r db_name; do
                    if [[ -z "$db_name" ]]; then
                        continue
                    fi
                    
                    printf "%2s. " "$i"
                    if [[ "$has_atlas_access" == "true" ]]; then
                        printf "%s\n" "$db_name"
                    else
                        printf "\033[90m%s\033[0m\n" "$db_name"
                    fi
                    i=$((i + 1))
                done <<< "$(echo "$filtered_dbs" | tr -d '\000-\037' | jq -r '.[] | .metadata.name')"

                # Prompt for selection
                printf "\n\033[1mSelect database (number):\033[0m "
                read db_choice

                if [ -z "$db_choice" ]; then
                    echo "No selection made. Exiting."
                    return 1
                fi

                selected_index=$((db_choice - 1))
                db_count=$(echo "$filtered_dbs" | tr -d '\000-\037' | jq 'length')
                
                if [[ $db_choice -gt 0 && $db_choice -le $db_count ]]; then
                    selected_db=$(echo "$filtered_dbs" | tr -d '\000-\037' | jq -r ".[$selected_index].metadata.name")
                    
                    # If user doesn't have atlas access, trigger elevated login
                    if [[ "$has_atlas_access" != "true" ]]; then
                        db_elevated_login "atlas-read-only" "$selected_db"
                    fi
                else
                    printf "\n\033[31mInvalid selection\033[0m\n"
                    return 1
                fi
                break
                ;;
            *)
                printf "\n\033[31mInvalid selection here2\033[0m\n"
                ;;
        esac
    done
    if [[ "$reauth_db" == "TRUE" ]]; then
        # Once the user returns from the elevated login, re-authenticate with request id.
        printf "\033c"
        create_header "Re-Authenticating"
        tsh logout
        tsh login --auth=ad --proxy=youlend.teleport.sh:443 --request-id="$REQUEST_ID" > /dev/null 2>&1
        reauth_db="FALSE"
    fi

    if [[ "$exit_db" == "TRUE" ]]; then
        exit_db="FALSE"
        return 0
    fi

    printf "\n\033[1;32m$selected_db\033[0m selected.\n"
    sleep 1

    # If the first column is ">", use the second column; otherwise, use the first.
    if [[ "$db_type" == "rds" ]]; then
        rds_connect "$selected_db"
        return 0
    fi
    mongo_connect "$selected_db"
    return 0
}

# Check login status for *prod* & sandbox clusters 
check_rds_login() {
    output=$(tsh db ls -f json)
    dbs=$(echo "$output" | tr -d '\000-\037' | jq -r '.[] | select(.metadata.labels.db_type == "rds") | .metadata.name')

    # Write to predetermined temp files that parent shell can read
    local access_status="unknown"
    local test_db=""
    
    # First pass: write all db names and find a test database
    while IFS= read -r db_name; do
        if [[ -z "$db_name" ]]; then
            continue
        fi

        echo "$db_name" >> "$temp_db_file"
        
        # Find first prod/sandbox db to test with
        if [[ -z "$test_db" && ("$db_name" == *prod* || "$db_name" == *sandbox*) ]]; then
            test_db="$db_name"
        fi
    done <<< "$dbs"
    
    # Test access with one database if we found one
    if [[ -n "$test_db" ]]; then
        # Start proxy and capture its output
        proxy_output=$(mktemp)
        tsh proxy db "$test_db" --db-name postgres --db-user tf_teleport_rds_read_user --tunnel > "$proxy_output" 2>&1 &
        proxy_pid=$!
        disown

        # Wait for the URL to appear in the output
        psql_url=""
        for _ in {1..20}; do
            if grep -qE 'psql postgres://.*@localhost:[0-9]+/postgres' "$proxy_output"; then
                psql_url=$(grep -Eo 'psql postgres://[^ ]+' "$proxy_output" | head -n1 | cut -d' ' -f2)
                break
            fi
            sleep 0.5
        done

        if [[ -n "$psql_url" ]]; then
            if PGPASSWORD=$PGPASSWORD psql "$psql_url" -c "SELECT 1;" > /dev/null 2>&1; then
                access_status="ok"
            else
                access_status="fail"
            fi
        else
            access_status="fail"
        fi

        # Clean up proxy
        kill "$proxy_pid" 2>/dev/null
        wait "$proxy_pid" 2>/dev/null
        rm -f "$proxy_output"
    fi
    
    # Second pass: write status for all databases based on single test
    while IFS= read -r db_name; do
        if [[ -z "$db_name" ]]; then
            continue
        fi

        if [[ "$db_name" == *prod* || "$db_name" == *sandbox* ]]; then
            echo "$access_status" >> "$temp_status_file"
        else
            echo "n/a" >> "$temp_status_file"
        fi
    done <<< "$dbs"
}

db_elevated_login() {
    local role="$1"
    local db_name="$2"
    if [[ -z "$2" ]]; then
        db_name="Mongo databases"
    fi

    while true; do
        printf "\033c" 
        create_header "Privilege Request"
        printf "You don't have access to \033[4m$db_name\033[0m"
        printf "\n\nWould you like to raise a request? (y/n): "
        read elevated
        if [[ $elevated =~ ^[Yy]$ ]]; then

            printf "\n\033[1mEnter your reason for request: \033[0m"
            read reason
            echo
            request_output=$(tsh request create --roles $role --max-duration 6h --reason "$reason" 2>&1 | tee /dev/tty)

            # 2. Extract request ID
            REQUEST_ID=$(echo "$request_output" | grep "Request ID:" | awk '{print $3}')

            reauth_db="TRUE"

            return 0

        elif [[ $elevated =~ ^[Nn]$ ]]; then
            echo
            echo "Request creation skipped."
            exit_db="TRUE"
            return 0 
        else
            printf "\n\033[31mInvalid input. Please enter y or n.\033[0m\n"
        fi
    done
}

rds_connect(){
    local rds="$1"
    local db_user="tf_teleport_rds_read_user"

    list_postgres_databases() {
        local rds="$1"
        local port=$(find_available_port)

        {
            set +m
            tsh proxy db "$rds" --db-user=tf_teleport_rds_read_user --db-name=postgres --port=$port --tunnel &> /dev/null &
            disown
            set -m
        } > /dev/null 2>&1

        # Wait for proxy to open (up to 10s)
        for i in {1..10}; do
            if nc -z localhost $port &> /dev/null; then
                break
            fi
            sleep 1
        done

        if ! nc -z localhost $port &> /dev/null; then
            printf "\n\033[31m❌ Failed to establish tunnel to database.\033[0m\n"
            kill $tunnel_pid 2>/dev/null
            return 1
        fi

        printf "\033c"
        create_header "Available Databases"

        local temp_db_list=$(mktemp)
        
        fetch_databases() {
            psql "postgres://tf_teleport_rds_read_user@localhost:$port/postgres" -t -A -c \
                "SELECT datname FROM pg_database WHERE datistemplate = false;" 2>/dev/null > "$temp_db_list"
        }

        load fetch_databases "Fetching databases..."
        
        db_list=$(cat "$temp_db_list")
        rm -f "$temp_db_list"

        if [ -z "$db_list" ]; then
            printf "\033[31m❌ No databases found or connection failed.\033[0m\n"
            kill $tunnel_pid 2>/dev/null
            return 1
        fi

        echo "$db_list" | nl -w2 -s'. '

        printf "\n\033[1mSelect database (number):\033[0m "
        read db_choice

        if [ -z "$db_choice" ]; then
            echo "No selection made. Exiting."
            kill $tunnel_pid 2>/dev/null
            return 1
        fi

        database=$(echo "$db_list" | sed -n "${db_choice}p")

        if [ -z "$database" ]; then
            printf "\n\033[31mInvalid selection\033[0m\n"
            kill $tunnel_pid 2>/dev/null
            return 1
        fi
        
        export database="$database"
        kill $tunnel_pid 2>/dev/null
        return 0
    }

    check_admin() {
        if tsh status | grep -qw "sudo_teleport_rds_write_role"; then 
            printf "\nConnecting as admin? (y/n): "
            read admin

            if [[ $admin =~ ^[Yy]$ ]]; then db_user="tf_sudo_teleport_rds_user"; fi
        fi
    }

    check_psql() {
        if ! command -v psql >/dev/null 2>&1; then
            printf "\n\033[1m=============== PSQL not found =============== \033[0m\n"
            printf "\n❌ PSQL client not found. It is required to connect to PostgreSQL databases.\n"
            # Ask whether the user wants to install it via brew
            while true; do  
            printf "\nWould you like to install it via brew? (y/n): "
            read install
            if [[ $install =~ ^[Yy]$ ]]; then
                echo
                brew install postgresql@14
                printf "\n✅ \033[1;32mPSQL client installed successfully!\033[0m\n"
                break
            elif [[ $install =~ ^[Nn]$ ]]; then
                printf "\nPSQL installation skipped.\n"
                return 0
            else
                printf "\n\033[31mInvalid input. Please enter y or n.\033[0m\n"
            fi
            done
        fi
    }

    connect_db() {
        local database="$1"
        printf "\n\033[1mConnecting to \033[1;32m$database\033[0m in \033[1;32m$rds\033[0m as \033[1;32m$db_user\033[0m...\n"
        for i in {3..1}; do
        printf "\033[1;32m. \033[0m"
        sleep 1
        done
        echo
        printf "\033c" 
        tsh db connect "$rds" --db-user=$db_user --db-name=$database
    }

    printf "\033c"
    create_header "Connect"
    printf "How would you like to connect?\n\n"
    printf "1. Via \033[1mPSQL\033[0m\n"
    printf "2. Via \033[1mDBeaver\033[0m\n"
    printf "\nSelect option (number): "
    read option

    if [ -z "$option" ]; then
        echo "No selection made. Exiting."
        return 1
    fi

    case "$option" in
        1)
            printf "\nConnecting via \033[1;32mPSQL\033[0m...\n"

            check_psql

            list_postgres_databases "$rds"
            
            check_admin

            if [ -z "$database" ]; then 
                connect_db "postgres"
                return 0
            fi
            connect_db "$database"
            ;;
        2)
            printf "\nConnecting via \033[1;32mDBeaver\033[0m...\n"
            
            check_admin

            open_dbeaver "$rds" "$db_user"
            ;;
        *)
            echo "Invalid selection. Exiting."
            return 1
        ;;
    esac
}


mongo_connect() {
    local db="$1"
    case "$db" in
        "mongodb-YLUSProd-Cluster-1")
        db_user="teleport-usprod"
        ;;
        "mongodb-YLProd-Cluster-1")
        db_user="teleport-prod"
        ;;
        "mongodb-YLSandbox-Cluster-1")
        db_user="teleport-sandbox"
        ;;
    esac
    printf "\033c"
    create_header "MongoDB"
    printf "How would you like to connect?\n\n"
    printf "1. Via \033[1mMongoCLI\033[0m\n"
    printf "2. Via \033[1mAtlasGUI\033[0m\n"
    printf "\nSelect option (number): "
    read option
    while true; do
        case "$option" in
        1)
            if ! command -v mongosh >/dev/null 2>&1; then
                printf "\n❌ MongoDB client not found. MongoSH is required to connect to MongoDB databases.\n" 
                # Ask whether the user wants to install it via brew
                while true; do  
                printf "\nWould you like to install it via brew? (y/n): "
                read install
                if [[ $install =~ ^[Yy]$ ]]; then
                    # Install the MongoDB client using brew & connect to the selected database
                    echo
                    brew install mongosh
                    printf "\n✅ \033[1;32mMongoDB client installed successfully!\033[0m\n"
                    printf "\n\033[1mConnecting to \033[1;32m$db\033[0m...\n"
                    echo
                    tsh db connect "$db"
                    return 0
                elif [[ $install =~ ^[Nn]$ ]]; then
                    printf "\nMongoDB client installation skipped.\n"
                    return 0
                else
                    printf "\n\033[31mInvalid input. Please enter y or n.\033[0m\n"
                fi
                done
            else
                # If the MongoDB client is found, connect to the selected database
                printf "\n\033[1mConnecting to \033[1;32m$db\033[0m...\n"
                for i in {3..1}; do
                    printf "\033[1;32m. \033[0m"
                    sleep 1
                done
                printf "\033c"
                tsh db connect "$db" --db-user=$db_user --db-name="admin"
                return
            fi
            ;;
        2)
            open_atlas $db $port
            return
            ;;
        *)
            printf "\n\033[31mInvalid selection. Please enter 1 or 2.\033[0m\n"
            printf "\nSelect option (number): "
            read option
            continue
            ;;
        esac
    done
}

open_atlas() {
    db="$1"
    port="$2"
    case "$db" in
        "mongodb-YLUSProd-Cluster-1")
        db_user="teleport-usprod"
        ;;
        "mongodb-YLProd-Cluster-1")
        db_user="teleport-prod"
        ;;
        "mongodb-YLSandbox-Cluster-1")
        db_user="teleport-sandbox"
        ;;
    esac
    printf "\033c"
    create_header "Mongo Atlas"
    printf "Logging into: \033[1;32m$db\033[0m as \033[1;32m$db_user\033[0m\n"
    tsh db login "$db" --db-user=$db_user --db-name="admin" > /dev/null 2>&1
    printf "\n✅ \033[1;32mLogged in successfully!\033[0m\n"

    # Create a proxy for the selected db.
    printf "\nCreating proxy for \033[1;32m$db\033[0m...\n"
    tsh proxy db --tunnel --port=$port $db > /dev/null 2>&1 &

    # Open MongoDB Compass
    printf "\nOpening MongoDB compass...\n"
    open "mongodb://localhost:$port/?directConnection=true"
}

# Load DB config from JSON
load_db_config() {
    local env="$1"
    local db_type="$2"  # rds, mongo, etc.
    # Handle bash vs zsh differences for script directory detection
    if [[ -n "$ZSH_VERSION" ]]; then
        local script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
    else
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    local config_file="$script_dir/../th.config.json"
    
    if [[ ! -f "$config_file" ]]; then
        echo ""
        return 1
    fi
    
    jq -r ".db.${db_type}.${env} // empty" "$config_file"
}

# Quick DB login
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
        printf "\033c"
        create_header "DB Login Error"
        printf "\033[31m❌ Invalid environment format: '$env_arg'\033[0m\n\n"
        printf "Available environments:\n"
        
        # Get config file path
        if [[ -n "$ZSH_VERSION" ]]; then
            local script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
        else
            local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        fi
        local config_file="$script_dir/../th.config.json"
        
        # List available DB environments
        if [[ -f "$config_file" ]]; then
            # Collect all entries with prefixes
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
            jq -r '.db.rds | to_entries[] | "r-\(.key): \(.value)"' "$config_file" 2>/dev/null | while read -r line; do
                local key=$(echo "$line" | cut -d':' -f1)
                local db=$(echo "$line" | cut -d':' -f2- | sed 's/^ //')
                printf "• \033[1m%-${max_key_len}s\033[0m : %s\n" "$key" "$db"
            done
            
            # Display MongoDB entries
            printf "\n\033[1mMongo:\033[0m\n"
            jq -r '.db.mongo | to_entries[] | "m-\(.key): \(.value)"' "$config_file" 2>/dev/null | while read -r line; do
                local key=$(echo "$line" | cut -d':' -f1)
                local db=$(echo "$line" | cut -d':' -f2- | sed 's/^ //')
                printf "• \033[1m%-${max_key_len}s\033[0m : %s\n" "$key" "$db"
            done
        fi
        printf "\n"
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
    db_name=$(load_db_config "$env_name" "$db_type")
    
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

open_dbeaver() {
    local rds="$1"
    local db_user="$2"
    local port="$3"
    printf "\033[1mConnecting to \033[1;32m$rds\033[0m as \033[1;32m$db_user\033[0m...\n\n"
    sleep 1
    tsh proxy db "$rds" --db-name="postgres" --port=$port --tunnel --db-user="$db_user" &> /dev/null &
    printf "\033c" 
    create_header "DBeaver"
    printf "\033[1mTo connect, follow these steps: \033[0m\n"
    printf "\n1. Once DBeaver opens click create a new connection in the very top left.\n"
    printf "2. Select \033[1mPostgreSQL\033[0m as the database type.\n"
    printf "3. Use the following connection details:\n"
    printf " - Host:      \033[1mlocalhost\033[0m\n"
    printf " - Port:      \033[1m$port\033[0m\n"
    printf " - Database:  \033[1mpostgres\033[0m\n"
    printf " - User:      \033[1m$db_user\033[0m\n"
    printf " - Password:  \033[1m(leave blank)\033[0m\n"
    printf " - Select \033[1m'Show all databases' ☑️\033[0m\n"
    printf "5. Click 'Test Connection' to ensure everything is set up correctly.\n"
    printf "6. If the test is successful, click 'Finish' to save the connection.\n"
    sleep 1
    open -a "DBeaver"
}