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
