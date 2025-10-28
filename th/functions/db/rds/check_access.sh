check_rds_login() {
    output=$(tsh db ls -f json)
    dbs=$(echo "$output" | tr -d '\000-\037' | jq -r '.[] | select(.metadata.labels."teleport.dev/discovery-type" == "rds") | .metadata.name')

    # Write to predetermined temp files that parent shell can read
    local access_status="unknown"
    local test_db=""
    
    # First pass: write all db names and find a test database
    while IFS= read -r db_name; do
        if [[ -z "$db_name" ]]; then
            continue
        fi

        # Create display name (everything before -aurora)
        display_name="${db_name%%-aurora*}"
        
        # Create shortened full name (everything before -rds)
        full_name="${db_name%%-rds*}"
        
        echo "$full_name" >> "$temp_db_file"
        echo "$display_name" >> "$temp_display_file"
        
        # Find first prod/sandbox db to test with
        if [[ -z "$test_db" && ("$db_name" == *prod* || "$db_name" == *sandbox*) ]]; then
            test_db="$db_name"
        fi
    done <<< "$dbs"
    
    # Test access with one database if we found one
    if [[ -n "$test_db" ]]; then
        # Start proxy and capture its output
        proxy_output=$(mktemp)
        tsh proxy db "$test_db" --db-name postgres --db-user tf_teleport_rds_read_user --tunnel > "$proxy_output" 2>&1 &
        proxy_pid=$!
        disown

        # Wait for the URL to appear in the output
        psql_url=""
        for _ in {1..20}; do
            if grep -qE 'psql postgres://.*@localhost:[0-9]+/postgres' "$proxy_output"; then
                psql_url=$(grep -Eo 'psql postgres://[^ ]+' "$proxy_output" | head -n1 | cut -d' ' -f2)
                break
            fi
            sleep 0.5
        done

        if [[ -n "$psql_url" ]]; then
            if PGPASSWORD=$PGPASSWORD psql "$psql_url" -c "SELECT 1;" > /dev/null 2>&1; then
                access_status="ok"
            else
                access_status="fail"
            fi
        else
            access_status="fail"
        fi

        # Clean up proxy
        kill "$proxy_pid" 2>/dev/null
        wait "$proxy_pid" 2>/dev/null
        rm -f "$proxy_output"
    fi
    
    # Second pass: write status for all databases based on single test
    while IFS= read -r db_name; do
        if [[ -z "$db_name" ]]; then
            continue
        fi

        if [[ "$db_name" == *prod* || "$db_name" == *sandbox* ]]; then
            echo "$access_status" >> "$temp_status_file"
        else
            echo "n/a" >> "$temp_status_file"
        fi
    done <<< "$dbs"

    # Check elevated access status and write to temp file
    if tsh status | grep -E "(Lead|Admin)" >/dev/null 2>&1; then
        echo "true" >> "$temp_elevated_access_file"
    else
        echo "false" >> "$temp_elevated_access_file"
    fi
}