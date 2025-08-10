# =============================================
# =============== Source Files ================
# =============================================

version="1.5.1"

if [[ -n "$BASH_SOURCE" ]]; then
    SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
elif [[ -n "$ZSH_VERSION" ]]; then
    SCRIPT_DIR="$(dirname "${(%):-%x}")"
else
    SCRIPT_DIR="$(dirname "$0")"
fi

source "$SCRIPT_DIR/functions/db.sh"
source "$SCRIPT_DIR/functions/kube.sh"
source "$SCRIPT_DIR/functions/aws.sh"
source "$SCRIPT_DIR/functions/helpers.sh"

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
        printf " ╚═ \033[1mth k\033[0m                     : Open interactive login.\n"
        printf " ╚═ \033[1mth k <account>\033[0m           : Quick kube log-in, Where \033[1m<account>\033[0m=dev, corepg etc..\n\n"
        printf "e.g:\n"
        printf " ╚═$(ccode "th k dev")                : logs you into \033[0;32maslive-dev-eks-blue.\033[0m\n"
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
        printf "Usage: \033[1mth aws [options] | k\033[0m\n"
        printf " ╚═ \033[1mth a\033[0m                    : Open interactive login.\n"
        printf " ╚═ \033[1mth a <account> <s>\033[0m      : Quick aws log-in, Where \033[1m<account>\033[0m=dev, corepg etc.. \n"
        printf "                              and \033[1m<s>\033[0m is an optional arg which logs you in with \n"
        printf "                              the account's sudo role\n"
        printf "e.g:\n"
        printf "\033[1m ╚═$(ccode "th a dev")               : logs you into \033[0;32myl-development\033[0m as \033[4;32mdev\033[0m\n"
        printf "\033[1m ╚═$(ccode "th a dev s")             : logs you into \033[0;32myl-development\033[0m as \033[4;32msudo_dev\033[0m\n"
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
	      echo "Usage:"
      else
        shift
        db_login "$@"
        # Show update notification after command completes
        if [ -n "$update_cache_file" ]; then
          show_update_notification "$update_cache_file"
        fi
      fi
      ;;
    logout|l)
      if [[ "$2" == "-h" ]]; then
	      echo "Logout from all proxies, accounts & clusters."
      else
	      th_kill
      fi
      ;;
    login|li)
      if [[ "$2" == "-h" ]]; then
	      echo "Log in to Teleport."
      else
	      tsh login --auth=ad --proxy=youlend.teleport.sh:443
      fi
      ;;
    -v)
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
      ;;
    *)
      print_help $version | less -R
  esac
}
