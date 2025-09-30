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

# Source all .sh files in functions directory and subdirectories
while IFS= read -r -d '' f; do
    source "$f"
done < <(find "$SCRIPT_DIR/functions" -name "*.sh" -print0)

version=$(get_th_version)

th(){
  # Start background update check for interactive commands
  update_cache_file=$(check_updates)

  case "$1" in
    kube|k)
      if [[ "$2" == "-h" ]]; then
        print_kube_help
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
        print_aws_help
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
        print_db_help
      else
        shift
        db_login "$@"
        # Show update notification after command completes
        if [ -n "$update_cache_file" ]; then
          show_update_notification "$update_cache_file"
        fi
      fi
      ;;
    config)
      if [[ "$2" == "-h" ]]; then
        print_config_help
      else
        shift 
        th_config "$@"
      fi
      ;;
    cleanup|c)
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
        th_login
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
    "")
      print_help $version
      ;;
    *)
      printf "\n🤔 Mate what? Try running $(ccode "th")\n"
  esac
}