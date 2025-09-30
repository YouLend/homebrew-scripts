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
        printf "\nSelect option (number): "
        read db_choice
        case "$db_choice" in
            1)
                printf "\n\033[1mRDS\033[0m selected.\n"
                db_type="rds"

                temp_db_file=$(mktemp)
                temp_display_file=$(mktemp)
                temp_status_file=$(mktemp)

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
                
                # Clean up temp files
                rm -f "$temp_db_file" "$temp_display_file" "$temp_status_file"

                local i
                i=0
                for line in "${display_lines[@]}"; do
                    local db_status="${login_status[$i]:-n/a}"

                    case "$db_status" in
                        ok)
                            printf "%2s. %s\n" "$(($i + 1))" "$line"
                            ;;
                        fail)
                            printf "\033[90m%2s. %s\033[0m\n" "$(($i + 1))" "$line"
                            ;;
                        n/a)
                            printf "%2s. %s\n" "$(($i + 1))" "$line"
                            ;;
                    esac
                    i=$((i + 1))
                done

                echo
                printf "\033[1mSelect database (number):\033[0m "
                read db_choice
                if [ -z "$db_choice" ]; then
                    echo "No selection made. Exiting."
                    return 1
                fi

                selected_index=$((db_choice - 1))
                
                if [[ $db_choice -gt 0 && $db_choice -le ${#db_lines} ]]; then
                    selected_db="${db_lines[$selected_index]}"
                    
                    # Check if the selected database has failed login status
                    local selected_status="${login_status[$selected_index]:-n/a}"
                    if [[ "$selected_status" == "fail" ]]; then
                        db_elevated_login "sudo_teleport_rds_read_role" $selected_db
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
                
                check_atlas_access() {
                    tsh status | grep -q "atlas-read-only" && echo "true" > "$temp_atlas_file" || echo "false" > "$temp_atlas_file"
                    tsh db ls --format=json > "$temp_json_file"
                }

                load check_atlas_access "Checking MongoDB access..."
                
                # Read results back from temp files
                has_atlas_access=$(cat "$temp_atlas_file")
                json_output=$(cat "$temp_json_file")
                
                # Clean up temp files
                rm -f "$temp_atlas_file" "$temp_json_file"

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
                
                # Display databases with color coding based on access
                local i=1
                for display_name in "${mongo_display_names[@]}"; do
                    printf "%2s. " "$i"
                    if [[ "$has_atlas_access" == "true" ]]; then
                        printf "%s\n" "$display_name"
                    else
                        printf "\033[90m%s\033[0m\n" "$display_name"
                    fi
                    i=$((i + 1))
                done

                # Prompt for selection
                printf "\n\033[1mSelect database (number):\033[0m "
                read db_choice

                if [ -z "$db_choice" ]; then
                    echo "No selection made. Exiting."
                    return 1
                fi

                selected_index=$((db_choice - 1))
                
                if [[ $db_choice -gt 0 && $db_choice -le ${#mongo_full_names[@]} ]]; then
                    selected_db="${mongo_full_names[$selected_index]}"
                    # If user doesn't have atlas access, trigger elevated login
                    if [[ "$has_atlas_access" != "true" ]]; then
                        db_elevated_login "atlas-read-only" "$selected_db"
                        if [[ $? -ne 0 ]]; then
                            return 0
                        fi
                    fi
                else
                    printf "\n\033[31mInvalid selection\033[0m\n"
                    return 1
                fi
                break
                ;;
            *)
                printf "\n\033[31mInvalid selection here\033[0m\n"
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
    printf "\n\033[1;32m$selected_display\033[0m selected.\n"
    sleep 1

    if [[ -z "$port" ]]; then port=$(find_available_port); fi 

    # If the first column is ">", use the second column; otherwise, use the first.
    if [[ "$db_type" == "rds" ]]; then
        rds_connect "$selected_db" "$port"
        return 0
    fi
    mongo_connect "$selected_db" "$port"
    return 0
}