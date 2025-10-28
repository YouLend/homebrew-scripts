aws_elevated_login(){
    local app="$1"
    local request_role="$2"
    printf "\033c"
    create_header "Privilege Request"
    printf "You're requesting access for: \033[1;32m%s\033[0m" $request_role

    printf "\n\nPlease enter a reason for your request (minimum 15 characters):\n"

    create_input 15 51 51 "Reason too short. Please provide more detail"
    local input_exit_code=$?
    reason="$user_input"

    # Check if user cancelled (Ctrl+C)
    if [ $input_exit_code -eq 130 ]; then
        return 130
    fi

    echo
    # Run the command and filter output to stop at approval
    tsh request create --roles $request_role --reason "$reason" --max-duration 4h
    return 0
}