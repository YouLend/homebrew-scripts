print_help() {
    center_spaces=$(center_content)
    version="$1"
    print_logo "$version" "$center_spaces"
    create_header "Usage" "$center_spaces" 1
    printf "%s     ╚═ \033[1mth aws  [options] | a\033[0m   : AWS login.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth db   [options] | d\033[0m   : Database login.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth kube [options] | k\033[0m   : Kubernetes login.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth terra          | t\033[0m   : Quick log-in to yl-admin.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth login          | l\033[0m   : Simple log in to Teleport\033[0m\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth cleanup        | c\033[0m   : Clean up Teleport session.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth version        | v\033[0m   : Show the current version.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth config         | u\033[0m   : Manage th settings.\n" "$center_spaces"
    printf "%s     \033[0m\033[38;5;245m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\033[1;34m\033[0m\n" "$center_spaces"
    printf "%s     For help, and \033[1m[options]\033[0m info, run $(ccode "th a/k/d -h") \n\n" "$center_spaces"
    create_header "Docs" "$center_spaces" 1
    printf "%s     ╚═ \033[1mDocs:             | doc\033[0m : Open main documentation in your browser. \033[0m\n" "$center_spaces"
    printf "%s     ╚═ \033[1mQuickstart:       | qs\033[0m  : Open quick-start docs in your browser. \033[0m\n\n" "$center_spaces"
    create_header "Extras" "$center_spaces" 1
    printf "%s     Run the following commands to access the extra features: \n" "$center_spaces"
    printf "%s     ╚═ \033[1mth loader               \033[0m: Run loader animation.\n" "$center_spaces"
    printf "%s     ╚═ \033[1mth animate [options]    \033[0m: Run logo animation.\n" "$center_spaces"
    printf "%s        ╚═ \033[1myl\n" "$center_spaces"
    printf "%s        ╚═ \033[1mth\n" "$center_spaces"
    printf "%s          \033[0m\033[38;5;245m  ▁▁▁▁▁▁▁▁▁▁▁▁▁\033[0m\033[1;97m  ▄▄▄ ▄▁▄  \033[0m\033[38;5;245m▁▁▁▁▁▁▁▁▁▁▁▁▁▁\033[0m\033[1;34m\033[0m\n" "$center_spaces"
    printf "%s          \033[0m\033[38;5;245m ▔▔▔▔▔▔▔▔▔▔▔▔▔▔\033[0m\033[1;97m   ▀  ▀▔▀  \033[0m\033[38;5;245m▔▔▔▔▔▔▔▔▔▔▔▔▔\033[0m\033[1;34m\033[0m\n" "$center_spaces"
}

print_db_help() {
    print "\033c"
    create_header "th database | d"
    printf "\033[1mConnect to our databases (RDS and MongoDB)\033[0m\n\n"
    printf "Usage: \033[1mth database [options] | d\033[0m\n"
    printf " ╚═ \033[1mth d\033[0m                     : Open interactive database selection.\n"
    printf " ╚═ \033[1mth d <db-env> [opt_args]\033[0m : Quick database connect, Where:\n"
    printf "    ║\n"
    printf "    ╚═ \033[1m<db-env>\033[0m   is an abbreviation for an RDS or Mongo database, using the format:\n"
    printf "    ║             <dbtype-env> e.g. \033[1mr-dev\033[0m would connect to the \033[1mdev RDS cluster.\033[0m\n"
    printf "    ╚═ \033[1m[opt_args]\033[0m either a port number or 'c', depending on connection method:"
    printf "
       ║
       ╚═ \033[1m[port]\033[0m an integer, 10000-50000. Useful for connection re-use in GUI's.\033[0m
       ║  
       ╚═ \033[1m[c]\033[0m connects via CLI (psql or mongosh).\n\n"
    printf "Examples:\n"
    printf " ╚═ $(ccode "th d r-dev")        : connects to \033[0;32mdb-dev-aurora-postgres-1\033[0m.\n"
    printf " ╚═ $(ccode "th d m-prod c")     : connects to \033[0;32mmongodb-YLProd-Cluster-1\033[0m via \033[0;32mMongoSH\033[0m.\n"
    printf " ╚═ $(ccode "th d m-prod 43000") : opens \033[0;32mmongodb-YLProd-Cluster-1\033[0m in \033[0;32mMongoDB Compass\033[0m on port \033[0;32m43000\033[0m.\n"
}

print_aws_help() {
    print "\033c"
    create_header "th aws | a"
    printf "\033[1mLogin to our AWS accounts.\033[0m\n\n"
    printf "Usage: \033[1mth aws [options] | a\033[0m\n"
    printf " ╚═ \033[1mth a\033[0m                      : Open interactive login.\n"
    printf " ╚═ \033[1mth a <account> [opt_args]\033[0m : Quick aws log-in, Where:\n"
    printf "    ║\n"
    printf "    ╚═ \033[1m<account>\033[0m is an abbreviated account name e.g. \033[1mdev, cpg\33[0m etc...\n"
    printf "    ║\n"
    printf "    ╚═ \033[1m[opt_args]\033[0m takes a combination of s/ss and/or b, Where:"
    printf "
       ║
       ╚═ \033[1m[s/ss]\033[0m determines whether you login with the \033[1msudo\033[0m or \033[1msuper_sudo\033[0m
       ║  role associated with the account.
       ╚═ \033[1m[b]\033[0m opens the browser for the chosen account & role.\n\n"
    printf "Examples:\n"
    printf " ╚═ $(ccode "th a dev")     : logs you into \033[0;32myl-development\033[0m as \033[1;4;32mdev\033[0m\n"
    printf " ╚═ $(ccode "th a dev s")   : logs you into \033[0;32myl-development\033[0m as \033[1;4;32msudo_dev\033[0m\n"
    printf " ╚═ $(ccode "th a dev ssb") : Opens the AWS console for \033[32myl-development\033[0m as \033[1;4;32msuper_sudo_dev\033[0m.\n"
}

print_kube_help() {
    print "\033c"
    create_header "th kube | k"
    printf "\033[1mLogin to our Kubernetes clusters.\033[0m\n\n"
    printf "Usage: \033[1mth kube [options] | k\033[0m\n"
    printf " ╚═ \033[1mth k\033[0m           : Open interactive login.\n"
    printf " ╚═ \033[1mth k <cluster>\033[0m : Quick kube log-in, Where:\n"
    printf "    ║\n"
    printf "    ╚═ \033[1m<cluster>\033[0m is an abbreviated cluster name e.g. dev, cpg etc..\n\n"
    printf "Examples:\n"
    printf " ╚═ $(ccode "th k dev") : logs you into \033[0;32maslive-dev-eks-blue.\033[0m\n"
}

print_config_help() {
    print "\033c"
    create_header "th config"
    printf "\033[1mManage & define configuration preferences.\033[0m\n\n"
    printf "Usage: \033[1mth config [options]\033[0m\n"
    printf " ╚═ \033[1mth config\033[0m                         : Display current configuration settings.\n"
    printf " ╚═ \033[1mth config <key> <value> <cluster>\033[0m : Set a given configuration value\n"
    printf "\n\033[1mAvailable [options]: \033[0m"
    printf "\n• \033[1mupdate <hours>\033[0m - Set inactivity timeout in hours."
    printf "\n\nExamples:\n"
    printf " ╚═ $(ccode "th config update 24") : Put off update notifications for \033[32m24hrs\033[0m.\033[0m\n"
}