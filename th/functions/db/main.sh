db_login() {
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
                temp_status_file=$(mktemp)

                printf "\033c" 
                create_header "Available Databases"
                
                load check_rds_login "Checking cluster access..."

                # Read results back into global arrays
                db_lines=()
                login_status=()

                while IFS= read -r line; do
                    db_lines+=("$line")
                done < "$temp_db_file"
                
                while IFS= read -r line; do
                    login_status+=("$line")
                done < "$temp_status_file"
                
                # Clean up temp files
                rm -f "$temp_db_file" "$temp_status_file"

                local i
                i=0
                for line in "${db_lines[@]}"; do
                    # Handle bash (0-indexed) vs zsh (1-indexed) arrays
                    local array_index=$i
                    if [[ -n "$ZSH_VERSION" ]]; then
                        array_index=$((i + 1))
                    fi
                    local db_status="${login_status[$array_index]:-n/a}"

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
                # Handle bash (0-indexed) vs zsh (1-indexed) arrays for selection
                local db_array_index=$selected_index
                local status_array_index=$selected_index
                if [[ -n "$ZSH_VERSION" ]]; then
                    db_array_index=$((selected_index + 1))
                    status_array_index=$((selected_index + 1))
                fi
                
                if [[ $db_choice -gt 0 && $db_choice -le ${#db_lines} ]]; then
                    selected_db="${db_lines[$db_array_index]}"
                    
                    # Check if the selected database has failed login status
                    local selected_status="${login_status[$status_array_index]:-n/a}"
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
                    tsh status | grep -q "atlas-can-read" && echo "true" > "$temp_atlas_file" || echo "false" > "$temp_atlas_file"
                    tsh db ls --format=json > "$temp_json_file"
                }

                load check_atlas_access "Checking MongoDB access..."
                
                # Read results back from temp files
                has_atlas_access=$(cat "$temp_atlas_file")
                json_output=$(cat "$temp_json_file")
                
                # Clean up temp files
                rm -f "$temp_atlas_file" "$temp_json_file"

                filtered_dbs=$(echo "$json_output" | tr -d '\000-\037' | jq -r '[.[] | select(.metadata.labels.db_type != "rds")]')
                # Display databases with color coding based on access
                local i=1
                while IFS= read -r db_name; do
                    if [[ -z "$db_name" ]]; then
                        continue
                    fi
                    
                    printf "%2s. " "$i"
                    if [[ "$has_atlas_access" == "true" ]]; then
                        printf "%s\n" "$db_name"
                    else
                        printf "\033[90m%s\033[0m\n" "$db_name"
                    fi
                    i=$((i + 1))
                done <<< "$(echo "$filtered_dbs" | tr -d '\000-\037' | jq -r '.[] | .metadata.name')"

                # Prompt for selection
                printf "\n\033[1mSelect database (number):\033[0m "
                read db_choice

                if [ -z "$db_choice" ]; then
                    echo "No selection made. Exiting."
                    return 1
                fi

                selected_index=$((db_choice - 1))
                db_count=$(echo "$filtered_dbs" | tr -d '\000-\037' | jq 'length')
                
                if [[ $db_choice -gt 0 && $db_choice -le $db_count ]]; then
                    selected_db=$(echo "$filtered_dbs" | tr -d '\000-\037' | jq -r ".[$selected_index].metadata.name")
                    
                    # If user doesn't have atlas access, trigger elevated login
                    if [[ "$has_atlas_access" != "true" ]]; then
                        db_elevated_login "atlas-read-only" "$selected_db"
                    fi
                else
                    printf "\n\033[31mInvalid selection\033[0m\n"
                    return 1
                fi
                break
                ;;
            *)
                printf "\n\033[31mInvalid selection here2\033[0m\n"
                ;;
        esac
    done
    if [[ "$reauth_db" == "TRUE" ]]; then
        # Once the user returns from the elevated login, re-authenticate with request id.
        printf "\033c"
        create_header "Re-Authenticating"
        tsh logout
        tsh login --auth=ad --proxy=youlend.teleport.sh:443 --request-id="$REQUEST_ID" > /dev/null 2>&1
        reauth_db="FALSE"
    fi

    if [[ "$exit_db" == "TRUE" ]]; then
        exit_db="FALSE"
        return 0
    fi

    printf "\n\033[1;32m$selected_db\033[0m selected.\n"
    sleep 1

    # If the first column is ">", use the second column; otherwise, use the first.
    if [[ "$db_type" == "rds" ]]; then
        rds_connect "$selected_db"
        return 0
    fi
    mongo_connect "$selected_db"
    return 0
}