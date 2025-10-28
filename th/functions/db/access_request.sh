db_elevated_login() {
    local request_role="$1"
    local db_name="$2"
    printf "\033c"
    create_header "Privilege Request"
    printf "To access \033[32m$db_name\033[0m you must raise an access request."

    printf "\n\nPlease enter a reason for your request (minimum 15 characters):\n"

    create_input 15 55 55 "Reason too short. Please provide more detail"
    local input_exit_code=$?
    reason="$user_input"

    # Check if user cancelled (Ctrl+C)
    if [ $input_exit_code -eq 130 ]; then
        return 130
    fi

    echo
    tsh request create --roles $request_role --reason "$reason" --max-duration 4h
    return 0
}