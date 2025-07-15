
#===============================================
#================== databases ==================
#===============================================

db_elevated_login() {
    local cluster="$1"
    while true; do
        printf "\033c" 
        printf "\n====================== \033[1mPrivilege Request\033[0m =========================="
        printf "\n\nYou don't have access to any databases..."
        printf "\n\nWould you like to raise a request? (y/n): "
        read elevated
        if [[ $elevated =~ ^[Yy]$ ]]; then

        printf "\n\033[1mEnter your reason for request: \033[0m"
        read reason

        request_output=$(tsh request create --roles atlas-read-only --reason "$reason" 2>&1 | tee /dev/tty)

        # 2. Extract request ID
        REQUEST_ID=$(echo "$request_output" | grep "Request ID:" | awk '{print $3}')

        printf "\n\n✅ \033[1;32mAccess request sent!\033[0m\n\n"

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

open_dbeaver() {
    local database="$1"
    printf "\n\033[1mConnecting to \033[1;32m$database\033[0m in \033[1;32m$rds\033[0m as \033[1;32mteleport_rds_read_user\033[0m...\n\n"
    sleep 2
    printf "\033c" 
    tsh proxy db "$rds" --db-name="$database" --port=50000 --tunnel --db-user=teleport_rds_read_user &> /dev/null
    printf "\033[1mTo connect to the database, follow these steps: \033[0m\n"
    printf "\n1. Once DBeaver opens click create a new connection in the very top left.\n"
    printf "2. Select \033[1mPostgreSQL\033[0m as the database type.\n"
    printf "3. Use the following connection details:\n"
    printf " - Host:      \033[1mlocalhost\033[0m\n"
    printf " - Port:      \033[1m50000\033[0m\n"
    printf " - Database:  \033[1m$database\033[0m\n"
    printf " - User:      \033[1mteleport_rds_read_user\033[0m\n"
    printf " - Password:  \033[1m(leave blank)\033[0m\n"
    printf "4. Optionally, select show all databases.\n"
    printf "5. Click 'Test Connection' to ensure everything is set up correctly.\n"
    printf "6. If the test is successful, click 'Finish' to save the connection.\n"
    for i in {3..1}; do
        printf "\033[1;32m. \033[0m"
        sleep 1
    done
    open -a "DBeaver"
}

rds_connect(){
    local rds="$1"
    printf "\n\033[1;32m$rds\033[0m selected.\n"
    printf "\nHow would you like to connect?\n\n"
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
            # Check whether the user already has the PSQL client installed
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
            local db_user="teleport_rds_read_user"
            printf "\nWhich internal database would you like to connect to?\n"
            printf "\nEnter db name (leave blank to connect to \033[1mpostgres\033[0m): "
            read database

            printf "\nConnecting as admin? (y/n): "
            read admin
            if [[ $admin =~ ^[Yy]$ ]]; then db_user="sudo_teleport_rds_user"; fi

            if [ -z "$database" ]; then
                printf "\n\033[1mConnecting to \033[1;32mpostgres\033[0m in \033[1;32m$rds\033[0m as \033[1;32m$db_user\033[0m...\n"
                for i in {3..1}; do
                printf "\033[1;32m. \033[0m"
                sleep 1
                done
                echo
                printf "\033c" 
                tsh db connect "$rds" --db-user=$db_user --db-name=postgres
                return 1
            fi
            printf "\n\033[1mConnecting to \033[1;32m$database\033[0m in \033[1;32m$rds\033[0m as \033[1;32m$db_user\033[0m...\n\n"
            for i in {3..1}; do
                printf "\033[1;32m. \033[0m"
                sleep 1
            done
            echo
            printf "\033c" 
            tsh db connect "$rds" --db-user=$db_user --db-name=$database
            ;;
        2)
            printf "\nConnecting via \033[1;32mDBeaver\033[0m...\n"
            printf "\nWhich internal database would you like to connect to?\n"
            printf "\nEnter db name (leave blank to connect to \033[1mpostgres\033[0m): "
            read database
            if [ -z "$database" ]; then
                open_dbeaver "postgres"
                return 1
            fi
            open_dbeaver "$database"
            ;;
        *)
            echo "Invalid selection. Exiting."
            return 1
        ;;
    esac
}

db_login() {
    printf "Which database would you like to connect to?"
    printf "\n\n1. \033[1mRDS\033[0m"
    printf "\n2. \033[1mMongoDB\033[0m\n"
    local db_type
    while true; do
        printf "\nSelect option (number): "
        read db_choice
        case "$db_choice" in
            1)
                printf "\n\033[1mRDS\033[0m selected.\n\n"
                th_login
                db_type="rds"

                # Capture tsh db ls output and parse it
                output=$(tsh db ls --format=json)

                # Filter JSON using jq
                dbs=$(echo "$output" | jq --arg type "$db_type" '[.[] | select(.metadata.labels.db_type == $type)]')

                # Check if the filtered result is empty
                if [ "$(echo "$dbs" | jq 'length')" -eq 0 ]; then
                    db_elevated_login
                fi
                break
                ;;
            2)
                printf "\n\033[1mMongoDB\033[0m selected.\n\n"
                th_login
                db_type="mongo"

                output=$(tsh db ls --format=json)

                # Filter JSON using jq
                dbs=$(echo "$output" | jq --arg type "$db_type" '[.[] | select(.metadata.labels.db_type == $type)]')

                # Check if the filtered result is empty
                if [ "$(echo "$dbs" | jq 'length')" -eq 0 ]; then
                    db_elevated_login
                fi
                break
                ;;
            *)
                printf "\n\033[31mInvalid selection\033[0m\n"
                ;;
        esac
    done
    if [ "$reauth_db" == "TRUE" ]; then
        # Once the user returns from the elevated login, re-authenticate with request id.
        printf "\n\033[1mRe-Authenticating\033[0m\n\n"
        tsh logout
        tsh login --auth=ad --proxy=youlend.teleport.sh:443 --request-id="$REQUEST_ID" > /dev/null 2>&1
        reauth_db="FALSE"
        return 0
    fi

    if [ "$exit_db" == "TRUE" ]; then
        exit_db="FALSE"
        return 0
    fi

    local json_output filtered db
    echo
    tsh db logout
    # Fetch JSON output from tsh
    json_output=$(tsh db ls --format=json)

    # Filter and enumerate matching databases
    printf "\033c" 
    printf "\n\033[1;4mAvailable databases:\033[0m\n\n"
    filtered=$(echo "$json_output" | jq -r --arg type "$db_type" '[.[] | select(.metadata.labels.db_type == $type)]')
    echo "$filtered" | jq -r '.[] | .metadata.name' | nl -w2 -s'. '
    # Prompt for app selection.
    echo
    printf "\033[1mSelect database (number):\033[0m "
    read db_choice
    if [ -z "$db_choice" ]; then
        echo "No selection made. Exiting."
        return 1
    fi

    db=$(echo "$filtered" | jq -r ".[$((db_choice-1))].metadata.name")

    if [ -z "$db" ]; then
        printf "\n\033[31mInvalid selection\033[0m\n"
        return 1
    fi

    # If the first column is ">", use the second column; otherwise, use the first.
    if [[ "$db_type" == "rds" ]]; then
        rds_connect "$db"
        return 0
    fi
    mongo_connect "$db"
    return 0
}

mongo_connect() {
    local db="$1" db_user
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
    printf "\n\033[1;32m$db\033[0m selected.\n"
    printf "\nHow would you like to connect?\n\n"
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
            # Log into the selected db.
            printf "\nLogging into: \033[1;32m$db\033[0m\n"
            tsh db login "$db" --db-user=$db_user --db-name="admin" > /dev/null 2>&1
            printf "\n✅ \033[1;32mLogged in successfully!\033[0m\n"

            # Create a proxy for the selected db.
            printf "\nCreating proxy for \033[1;32m$db\033[0m...\n"
            tsh proxy db --tunnel --port=50000 $db > /dev/null 2>&1 &
            printf "\n✅ \033[1;32mProxy created successfully!\033[0m\n"

            # Open MongoDB Compass
            printf "\nOpening MongoDB compass...\n"
            open "mongodb://localhost:50000/?directConnection=true"
            break
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