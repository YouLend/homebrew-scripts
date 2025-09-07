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
      changelog=$(get_changelog "1.6.0")
      create_notification "1.5.9" "1.6.0" "$changelog"
      ;;
    "")
      print_help $version | less -R
      ;;
    *)
      printf "\n🤔 Mate what? Try running $(ccode "th")\n"
  esac
}