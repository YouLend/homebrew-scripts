db_elevated_login() {
    local role="$1"
    local db_name="$2"

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
            tsh request create --roles $role --max-duration 4h --reason "$reason"
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