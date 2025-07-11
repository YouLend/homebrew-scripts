# =============================================
# =============== Source Files ================
# =============================================

source "$(dirname "${BASH_SOURCE[0]}")/functions/db.sh"
source "$(dirname "${BASH_SOURCE[0]}")/functions/kube.sh"
source "$(dirname "${BASH_SOURCE[0]}")/functions/aws.sh"
source "$(dirname "${BASH_SOURCE[0]}")/functions/helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/functions/terraform.sh"

th(){ 
  #===========================================
  #============== Main Handler ===============
  #===========================================
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
    login)
      if [[ "$2" == "-h" ]]; then
	      echo "Log in to Teleport."
      else
	      tsh login --auth=ad --proxy=youlend.teleport.sh:443
      fi
      ;;
    -v)
      brew list --versions th | awk '{print $2}'
      ;;
    *)
      printf "\033[1;4mUsage:\033[0m\n\n"
      printf "\033[1mth kube   | k\033[0m : Kubernetes login.\n"
      printf "\033[1mth aws    | a\033[0m : AWS login.\n"
      printf "\033[1mth db     | d\033[0m : Log into our various databases.\n"
      printf "\033[1mth terra  | t\033[0m : Log into yl-admin as sudo-admin for use with Terragrunt.\n"
      printf "\033[1mth logout | l\033[0m : Clean up Teleport session.\n"
      printf "\033[1mth login     \033[0m : Simple log in to Teleport\033[0m\n"
      printf "\033[1m------------------------------------------------------------------------\033[0m\n"
      printf "For specific instructions regarding any of the above, run \033[1mth <option> -h\033[0m\n\n"
      printf "\033[1;4mPages:\033[0m\n\n"
      printf "\033[1mQuickstart:\033[0m \033[1;34mhttps://youlend.atlassian.net/wiki/spaces/ISS/pages/1384972392/TH+-+Teleport+Helper+Quick+Start\033[0m\n\n"
      printf "\033[1mDocs:\033[0m       \033[1;34mhttps://youlend.atlassian.net/wiki/spaces/ISS/pages/1378517027/TH+-+Teleport+Helper+Docs\033[0m\n\n"
      printf "\033[1m--> (Hold CMD + Click to open links)\033[0m"
  esac
}
