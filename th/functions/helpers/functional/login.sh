th_login() {
    printf "\033c"
    create_header "Login"
    printf "Checking login status...\n"
    # Check if already logged in
    if tsh status 2>/dev/null | grep -q 'Logged in as:'; then
        cprintf "\n✅ \033[1mAlready logged in to Teleport!\033[0m\n"
        sleep 1
        return 0
    fi
    printf "\nLogging you into Teleport...\n"
    tsh login --auth=ad --proxy=youlend.teleport.sh:443 > /dev/null 2>&1
    # Wait until login completes (max 15 seconds)
    for i in {1..30}; do
        if tsh status 2>/dev/null | grep -q 'Logged in as:'; then
        printf "\n\033[1;32mLogged in successfully!\033[0m\n"
        sleep 1
        return 0
        fi
        sleep 0.5
    done

    printf "\n❌ \033[1;31mTimed out waiting for Teleport login.\033[0m"
    return 1
}