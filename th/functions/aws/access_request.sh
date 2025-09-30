aws_elevated_login(){
    local app="$1"
    local default_role="$2"
    printf "\033c" 
    create_header "Privilege Request"
    printf "No privileged roles found. Your only available role is: \033[1;32m%s\033[0m" $default_role

    while true; do
        printf "\n\n\033[1mWould you like to raise a privilege request?\033[0m"
        create_note "Entering (N/n) will log you in as \033[1;32m$default_role\033[0m. "
        printf "(Yy/Nn):\033[0m "
        read request
        if [[ $request =~ ^[Yy]$ ]]; then
            printf "\n\033[1mEnter request reason:\033[0m "
            read reason

            request_role="sudo_${default_role}_role"
            
            echo
            tsh request create --roles $request_role --reason "$reason" --max-duration 4h  2>&1 
            
            reauth_aws="TRUE"
            return 0
        elif [[ $request =~ ^[Nn]$ ]]; then
            printf "\033c"
            create_header "AWS Login"
            printf "\033[1mLogging you in to \033[1;32m$app\033[0m \033[1mas\033[0m \033[1;32m$default_role\033[0m" 
            tsh apps login "$app" > /dev/null 2>&1
            printf "\n\n✅\033[1;32m Logged in successfully!\033[0m\n" 
            create_proxy "$app" "$default_role"
            reauth_aws="FALSE"
            return 0
        else
            printf "\n\033[31mInvalid input. Please enter y or n.\033[0m\n"
        fi
    done
}