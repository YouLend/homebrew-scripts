#===============================================
#================ Kubernetes ===================
#===============================================
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

kube_elevated_login() {
    local cluster="$1"
    while true; do
        printf "\033c" 
        printf "\n====================== \033[1mPrivilege Request\033[0m =========================="
        printf "\n\nYou don't have write access to \033[1m$cluster\033[0m."
        printf "\n\n\033[1mWould you like to raise a request?\033[0m"
        printf "\n\n\033[1mNote:\033[0m Entering (N/n) will log you in as a read-only user."
        printf "\n\n(Yy/Nn): "
        read elevated
        if [[ "$elevated" =~ ^[Yy]$ ]]; then
        printf "\n\033[1mEnter your reason for request: \033[0m"
        read reason

        if [ "$cluster" == 'live-prod-eks-blue' ]; then
            request_output=$(tsh request create --roles sudo_prod_eks_cluster --reason "$reason")
        elif [ "$cluster" == 'live-usprod-eks-blue' ]; then
            request_output=$(tsh request create --roles sudo_usprod_eks_cluster --reason "$reason")
        else
            printf "\nCluster doesn't exist"
        fi

        # 2. Extract request ID
        REQUEST_ID=$(echo "$request_output" | grep "Request ID:" | awk '{print $3}')

        printf "\n\n✅ \033[1;32mAccess request sent!\033[0m\n\n"
        return 0

        elif [[ "$elevated" =~ ^[Nn]$ ]]; then
        echo
        echo "Request creation skipped."
        return 0
        else
        printf "\n\033[31mInvalid input. Please enter y or n.\033[0m\n"
        fi
    done
}
# ========================
# Main - Interactive Login 
# ========================
kube_login() {
    if [ "$reauth_kube" == "true" ]; then
        printf "\nReauthenticating"
        printf "\n\033[1mRe-Authenticating\033[0m\n\n"
        tsh logout
        tsh login --auth=ad --proxy=youlend.teleport.sh:443 --request-id="$REQUEST_ID" > /dev/null 2>&1
        reauth_kube="false"
        return 0
    else
        th_login
    fi

    local output clusters
    output=$(tsh kube ls -f json)
    clusters=$(echo "$output" | jq -r '.[].kube_cluster_name')

    if [ -z "$clusters" ]; then
        echo "No Kubernetes clusters available."
        return 1
    fi

    printf "\n\033[1;4mAvailable Clusters:\033[0m\n"

    local cluster_lines=()
    local login_status=()

    while IFS= read -r cluster_name; do
        if [ -z "$cluster_name" ]; then
            continue
        fi

        cluster_lines+=("$cluster_name")

        # Only try login for prod clusters
        if [[ "$cluster_name" == *prod* ]]; then
            if tsh kube login "$cluster_name" > /dev/null 2>&1; then
                if kubectl auth can-i create pod > /dev/null 2>&1; then
                    login_status+=("ok")
                else
                    login_status+=("fail")
                fi
            else
                login_status+=("fail")
            fi
        else
            login_status+=("n/a")
        fi
    done <<< "$clusters"

    echo
    for i in "${!cluster_lines[@]}"; do
        line="${cluster_lines[$i]}"
        status="${login_status[$i]}"

        case "$status" in
            ok)
                printf "%2d. %s\n" $((i + 1)) "$line"
                ;;
            fail)
                printf "\033[90m%2d. %s\033[0m\n" $((i + 1)) "$line"
                ;;
            n/a)
                printf "%2d. %s\n" $((i + 1)) "$line"
                ;;
        esac
    done

    printf "\n\033[1mSelect cluster (number):\033[0m "
    read choice

    if [ -z "$choice" ]; then
        echo "No selection made. Exiting."
        return 1
    fi

    selected_index=$((choice - 1))
    if [[ -z "${cluster_lines[$selected_index]}" ]]; then
        printf "\n\033[31mInvalid selection\033[0m\n"
        return 1
    fi

    selected_cluster="${cluster_lines[$selected_index]}"
    selected_status="${login_status[$selected_index]}"

    if [[ "$selected_status" == "fail" ]]; then
        kube_elevated_login "$selected_cluster"
        printf "\n\033[1mLogging you into:\033[0m \033[1;32m$selected_cluster\033[0m\n"
        tsh kube login "$selected_cluster"
    else
        printf "\n\033[1mLogging you into:\033[0m \033[1;32m$selected_cluster\033[0m\n"
        tsh kube login "$selected_cluster"
    fi
}
