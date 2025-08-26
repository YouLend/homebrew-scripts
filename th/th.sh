# =============================================
# =============== Source Files ================
# =============================================

if [[ -n "$BASH_SOURCE" ]]; then
    SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
elif [[ -n "$ZSH_VERSION" ]]; then
    SCRIPT_DIR="$(dirname "${(%):-%x}")"
else
    SCRIPT_DIR="$(dirname "$0")"
fi

for f in "$SCRIPT_DIR/functions"/*/*.sh; do source "$f"; done

version=$(get_th_version)

th(){ 
  # Start background update check for interactive commands
  local update_cache_file=""
  case "$1" in
    kube|k|aws|a|database|d|terra|t)
      update_cache_file=$(check_th_updates_background)
      ;;
  esac

  case "$1" in
    kube|k)
      if [[ "$2" == "-h" ]]; then
        print "\033c"
        create_header "th kube | k"
        printf "Login to our Kubernetes clusters.\n\n"
        printf "Usage: \033[1mth kube [options] | k\033[0m\n"
        printf " ╚═ \033[1mth k\033[0m                   : Open interactive login.\n"
        printf " ╚═ \033[1mth k <cluster>\033[0m         : Quick kube log-in, Where:\n"
        printf "    ╚═ \033[1m<cluster>\033[0m is an abbreviated cluster name e.g. dev, cpg etc..\n\n"
        printf "Examples:\n"
        printf " ╚═ $(ccode "th k dev")             : logs you into \033[0;32maslive-dev-eks-blue.\033[0m\n"
      else
        shift
        kube_login "$@"
        # Show update notification after command completes
        if [ -n "$update_cache_file" ]; then
          show_update_notification "$update_cache_file"
        fi
      fi
      ;;
    terra|t)
      if [[ "$2" == "-h" ]]; then
        printf "\033c"
        create_header "th terra | t"
        echo "Logs into yl-admin as sudo-admin"
      else
        shift
        terraform_login "$@"
        # Show update notification after command completes
        if [ -n "$update_cache_file" ]; then
          show_update_notification "$update_cache_file"
        fi
      fi
      ;;
    aws|a)
      if [[ "$2" == "-h" ]]; then
        print "\033c"
        create_header "th aws | a"
        printf "Login to our AWS accounts.\n\n"
        printf "Usage: \033[1mth aws [options] | a\033[0m\n"
        printf " ╚═ \033[1mth a\033[0m                   : Open interactive login.\n"
        printf " ╚═ \033[1mth a <account> <s> <b>\033[0m : Quick aws log-in, Where:\n"
        printf "    ╚═ \033[1m<account>\033[0m is an abbreviated account name e.g. dev, cpg etc...\n"
        printf "    ╚═ \033[1m<s>\033[0m is an optional arg which logs you in with the account's sudo role\n"
        printf "    ╚═ \033[1m<b>\033[0m is another optional arg which opens the aws console.\n\n"
        printf "Examples:\n"
        printf " ╚═ $(ccode "th a dev")             : logs you into \033[0;32myl-development\033[0m as \033[1;4;32mdev\033[0m\n"
        printf " ╚═ $(ccode "th a dev s")           : logs you into \033[0;32myl-development\033[0m as \033[1;4;32msudo_dev\033[0m\n"
        printf " ╚═ $(ccode "th a dev s b")         : Opens the AWS console for the above account & role.\n"
      else
        shift
        aws_login "$@"
        # Show update notification after command completes
        if [ -n "$update_cache_file" ]; then
          show_update_notification "$update_cache_file"
        fi
      fi
      ;;
    database|d)
      if [[ "$2" == "-h" ]]; then
        print "\033c"
        create_header "th database | d"
        printf "Connect to our databases (RDS and MongoDB).\n\n"
        printf "Usage: \033[1mth database [options] | d\033[0m\n"
        printf " ╚═ \033[1mth d\033[0m                   : Open interactive database selection.\n"
        printf " ╚═ \033[1mth d <db-env> <port>\033[0m   : Quick database connect, Where:\n"
        printf "    ╚═ \033[1m<db-env>\033[0m is an abbreviation for an RDS or Mongo database, using the format:\n"
        printf "                <dbtype-env>. e.g. \033[1mr-dev\033[0m would connect to the \033[1mdev RDS cluster\033[0m\n"
        printf "    ╚═ \033[1m<port>\033[0m   is An optional arg that allows you to specify a\n"
        printf "                custom port for connection reuse in GUIs\n\n"
        printf "Examples:\n"
        printf " ╚═ $(ccode "th d r-dev")           : connects to the \033[0;32mdb-dev-aurora-postgres-1\033[0m.\n"
        printf " ╚═ $(ccode "th d m-prod")          : connects to \033[0;32mmongodb-YLProd-Cluster-1\033[0m.\n"
      else
        shift
        db_login "$@"
        # Show update notification after command completes
        if [ -n "$update_cache_file" ]; then
          show_update_notification "$update_cache_file"
        fi
      fi
      ;;
    logout|c)
      if [[ "$2" == "-h" ]]; then
	      echo "Logout from all proxies, accounts & clusters."
      else
	      th_kill
      fi
      ;;
    login|l)
      if [[ "$2" == "-h" ]]; then
	      echo "Alias for \"tsh login --auth=ad --proxy=youlend.teleport.sh:443\""
      else
	      tsh login --auth=ad --proxy=youlend.teleport.sh:443
      fi
      ;;
    version|v)
       echo $version
      ;;
    quickstart|qs)
      open "https://youlend.atlassian.net/wiki/spaces/ISS/pages/1384972392/TH+-+Teleport+Helper+Quick+Start"
      ;;
    docs|doc)
      open "https://youlend.atlassian.net/wiki/spaces/ISS/pages/1378517027/TH+-+Teleport+Helper+Docs"
      ;;
    animate)
      shift
      case "$1" in
        yl)
          animate_youlend 
          ;;
        *|th)
          animate_th
          ;;
      esac
      ;;
    loader)
      shift 
      demo_wave_loader "$@"
      ;;
    update|u)
      brew upgrade youlend/tools/th
      # Update version cache after manual upgrade
      local version_cache="$HOME/.cache/th_version"
      mkdir -p "$(dirname "$version_cache")"
      brew list --versions th 2>/dev/null | awk '{print $2}' > "$version_cache"
      ;;
    notifications|n)
      shift
      changelog=$(get_changelog "1.5.6")
      create_notification "1.5.5" "1.5.6" "prompt" "$changelog"
      ;;
    "")
      print_help $version | less -R
      ;;
    *)
      printf "\nMate what? Try running $(ccode "th")\n"
  esac
}
