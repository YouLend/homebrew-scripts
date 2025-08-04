# =============================================
# =============== Source Files ================
# =============================================

version="1.4.6"

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
  case "$1" in
    kube|k)
      if [[ "$2" == "-h" ]]; then
        echo "Interactive login for our K8s clusters."
      else
        shift
        kube_login "$@"
      fi
      ;;
    terra|t)
      if [[ "$2" == "-h" ]]; then
	      echo "Logs into yl-admin as sudo-admin"
      else
        shift
        terraform_login "$@"
      fi
      ;;
    aws|a)
      if [[ "$2" == "-h" ]]; then
        echo "Interactive login for our AWS accounts."
      else
        shift
        aws_login "$@"
      fi
      ;;
    database|d)
      if [[ "$2" == "-h" ]]; then
	      echo "Usage:"
      else
        shift
        db_login "$@"
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
    *)
      print_help $version | less -R
  esac
}
