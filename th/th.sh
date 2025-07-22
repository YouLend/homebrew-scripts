# =============================================
# =============== Source Files ================
# =============================================

source "$(dirname "${BASH_SOURCE[0]}")/functions/db.sh"
source "$(dirname "${BASH_SOURCE[0]}")/functions/kube.sh"
source "$(dirname "${BASH_SOURCE[0]}")/functions/aws.sh"
source "$(dirname "${BASH_SOURCE[0]}")/functions/helpers.sh"
version="1.3.8"
th(){ 
  case "$1" in
    kube|k)
      if [[ "$2" == "-h" ]]; then
        echo "Interactive login for our K8s clusters."
        #echo "Usage:"
        #echo "-l : List all kubernetes clusters"
        #echo "-s : List all current sessions"
        #echo "-e : Execute a command"
        #echo "-j : Join something"
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
        #echo "Usage:"
        #echo "-l : List all accounts"
      else
        shift
        aws_login 
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
    *)
      print_help $version | less -R
  esac
}
