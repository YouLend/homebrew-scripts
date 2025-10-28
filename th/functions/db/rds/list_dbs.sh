list_postgres_databases() {
    local cluster="$1"
    local port="$2"
    {
        set +m
        tsh proxy db "$cluster" --db-user=tf_teleport_rds_read_user --db-name=postgres --port=$port --tunnel &> /dev/null &
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

    printf "\n\033[1mSelect database (number):\033[0m\n"
    create_input 1 2 50 "Invalid input. " "numerical"
    local input_exit_code=$?
    db_choice="$user_input"

    if [ $input_exit_code -eq 130 ]; then
        kill $tunnel_pid 2>/dev/null
        return 130
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