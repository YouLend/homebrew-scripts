# =============================================
# =============== Source Files ================
# =============================================

source "$(dirname "${BASH_SOURCE[0]}")/functions/db.sh"
source "$(dirname "${BASH_SOURCE[0]}")/functions/kube.sh"
source "$(dirname "${BASH_SOURCE[0]}")/functions/aws.sh"
source "$(dirname "${BASH_SOURCE[0]}")/functions/helpers.sh"

print_logo() {
  local version="1.3.4"
  printf "\n"
  printf "                \033[0m\033[38;5;250m ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁\033[0m\033[1;34m\033[0m\n"
  printf "                \033[0m\033[38;5;250m▕░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▏\033[0m\033[1;34m\033[0m\n"
  printf "               \033[0m\033[38;5;250m▕░░░░░░░░░░░ \033[0m\033[1;97m████████╗ ██╗  ██╗\033[0m\033[38;5;250m ░░░░░░░░░░░░░▏\033[0m\033[1;34m\033[0m\n"
  printf "              \033[0m\033[38;5;249m▕▒▒▒▒▒▒▒▒▒▒▒ \033[0m\033[1;97m╚══██╔══╝ ██║  ██║\033[0m\033[38;5;249m ▒▒▒▒▒▒▒▒▒▒▒▒▒▏\033[0m\033[1;34m\033[0m\n"
  printf "             \033[0m\033[38;5;248m▕▓▓▓▓▓▓▓▓▓▓▓▓▓▓ \033[0m\033[1;97m█▉║    ███████║\033[0m\033[38;5;248m ▓▓▓▓▓▓▓▓▓▓▓▓▓▏\033[0m\033[1;34m\033[0m\n"
  printf "            \033[0m\033[38;5;247m▕██████████████ \033[0m\033[1;97m█▉║    ██╔══██║\033[0m\033[38;5;247m █████████████▏\033[0m\033[1;34m\033[0m\n"
  printf "           \033[0m\033[38;5;246m▕██████████████ \033[0m\033[1;97m██║    ██║  ██║\033[0m\033[38;5;246m █████████████▏\033[0m\033[1;34m\033[0m\n"
  printf "          \033[0m\033[38;5;245m▕██████████████ \033[0m\033[1;97m██╝    ██╝  ██╝\033[0m\033[38;5;245m █████████████▏\033[0m\033[1;34m\033[0m\n"
  printf "         \033[0m\033[38;5;245m▕██████████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄█████████████▏\033[0m\033[1;34m\033[0m\n"
  printf "         \033[0m\033[38;5;245m ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔\033[0m\033[1;34m\033[0m\n"
  printf "        \033[0m\033[38;5;245m■■■■■■■■■■\033[0m\033[1m Teleport Helper - v$version \033[0m\033[38;5;245m■■■■■■■■■■■\033[0m\033[1;34m\033[0m\n"
  printf "\n"
}
th(){ 
  printf "\033c"
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
      brew list --versions th | awk '{print $2}'
      ;;
    quickstart|qs)
      open "https://youlend.atlassian.net/wiki/spaces/ISS/pages/1384972392/TH+-+Teleport+Helper+Quick+Start"
      ;;
    docs|doc)
      open "https://youlend.atlassian.net/wiki/spaces/ISS/pages/1378517027/TH+-+Teleport+Helper+Docs"
      ;;
    *)
      print_logo $version
      printf "\033[0m\033[38;5;245m    ▄███████▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀███████████▀\033[0m\033[1;34m\033[0m\n"
      printf "\033[0m\033[38;5;245m  ━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\033[1m Usage \033[0m\033[38;5;245m━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\033[1;34m\033[0m\n"
      printf "\033[0m\033[38;5;245m▄███████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄███████▀\033[0m\033[1;34m\033[0m\n\n"

      printf "     ╚═ \033[1mth kube       | k\033[0m   : Kubernetes login.\n"
      printf "     ╚═ \033[1mth aws        | a\033[0m   : AWS login.\n"
      printf "     ╚═ \033[1mth db         | d\033[0m   : Log into our various databases.\n"
      printf "     ╚═ \033[1mth terra      | t\033[0m   : Log into yl-admin as sudo-admin for use with Terragrunt.\n"
      printf "     ╚═ \033[1mth logout     | l\033[0m   : Clean up Teleport session.\n"
      printf "     ╚═ \033[1mth login      |  \033[0m   : Simple log in to Teleport\033[0m\n"
      printf "     ╚═ \033[1mth quickstart | qs\033[0m  : Open quickstart guide in browser.\n"
      printf "     ╚═ \033[1mth docs       | doc\033[0m : Open documentation in browser.\n"
      printf "     \033[0m\033[38;5;245m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\033[1;34m\033[0m\n"
      printf "     For specific instructions regarding any of the above, run \033[1mth <option> -h\033[0m\n\n"

      printf "\033[0m\033[38;5;245m    ▄███████▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀███████████▀\033[0m\033[1;34m\033[0m\n"
      printf "\033[0m\033[38;5;245m  ━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\033[1m Docs \033[0m\033[38;5;245m━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\033[1;34m\033[0m\n"
      printf "\033[0m\033[38;5;245m▄███████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄███████▀\033[0m\033[1;34m\033[0m\n\n"
      printf "     Run the following commands to access the documentation pages: \n"
      printf "     ╚═ \033[1mQuickstart: \033[1;34mth qs\033[0m\n"
      printf "     ╚═ \033[1mDocs:       \033[1;34mth doc\033[0m\n"

      printf "          \033[0m\033[38;5;245m  ▁▁▁▁▁▁▁▁▁▁▁▁▁\033[0m\033[1;97m  ▄▄▄ ▄▁▄  \033[0m\033[38;5;245m▁▁▁▁▁▁▁▁▁▁▁▁▁▁\033[0m\033[1;34m\033[0m\n"
      printf "          \033[0m\033[38;5;245m ▔▔▔▔▔▔▔▔▔▔▔▔▔▔\033[0m\033[1;97m   ▀  ▀▔▀  \033[0m\033[38;5;245m▔▔▔▔▔▔▔▔▔▔▔▔▔\033[0m\033[1;34m\033[0m\n"
  esac
}
