# RDS connection handler
rds_connect(){
    local cluster="$1"
    local port="$2"
    local db_user="tf_teleport_rds_read_user"

    printf "\033c"
    create_header "Connect"
    printf "How would you like to connect?\n\n"
    printf "1. Via \033[1mPSQL\033[0m\n"
    printf "2. Via \033[1mDBeaver\033[0m\n"
    printf "\nSelect option (number):\n"
    create_input 1 1 15 "Invalid input. " "numerical"
    local input_exit_code=$?
    option="$user_input"

    if [ $input_exit_code -eq 130 ]; then
        return 130
    fi

    case "$option" in
        1)
            printf "\nConnecting via \033[1;32mPSQL\033[0m...\n"

            check_psql

            list_postgres_databases "$cluster" "$port"

            local input_exit_code=$?

            if [ $input_exit_code -eq 130 ]; then
                return 130
            fi

            if [ -z "$database" ]; then 
                connect_db "postgres"
                return 0
            fi
            connect_psql "$cluster" "$database" "$db_user"
            ;;
        2)
            printf "\nConnecting via \033[1;32mDBeaver\033[0m...\n"

            open_dbeaver "$cluster" "$db_user" "$port"
            ;;
        *)
            echo "Invalid selection. Exiting."
            return 1
        ;;
    esac
}

# Connect via GUI
open_dbeaver() {
    local cluster="$1"
    local db_user="$2"
    local port="$3"
    ( tsh proxy db "$cluster" --db-name="postgres" --port=$port --tunnel --db-user="$db_user" &> /dev/null & )
    printf "\033c" 
    create_header "DBeaver"
    printf "Connecting to: \033[1;32m$cluster\033[0m\n"
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

# Connect via CLI
connect_psql() {
    local cluster="$1"
    local database="$2"
    local db_user="$3"
    printf "\n\033[1mConnecting to \033[1;32m$database\033[0m in \033[1;32m$cluster\033[0m as \033[1;32m$db_user\033[0m...\n"
    for i in {3..1}; do
    printf "\033[1;32m. \033[0m"
    sleep 1
    done
    echo
    printf "\033c" 
    tsh db connect "$cluster" --db-user=$db_user --db-name=$database
}