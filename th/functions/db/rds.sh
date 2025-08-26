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