db_login() {
    # Enable bash-compatible array indexing for zsh
    [[ -n "$ZSH_VERSION" ]] && setopt KSH_ARRAYS
    
    th_login

    if [[ -n "$1" ]]; then
        db_quick_login "$@"
        return 0
    fi

    printf "\033c"
    create_header "DB"
    printf "Which database would you like to connect to?"
    printf "\n\n1. \033[1mRDS\033[0m"
    printf "\n2. \033[1mMongoDB\033[0m\n"
    local db_type
    local selected_db
    while true; do
        printf "\nSelect database type (number): \n"
        create_input 1 1 50 "Invalid input. " "numerical"
        local input_exit_code=$?
        db_choice="$user_input"

        if [ $input_exit_code -eq 130 ]; then
            return 130
        fi
        case "$db_choice" in
            1)
                printf "\n\033[1mRDS\033[0m selected.\n"
                db_type="rds"

                temp_db_file=$(mktemp)
                temp_display_file=$(mktemp)
                temp_status_file=$(mktemp)
                temp_elevated_access_file=$(mktemp)

                printf "\033c" 
                create_header "Available Databases"
                
                load check_rds_login "Checking cluster access..."

                # Read results back into global arrays
                db_lines=()
                display_lines=()
                login_status=()

                while IFS= read -r line; do
                    db_lines+=("$line")
                done < "$temp_db_file"
                
                while IFS= read -r line; do
                    display_lines+=("$line")
                done < "$temp_display_file"
                
                while IFS= read -r line; do
                    login_status+=("$line")
                done < "$temp_status_file"
                
                # Read elevated access status
                local has_elevated_access="false"
                if [[ -f "$temp_elevated_access_file" ]]; then
                    has_elevated_access=$(cat "$temp_elevated_access_file")
                fi

                # Clean up temp files
                rm -f "$temp_db_file" "$temp_display_file" "$temp_status_file" "$temp_elevated_access_file"

                # Find the longest database display name for alignment
                local max_length=0
                for line in "${display_lines[@]}"; do
                    if [[ ${#line} -gt $max_length ]]; then
                        max_length=${#line}
                    fi
                done

                local i
                i=0
                for line in "${display_lines[@]}"; do
                    local db_status="${login_status[$i]:-n/a}"
                    local db_name="${db_lines[$i]}"
                    local sudo_indicator=""

                    # Check if database has request role available (only show if user doesn't have elevated access)
                    if [[ "$has_elevated_access" == "false" ]]; then
                        local request_role=$(load_config_by_account "db" "$db_name" "request_role" "rds")
                        if [[ -n "$request_role" && "$request_role" != "" ]]; then
                            sudo_indicator="$(printf '\033[32m[S]\033[0m')"
                        fi
                    fi

                    case "$db_status" in
                        ok)
                            printf "%2s. %-${max_length}s %s\n" "$(($i + 1))" "$line" "$sudo_indicator"
                            ;;
                        fail)
                            printf "\033[90m%2s. %-${max_length}s %s\033[0m\n" "$(($i + 1))" "$line" "$sudo_indicator"
                            ;;
                        n/a)
                            printf "%2s. %-${max_length}s %s\n" "$(($i + 1))" "$line" "$sudo_indicator"
                            ;;
                    esac
                    i=$((i + 1))
                done

                # Only show the note if user doesn't have elevated access (and thus might see [S] indicators)
                if [[ "$has_elevated_access" == "false" ]]; then
                    printf "\033[1A"
                    create_note "Note: \033[32m[S]\033[0m indicates database requires elevated access."
                    printf "\033[1A"
                    printf "           Selecting one will start an access request.\n"
                fi

                echo
                printf "\033[1mSelect database (number):\033[0m\n"
                create_input 1 2 50 "Invalid input. " "numerical"
                local input_exit_code=$?
                db_choice="$user_input"

                if [ $input_exit_code -eq 130 ]; then
                    return 130
                fi

                selected_index=$((db_choice - 1))
                
                if [[ $db_choice -gt 0 && $db_choice -le ${#db_lines} ]]; then
                    selected_db="${db_lines[$selected_index]}"
                    
                    # Check if the selected database has failed login status
                    local selected_status="${login_status[$selected_index]:-n/a}"
                    if [[ "$selected_status" == "fail" ]]; then
                        db_elevated_login "sudo_teleport_rds_read_role" $selected_db
                        
                        local input_exit_code=$?
                        if [ $input_exit_code -eq 130 ]; then
                            return 130
                        fi
                    fi
                else
                    printf "\n\033[31mInvalid selection here\033[0m\n"
                    return 1
                fi
                break
                ;;
            2)
                printf "\n\033[1mMongoDB\033[0m selected.\n"
                db_type="mongo"

                printf "\033c"
                create_header "Available Databases"

                local has_atlas_access json_output
                
                temp_atlas_file=$(mktemp)
                temp_json_file=$(mktemp)
                temp_elevated_access_file=$(mktemp)
                
                check_atlas_access() {
                    tsh status | grep -q "atlas-read-only" && echo "true" > "$temp_atlas_file" || echo "false" > "$temp_atlas_file"
                    tsh db ls --format=json > "$temp_json_file"
                    # Check elevated access status and write to temp file
                    if tsh status | grep -E "(Lead|Admin)" >/dev/null 2>&1; then
                        echo "true" >> "$temp_elevated_access_file"
                    else
                        echo "false" >> "$temp_elevated_access_file"
                    fi
                }

                load check_atlas_access "Checking MongoDB access..."
                
                # Read results back from temp files
                has_atlas_access=$(cat "$temp_atlas_file")
                json_output=$(cat "$temp_json_file")
                local has_elevated_access="false"
                if [[ -f "$temp_elevated_access_file" ]]; then
                    has_elevated_access=$(cat "$temp_elevated_access_file")
                fi

                # Clean up temp files
                rm -f "$temp_atlas_file" "$temp_json_file" "$temp_elevated_access_file"

                filtered_dbs=$(echo "$json_output" | tr -d '\000-\037' | jq -r '[.[] | select(.metadata.labels."teleport.dev/discovery-type" != "rds")]')
                
                # Create arrays for mongo databases
                mongo_full_names=()
                mongo_display_names=()
                
                while IFS= read -r db_name; do
                    if [[ -z "$db_name" ]]; then
                        continue
                    fi
                    
                    # Extract display name: everything between dashes, strip YL prefix
                    # mongodb-YLProd-Cluster-1 -> Prod
                    display_name=$(echo "$db_name" | cut -d'-' -f2 | sed 's/^YL//')
                    
                    mongo_full_names+=("$db_name")
                    mongo_display_names+=("$display_name")
                done <<< "$(echo "$filtered_dbs" | tr -d '\000-\037' | jq -r '.[] | .metadata.name')"
                
                # Find the longest mongo display name for alignment
                local max_length=0
                for display_name in "${mongo_display_names[@]}"; do
                    if [[ ${#display_name} -gt $max_length ]]; then
                        max_length=${#display_name}
                    fi
                done

                # Display databases with color coding based on access and sudo indicators
                local i=1
                for display_name in "${mongo_display_names[@]}"; do
                    local full_name="${mongo_full_names[$((i-1))]}"
                    local sudo_indicator=""

                    # Check if database has request role available (only show if user doesn't have elevated access)
                    if [[ "$has_elevated_access" == "false" ]]; then
                        local request_role=$(load_config_by_account "db" "$full_name" "request_role" "mongo")
                        if [[ -n "$request_role" && "$request_role" != "" ]]; then
                            sudo_indicator="$(printf '\033[32m[S]\033[0m')"
                        fi
                    fi

                    printf "%2s. " "$i"
                    if [[ "$has_atlas_access" == "true" ]]; then
                        printf "%-${max_length}s %s\n" "$display_name" "$sudo_indicator"
                    else
                        printf "\033[90m%-${max_length}s %s\033[0m\n" "$display_name" "$sudo_indicator"
                    fi
                    i=$((i + 1))
                done

                # Only show the note if user doesn't have elevated access (and thus might see [S] indicators)
                if [[ "$has_elevated_access" == "false" ]]; then
                    printf "\033[1A"
                    create_note "Note: \033[32m[S]\033[0m indicates database requires elevated access."
                    printf "\033[1A"
                    printf "           Selecting one will start an access request.\n"
                fi

                # Prompt for selection
                printf "\n\033[1mSelect database (number):\033[0m\n"
                create_input 1 2 50 "Invalid input. " "numerical"
                local input_exit_code=$?
                db_choice="$user_input"

                if [ $input_exit_code -eq 130 ]; then
                    return 130
                fi

                selected_index=$((db_choice - 1))
                
                if [[ $db_choice -gt 0 && $db_choice -le ${#mongo_full_names[@]} ]]; then
                    selected_db="${mongo_full_names[$selected_index]}"
                    # If user doesn't have atlas access, trigger elevated login
                    if [[ "$has_atlas_access" != "true" ]]; then
                        db_elevated_login "atlas-read-only" "$selected_db"
                        local input_exit_code=$?
                        if [ $input_exit_code -eq 130 ]; then
                            return 130
                        fi
                    fi
                else
                    printf "\n\033[31mInvalid selection\033[0m\n"
                    return 1
                fi
                break
                ;;
        esac
    done
    
    if [[ "$exit_db" == "TRUE" ]]; then
        exit_db="FALSE"
        return 0
    fi

    # Get display name for selected database
    local selected_display
    if [[ "$db_type" == "rds" ]]; then
        selected_display="${display_lines[$selected_index]}"
    else
        selected_display="${mongo_display_names[$selected_index]}"
    fi

    if [[ -z "$port" ]]; then port=$(find_available_port); fi 

    # If the first column is ">", use the second column; otherwise, use the first.
    if [[ "$db_type" == "rds" ]]; then
        rds_connect "$selected_db" "$port"
        return 0
    fi
    mongo_connect "$selected_db" "$port"
    return 0
}