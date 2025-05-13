# ===========================================================
# 		    Teleport CLI shortcuts
# ===========================================================
th(){
  # ========================
  # Helper - Teleport Login
  # ========================
  th_login() {
    if tsh status 2>/dev/null | grep -q 'Logged in as:'; then
      printf "\033[1;32mAlready logged in to Teleport.\033[0m\n"
      return 0
    fi
    echo "Logging you into Teleport..."
    tsh login --auth=ad --proxy=youlend.teleport.sh:443 > /dev/null 2>&1
    # Wait until login completes (max 15 seconds)
    for i in {1..30}; do
      if tsh status 2>/dev/null | grep -q 'Logged in as:'; then
	printf "\n✅ \033[1;32mLogged in successfully!\033[0m\n"
	return 0
      fi
      sleep 0.5
    done

    printf "\n❌ \033[1;31mTimed out waiting for Teleport login.\033[0m"
    return 1
  }

  
  # ========================
  # Helper - Teleport Logout
  # ========================
  th_kill() {
    printf "🧹 \033[1mCleaning up Teleport session...\033[0m"

    # Enable nullglob in Zsh to prevent errors from unmatched globs
    if [ -n "$ZSH_VERSION" ]; then
      setopt NULL_GLOB
    fi

    # Remove temp credential files
    for f in /tmp/yl* /tmp/tsh* /tmp/admin_*; do
      [ -e "$f" ] && rm -f "$f"
    done

    # Determine which shell profile to clean
    local shell_name shell_profile
    shell_name=$(basename "$SHELL")

    if [ "$shell_name" = "zsh" ]; then
      shell_profile="$HOME/.zshrc"
    elif [ "$shell_name" = "bash" ]; then
      shell_profile="$HOME/.bash_profile"
    else
      echo "Unsupported shell: $shell_name. Skipping profile cleanup."
      shell_profile=""
    fi

    # Remove any lines sourcing proxy envs from the profile
    if [ -n "$shell_profile" ] && [ -f "$shell_profile" ]; then
      sed -i.bak '/[[:space:]]*source \/tmp\/tsh_proxy_/d' "$shell_profile"
      printf "\n\n✏️ \033[0mRemoving source lines from $shell_profile...\033[0m"
    fi

    printf "\n📃 \033[0mRemoving ENVs...\033[0m"

    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_CA_BUNDLE
    unset HTTPS_PROXY
    unset ACCOUNT
    unset AWS_DEFAULT_REGION

    printf "\n💀 \033[0mKilling all running tsh proxies...\033[0m"
    # Kill all tsh proxy aws processes
    ps aux | grep '[t]sh proxy aws' | awk '{print $2}' | xargs kill 2>/dev/null
    tsh logout > /dev/null 2>&1
    
    tsh apps logout > /dev/null 2>&1
    printf "\n\n✅ \033[1;32mLogged out of all apps, clusters & proxies\033[0m"
  }

  #===============================================
  #================ Kubernetes ===================
  #===============================================
  tkube_elevated_login() {
    while true; do
      printf "\n====================== \033[1mPrivilege Request\033[0m =========================="
      printf "\n\nDo you require access to \033[1mprod/usprod?\033[0m (y/n): "
      read elevated
      if [[ $elevated =~ ^[Yy]$ ]]; then
	# Adds checks for new kubernetes roles here (us-production-eks)	

	printf "\n\033[1mEnter your reason for request:\033[0m"
	read reason
	printf "\n✅ \033[1;32mAccess request sent!\033[0m\n\n"
	tsh request create --roles production-eks-clusters --reason "$reason"
	ELEVATED="true"
	tkube_interactive_login
	return 0

      elif [[ $elevated =~ ^[Nn]$ ]]; then
	echo
	echo "Request creation skipped."
	return 0
      else
	echo "Invalid input. Please enter y or n."
      fi
    done
  }
  # ========================
  # Main - Interactive Login 
  # ========================
  tkube_interactive_login() {
    th_login

    if [[ "$ELEVATED" != "true" ]]; then
      tkube_elevated_login
    else
      return 0
    fi

    local output header clusters
    output=$(tsh kube ls -f text)
    header=$(echo "$output" | head -n 2)
    clusters=$(echo "$output" | tail -n +3)

    if [ -z "$clusters" ]; then
      echo "No Kubernetes clusters available."
      return 1
    fi

    # Show cluster list and prompt for normal login
    printf "\n\033[1;4mAvailable Clusters:\033[0m\n\n"
    echo "$header"
    echo "$clusters" | nl -w2 -s'. '

    printf "\n\033[1mSelect cluster (number):\033[0m "
    read choice

    if [ -z "$choice" ]; then
      echo "No selection made. Exiting."
      return 1
    fi

    local chosen_line login_cluster
    chosen_line=$(echo "$clusters" | sed -n "${choice}p")
    if [ -z "$chosen_line" ]; then
      echo "Invalid selection."
      return 1
    fi

    login_cluster=$(echo "$chosen_line" | awk '{print $1}')
    if [ -z "$login_cluster" ]; then
      echo "Invalid selection."
      return 1
    fi

    printf "\n\033[1mLogging you into:\033[0m \033[1;32m$login_cluster\033[0m\n\n"
    tsh kube login "$login_cluster"
    ELEVATED="false"
  }

  # ========================
  # Helper - Local Handler 
  # ========================
  tkube() {
    if [ $# -eq 0 ]; then
      tkube_interactive_login
      return
    fi 

    case "$1" in
      -l)
	tsh kube ls -f text
	;;
      -s)
	shift
	if [ $# -eq 0 ]; then
	  echo "Missing arguments for -s"
	  return 1
	fi
	tsh kube sessions "$@"
	;;
      -e)
	shift
	if [ $# -eq 0 ]; then
	  echo "Missing arguments for -e"
	  return 1
	fi
	tsh kube exec "$@"
	;;
      -j)
	shift
	if [ $# -eq 0 ]; then
	  echo "Missing arguments for -j"
	  return 1
	fi
	tsh kube join "$@"
	;;
      *)
	echo "Usage:"
	echo "-l : List all clusters"
	echo "-s : List all sessions"
	echo "-e : Execute command"
	echo "-j : Join something"
	;;
    esac
  }

  #===============================================
  #=================== AWS =======================
  #===============================================

  # ========================
  # Helper - Get Credentials
  # ========================
  get_credentials() {
    # Enable nullglob in Zsh to avoid errors on unmatched globs
    if [ -n "$ZSH_VERSION" ]; then
      setopt NULL_GLOB
    fi

    local app
    app=$(tsh apps ls -f text | awk '$1 == ">" { print $2 }')

    if [ -z "$app" ]; then
      echo "No active app found. Run 'tsh apps login <app>' first."
      return 1
    fi

    local log_file="/tmp/tsh_proxy_${app}.log"

    # Kill proxy here - Future implementation
    # pkill -f "tsh proxy" 2>/dev/null
    # sleep 2

    # Clean up any matching temp files — won't error in Zsh or Bash now
    for f in /tmp/yl* /tmp/tsh* /tmp/admin_*; do
      [ -e "$f" ] && rm -f "$f"
    done

    printf "\nCleaned up existing credential files."

    printf "\nStarting AWS proxy for \033[1;32m$app\033[0m... Process id: "

    tsh proxy aws --app "$app" > "$log_file" 2>&1 &

    # Wait up to 10 seconds for credentials to appear
    local wait_time=0
    while ! grep -q '^  export AWS_ACCESS_KEY_ID=' "$log_file"; do
      sleep 0.5
      wait_time=$((wait_time + 1))
      if (( wait_time >= 20 )); then
	echo "Timed out waiting for AWS credentials."
	return 1
      fi
    done

    # Retain only export lines
    printf "%s\n" "$(grep -E '^[[:space:]]*export ' "$log_file")" > "$log_file"

    # Source all export lines into the shell
    while read -r line; do
      [[ $line == export* || $line == "  export"* ]] && eval "$line"
    done < "$log_file"

    export ACCOUNT=$app
    echo "export ACCOUNT=$app" >> "$log_file"

    # Determine shell and modify appropriate profile
    local shell_name shell_profile
    shell_name=$(basename "$SHELL")

    if [ "$shell_name" = "zsh" ]; then
      shell_profile="$HOME/.zshrc"
    elif [ "$shell_name" = "bash" ]; then
      shell_profile="$HOME/.bash_profile"
    else
      shell_profile="$HOME/.profile"  # fallback
    fi

    sed -i.bak '/^source \/tmp\/tsh/d' "$shell_profile"
    echo "source $log_file" >> "$shell_profile"

    # Set region based on app name
    if [[ $app =~ ^yl-us ]]; then
      export AWS_DEFAULT_REGION=us-east-2
      echo "export AWS_DEFAULT_REGION=us-east-2" >> "$log_file"
    else
      export AWS_DEFAULT_REGION=eu-west-1
      echo "export AWS_DEFAULT_REGION=eu-west-1" >> "$log_file"
    fi

    printf "\nCredentials exported, and made global, for app: \033[1;32m$app\033[0m"
  } 

  # ========================
  # Helper - Create Proxy
  # ========================
  create_proxy(){
    while true; do
      printf "\n\n======================== \033[1mProxy Creation\033[0m ============================"
      printf "\n\nUsing a proxy will allow you to use \033[1maws\033[0m commands\n"
      printf "without needing to prefix with \033[1mtsh\033[0m"
      printf "\n\n\033[1mWould you like to create a proxy? (y/n):\033[0m "
      read proxy
      if [[ $proxy =~ ^[Yy]$ ]]; then
	get_credentials
	break
      elif [[ $proxy =~ ^[Nn]$ ]]; then
	printf "\nProxy creation skipped."
	break
      else
	echo "Invalid input. Please enter Y or N."
      fi
    done
  }

  # ========================
  # Helper - Create Request 
  # ========================
  raise_request(){
    local app="$1"
    while true; do
      printf "\n\n\033[1mWould you like to raise a privilege request? (y/n):\033[0m "
      read request
      if [[ $request =~ ^[Yy]$ ]]; then
	printf "\n\033[1mEnter request reason:\033[0m "
	read reason
	if [[ $app == "yl-production" ]]; then
	  printf "\n✅ \033[1;32mAccess request sent for sudo_prod.\033\n\n[0m"
	  tsh request create --roles sudo_prod_role --reason $reason
	  RAISED_ROLE="sudo_prod"
	  return 0
	elif [[ $app == "yl-usproduction" ]]; then
	  printf "\n✅ \033[1;32mAccess request sent for sudo_usprod.\033\n\n[0m"
	  tsh request create --roles sudo_usprod_role --reason $reason
	  RAISED_ROLE="sudo_usprod"
	  return 0
	else
	  printf "\nNo associated roles"
	  return 1 
	fi
	return 1
	break
      elif [[ $request =~ ^[Nn]$ ]]; then
	return 1
      else
	printf "\n❌ \033[1;31mInvalid input. Please enter Y or N.\033[0m\n"
      fi
    done
  }

  # ========================
  # Helper - Login via req --- Not currently in use
  # ========================
  request_login() {
    # Loop until valid input (y/n)
    while true; do
      echo
      read -p "Have a request ID? (y/n): " request
      if [[ $request =~ ^[Yy]$ ]]; then
	echo
	tsh logout
	echo
	while true; do
	  echo
	  read -p "Enter your request ID: " id
	  if [[ -n "$id" ]]; then
	    echo
	    echo "Logging in with request ID: $id"
	    tsh login --auth=ad --proxy=youlend.teleport.sh:443 --request-id="$id"
	    return 0
	  else
	    echo
	    echo "Request ID cannot be empty. Please try again."
	  fi
	done
      elif [[ $request =~ ^[Nn]$ ]]; then
	raise_request $app
	return 0
      else
	echo
	echo "Invalid input. Please enter y or n."
      fi
    done
  }

  # ========================
  # Main - Interactive Login
  # ========================
  tawsp_interactive_login() {
    th_login

    local output header apps

    # Get the list of apps.
    output=$(tsh apps ls -f text)
    header=$(echo "$output" | head -n 2)
    apps=$(echo "$output" | tail -n +3)

    if [ -z "$apps" ]; then
      echo "No apps available."
      return 1
    fi

    # Display header and numbered list of apps.
    printf "\n\033[1;4mAvailable apps:\033[0m\n\n"
    echo "$header"
    echo "$apps" | nl -w2 -s'. '

    # Prompt for app selection.
    echo
    printf "\033[1mSelect Application (number):\033[0m "
    read app_choice
    if [ -z "$app_choice" ]; then
      echo "No selection made. Exiting."
      return 1
    fi

    local chosen_line app
    chosen_line=$(echo "$apps" | sed -n "${app_choice}p")
    if [ -z "$chosen_line" ]; then
      echo "Invalid selection."
      return 1
    fi

    # If the first column is ">", use the second column; otherwise, use the first.
    app=$(echo "$chosen_line" | awk '{if ($1==">") print $2; else print $1;}')
    if [ -z "$app" ]; then
      echo "Invalid selection."
      return 1
    fi

    printf "\nSelected app: \033[1;32m$app\033[0m\n"

    # Log out of the selected app to force fresh AWS role output.
    printf "\nLogging out of app: $app...\n"
    tsh apps logout > /dev/null 2>&1

    # Run tsh apps login to capture the AWS roles listing.
    # (This command will error out because --aws-role is required, but it prints the available AWS roles.)
    local login_output
    login_output=$(tsh apps login "$app" 2>&1)

    # Extract the AWS roles section.
    # The section is expected to start after "Available AWS roles:" and end before the error message.
    local role_section
    role_section=$(echo "$login_output" | awk '/Available AWS roles:/{flag=1; next} /ERROR: --aws-role flag is required/{flag=0} flag')

    # Remove lines that contain "ERROR:" or that are empty.
    role_section=$(echo "$role_section" | grep -v "ERROR:" | sed '/^\s*$/d')

    if [ -z "$role_section" ]; then

      local default_role="$(echo "$login_output" | grep -o 'arn:aws:iam::[^ ]*' | awk -F/ '{print $NF}')"

      printf "\n====================== \033[1mPrivilege Request\033[0m =========================="
      printf "\n\nNo privileged roles found. Your only available role is: \033[1;32m%s\033[0m" $default_role
      if raise_request "$app"; then
	local role="$RAISED_ROLE"
	printf "\n\033[1mLogging you in to \033[1;32m$app\033[0m \033[1mas\033[0m \033[1;32m$role\033[0m!"
	tsh apps login "$app" --aws-role "$role" > /dev/null 2>&1
	printf "\n\n✅ \033[1;32m Logged in successfully!\033[0m" 
	create_proxy
      else
	printf "\n\033[1mLogging you in to \033[1;32m$app\033[0m \033[1mas\033[0m \033[1;32m$default_role\033[0m!" 
	tsh apps login "$app" > /dev/null 2>&1
	printf "\n\n✅ \033[1;32m Logged in successfully!\033[0m" 
	return 
      fi
      return
    fi

    # Assume the first 2 lines of role_section are headers.
    local role_header roles_list
    role_header=$(echo "$role_section" | head -n 2)
    roles_list=$(echo "$role_section" | tail -n +3 | sed '/^\s*$/d')

    if [ -z "$roles_list" ]; then
      echo "No roles found in the AWS roles listing."
      echo "Logging you into app \"$app\" without specifying an AWS role."
      tsh apps login "$app"
      return
    fi

    printf "\n\033[1;4mAvailable roles:\033[0m\n\n"
    echo "$role_header"
    echo "$roles_list" | nl -w2 -s'. '

    # Prompt for role selection.
    printf "\n\033[1mSelect role (number):\033[0m " 
    read role_choice
    if [ -z "$role_choice" ]; then
      echo "No selection made. Exiting."
      return 1
    fi

    local chosen_role_line role_name
    chosen_role_line=$(echo "$roles_list" | sed -n "${role_choice}p")
    if [ -z "$chosen_role_line" ]; then
      echo "Invalid selection."
      return 1
    fi

    role_name=$(echo "$chosen_role_line" | awk '{print $1}')
    if [ -z "$role_name" ]; then
      echo "Invalid selection."
      return 1
    fi

    printf "\nLogging you into \033[1;32m$app\033[0m as \033[1;32m$role_name\033[0m"
    tsh apps login "$app" --aws-role "$role_name" > /dev/null 2>&1

    create_proxy 
  }

  # ========================
  # Helper - Local Handler
  # ========================
  tawsp() {
    if [[ $# -eq 0 ]]; then
      tawsp_interactive_login
      return
    fi
    case "$1" in
      -l)
	tsh apps ls -f text
      ;;
      *)
	echo "Usage:"
	echo "-i : Interactive login"
	echo "-l : List all accounts"
    esac
  }

  #===============================================
  #================= Terraform ===================
  #===============================================
  terraform_login() {
    th_login     
    tsh apps logout > /dev/null 2>&1
    printf "\n\033[1mLogging into \033[1;32myl-admin\033[0m \033[1mas\033[0m \033[1;32msudo_admin.\033[0m"
    tsh apps login "yl-admin" --aws-role "sudo_admin" > /dev/null 2>&1
    get_credentials
    printf "\n\n✅ \033[1;32mLogged in successfully!\033[0m"
  }

  #===============================================
  #================ Main Handler =================
  #===============================================
  # Handle user input & redirect to the appropriate function
  case "$1" in
    kube|k)
      if [[ "$2" == "-h" ]]; then
	echo "Usage:"
	echo "-l : List all kubernetes clusters"
	echo "-s : List all current sessions"
	echo "-e : Execute a command"
	echo "-j : Join something"
      else
	shift
	tkube "$@"
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
	echo "Usage:"
	echo "-l : List all accounts"
      else
	shift
	tawsp "$@"
      fi
      ;;
    logout|l)
      if [[ "$2" == "-h" ]]; then
	echo "Logout from all proxies."
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
      brew info th | tail -n +1 | grep -m1 "stable" | awk '{print $NF}'
      ;;
    *)
      printf "\033[1;4mUsage:\033[0m\n\n"
      printf "\033[1mth kube   | k\033[0m : Kubernetes login.\n"
      printf "\033[1mth aws    | a\033[0m : AWS login.\n"
      printf "\033[1mth terra  | t\033[0m : Log into yl-admin as sudo-admin for use with Terraform/Grunt.\n"
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
