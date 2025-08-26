terraform_login() {
    th_login     
    printf "\033c"
    create_header "Terragrunt Login"
    tsh apps logout > /dev/null 2>&1
    printf "\033[1mLogging into \033[1;32myl-admin\033[0m \033[1mas\033[0m \033[1;32msudo_admin\033[0m\n"
    tsh apps login "yl-admin" --aws-role "sudo_admin" > /dev/null 2>&1
    create_proxy "yl-admin" "sudo_admin"
}