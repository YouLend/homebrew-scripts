kube_elevated_login() {
    local cluster="$1"
    
    while true; do
        printf "\033c" 
        create_header "Privilege Request"
        printf "You don't have write access to \033[1;32m$cluster\033[0m."
        printf "\n\n\033[1mWould you like to raise a request?\033[0m"
        create_note "Entering (N/n) will log you in as a read-only user."
        printf "(Yy/Nn): "
        read elevated
        if [[ "$elevated" =~ ^[Yy]$ ]]; then
        printf "\n\033[1mEnter your reason for request: \033[0m"
        read reason

        echo
        tsh request create --roles "production-eks-clusters" --reason "$reason" --max-duration 4h

        reauth_kube="true"
        return 0

        elif [[ "$elevated" =~ ^[Nn]$ ]]; then
        echo
        echo "Request creation skipped."
        return 0
        else
        printf "\n\033[31mInvalid input. Please enter y or n.\033[0m\n"
        fi
    done
}