mongo_connect() {
    local cluster="$1"
    local port="$2"
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
            mongocli_connect $cluster
            return
            ;;
        2)
            open_atlas $cluster $port
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
    local cluster="$1"
    local port="$2"
    case "$cluster" in
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
    printf "Logging into: \033[1;32m$cluster\033[0m as \033[1;32m$db_user\033[0m\n"
    tsh db login "$cluster" --db-user=$db_user --db-name="admin" > /dev/null 2>&1
    printf "\n✅ \033[1;32mLogged in successfully!\033[0m\n"

    # Create a proxy for the selected db.
    printf "\nCreating proxy for \033[1;32m$cluster\033[0m...\n"
    ( tsh proxy db --tunnel --port=$port $cluster > /dev/null 2>&1 & )

    # Open MongoDB Compass
    printf "\nOpening MongoDB compass...\n"
    open "mongodb://localhost:$port/?directConnection=true"
}

mongocli_connect() {
    local cluster="$1"
    case "$cluster" in
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
    if ! command -v mongosh >/dev/null 2>&1; then
        check_mongocli_installed
    else
        # If the MongoDB client is found, connect to the selected database
        printf "\n\033[1mConnecting to \033[1;32m$cluster\033[0m...\n"
        for i in {3..1}; do
            printf "\033[1;32m. \033[0m"
            sleep 1
        done
        printf "\033c"
        tsh db connect "$cluster" --db-user=$db_user --db-name="admin"
        return
    fi
}

check_mongocli_installed() {
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
        printf "\n\033[1mConnecting to \033[1;32m$cluster\033[0m...\n"
        echo
        tsh db connect "$cluster"
        return 0
    elif [[ $install =~ ^[Nn]$ ]]; then
        printf "\nMongoDB client installation skipped.\n"
        return 0
    else
        printf "\n\033[31mInvalid input. Please enter y or n.\033[0m\n"
    fi
    done
}