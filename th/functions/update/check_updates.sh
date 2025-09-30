# Background update checker for both th and tsh
check_updates() {
    local th_dir="$HOME/.th"
    local version_file="$th_dir/version"
    local tap_name="youlend/tools"
    local package_name="th"

    # Create .th directory if it doesn't exist
    mkdir -p "$th_dir"
    # Read update suppression setting (default 24 hours)
    local suppression_hours=24
    if [[ -f "$version_file" ]]; then
        while IFS=': ' read -r key value || [[ -n "$key" ]]; do
            if [[ "$key" == "UPDATE_SUPPRESSION_HOURS" && -n "$value" ]]; then
                suppression_hours="$value"
                break
            fi
        done < "$version_file"
    fi

    local suppression_seconds=$((suppression_hours * 3600))

    # Check if we already checked within suppression period based on LAST_UPDATE_CHECK
    if [ -f "$version_file" ]; then
        local last_check=$(grep "^LAST_UPDATE_CHECK:" "$version_file" 2>/dev/null | cut -d':' -f2- | tr -d ' ')
        if [[ -n "$last_check" ]]; then
            local last_check_epoch=$(date -d "$last_check" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$last_check" +%s 2>/dev/null)
            local current_time=$(date +%s)

            if [[ -n "$last_check_epoch" ]]; then
                local time_diff=$((current_time - last_check_epoch))

                # If within suppression period, use cached result
                if [ $time_diff -lt $suppression_seconds ]; then
                    echo "$version_file"
                    return
                else
                    # Suppression period has expired, clear muted flag if it exists
                    if grep -q "^UPDATE_MUTED:" "$version_file" 2>/dev/null; then
                        local temp_file=$(mktemp)
                        while IFS=': ' read -r key value || [[ -n "$key" ]]; do
                            if [[ -n "$key" && -n "$value" && "$key" != "UPDATE_MUTED" ]]; then
                                printf "%s: %s\n" "$key" "$value" >> "$temp_file"
                            fi
                        done < "$version_file"
                        mv "$temp_file" "$version_file"
                    fi
                fi
            fi
        fi
    fi
    
    # Start background process
    {
        set +m
        local results=()

        # Check th updates
        if command -v brew >/dev/null 2>&1; then
            local outdated_info=$(brew outdated $tap_name/$package_name 2>/dev/null)
            
            if [ -n "$outdated_info" ]; then
                local current_version=$(brew list --versions $package_name 2>/dev/null | awk '{print $2}' | head -1)
                local latest_version=$(brew info $tap_name/$package_name 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
                
                if [ -n "$current_version" ] && [ -n "$latest_version" ]; then
                    results+=("TH_UPDATE_AVAILABLE:$current_version:$latest_version")
                else
                    results+=("TH_UP_TO_DATE")
                fi
            else
                local installed_version=$(brew list --versions $package_name 2>/dev/null | awk '{print $2}' | head -1)
                if [ -n "$installed_version" ]; then
                    results+=("TH_UP_TO_DATE")
                else
                    results+=("TH_NOT_INSTALLED_VIA_BREW")
                fi
            fi
        else
            results+=("TH_BREW_NOT_FOUND")
        fi
        
        # Check tsh updates
        if command -v tsh >/dev/null 2>&1; then
            local version_output=$(tsh version 2>/dev/null)
            local current_version
            
            if echo "$version_output" | grep -q "Re-executed from version:"; then
                current_version=$(echo "$version_output" | grep "Re-executed from version:" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1)
            else
                current_version=$(echo "$version_output" | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1)
            fi
            
            if [[ -n "$current_version" ]]; then
                if command -v curl >/dev/null 2>&1; then
                    local latest_version=$(curl -fsSL "https://api.github.com/repos/gravitational/teleport/releases/latest" 2>/dev/null | \
                        grep '"tag_name":' | \
                        sed -E 's/.*"tag_name": "v?([^"]+)".*/\1/' | \
                        head -n1)
                        
                    if [[ -n "$latest_version" ]]; then
                        if printf '%s\n%s\n' "$current_version" "$latest_version" | sort -V | head -n1 | grep -q "^$current_version$"; then
                            if [[ "$current_version" == "$latest_version" ]]; then
                                results+=("TSH_UP_TO_DATE:$current_version")
                            else
                                results+=("TSH_UPDATE_AVAILABLE:$current_version:$latest_version")
                            fi
                        else
                            results+=("TSH_UP_TO_DATE:$current_version")
                        fi
                    else
                        results+=("TSH_GITHUB_API_ERROR")
                    fi
                else
                    results+=("TSH_CURL_NOT_FOUND")
                fi
            else
                results+=("TSH_VERSION_NOT_FOUND")
            fi
        else
            results+=("TSH_NOT_FOUND")
        fi
        

        # Write version information to .th/version file
        local version_file="$HOME/.th/version"
        local current_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local temp_file=$(mktemp)

        # Copy existing version data except fields we'll update
        if [[ -f "$version_file" ]]; then
            while IFS=': ' read -r key value || [[ -n "$key" ]]; do
                if [[ -n "$key" && -n "$value" ]]; then
                    case "$key" in
                        "LAST_UPDATE_CHECK"|"TH_CURRENT_VERSION"|"TH_LATEST_VERSION"|"TH_UPDATE_AVAILABLE"|"TSH_CURRENT_VERSION"|"TSH_LATEST_VERSION"|"TSH_UPDATE_AVAILABLE")
                            # Skip these - we'll add them fresh
                            ;;
                        *)
                            printf "%s: %s\n" "$key" "$value" >> "$temp_file"
                            ;;
                    esac
                fi
            done < "$version_file"
        fi

        # Add update check timestamp
        printf "LAST_UPDATE_CHECK: %s\n" "$current_timestamp" >> "$temp_file"

        # Process results and write version data
        for result in "${results[@]}"; do
            if [[ "$result" == TH_UPDATE_AVAILABLE:* ]]; then
                local current_version=$(echo "$result" | cut -d':' -f2)
                local latest_version=$(echo "$result" | cut -d':' -f3)
                printf "TH_CURRENT_VERSION: %s\n" "$current_version" >> "$temp_file"
                printf "TH_LATEST_VERSION: %s\n" "$latest_version" >> "$temp_file"
                printf "TH_UPDATE_AVAILABLE: true\n" >> "$temp_file"
            elif [[ "$result" == TH_UP_TO_DATE* ]]; then
                printf "TH_UPDATE_AVAILABLE: false\n" >> "$temp_file"
            elif [[ "$result" == TSH_UPDATE_AVAILABLE:* ]]; then
                local current_version=$(echo "$result" | cut -d':' -f2)
                local latest_version=$(echo "$result" | cut -d':' -f3)
                printf "TSH_CURRENT_VERSION: %s\n" "$current_version" >> "$temp_file"
                printf "TSH_LATEST_VERSION: %s\n" "$latest_version" >> "$temp_file"
                printf "TSH_UPDATE_AVAILABLE: true\n" >> "$temp_file"
            elif [[ "$result" == TSH_UP_TO_DATE:* ]]; then
                local current_version=$(echo "$result" | cut -d':' -f2)
                printf "TSH_CURRENT_VERSION: %s\n" "$current_version" >> "$temp_file"
                printf "TSH_UPDATE_AVAILABLE: false\n" >> "$temp_file"
            fi
        done

        # Atomically replace version file
        mv "$temp_file" "$version_file"

        
        disown
        set -m
    } > /dev/null 2>&1 &

    echo "$version_file"
}
