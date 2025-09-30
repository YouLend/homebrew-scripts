# Check for update results and display notification
show_update_notification() {
    local version_file="$1"

    # Don't wait - just check if file exists
    if [ -f "$version_file" ]; then
        # Read version data using grep for specific keys
        local update_muted th_update_available th_current_version th_latest_version
        local tsh_update_available tsh_current_version tsh_latest_version

        # Extract values from version file
        update_muted=$(grep "^UPDATE_MUTED:" "$version_file" 2>/dev/null | cut -d':' -f2 | tr -d ' ')
        th_update_available=$(grep "^TH_UPDATE_AVAILABLE:" "$version_file" 2>/dev/null | cut -d':' -f2 | tr -d ' ')
        th_current_version=$(grep "^TH_CURRENT_VERSION:" "$version_file" 2>/dev/null | cut -d':' -f2 | tr -d ' ')
        th_latest_version=$(grep "^TH_LATEST_VERSION:" "$version_file" 2>/dev/null | cut -d':' -f2 | tr -d ' ')
        tsh_update_available=$(grep "^TSH_UPDATE_AVAILABLE:" "$version_file" 2>/dev/null | cut -d':' -f2 | tr -d ' ')
        tsh_current_version=$(grep "^TSH_CURRENT_VERSION:" "$version_file" 2>/dev/null | cut -d':' -f2 | tr -d ' ')
        tsh_latest_version=$(grep "^TSH_LATEST_VERSION:" "$version_file" 2>/dev/null | cut -d':' -f2 | tr -d ' ')

        # Check if notifications are muted
        if [[ "$update_muted" == "true" ]]; then
            return 0  # Skip notification silently
        fi

        # Check for TH updates
        if [[ "$th_update_available" == "true" ]] && [[ -n "$th_current_version" ]] && [[ -n "$th_latest_version" ]]; then
            # Get changelog from GitHub release
            local changelog=""
            changelog=$(get_changelog "$th_latest_version")

            create_notification "$th_current_version" "$th_latest_version" "$changelog"
            local notification_result=$?

            # If user selected "No" (mute), update the version file
            if [[ $notification_result -eq 1 ]]; then
                local temp_file=$(mktemp)

                # Copy existing version data except UPDATE_MUTED
                if [[ -f "$version_file" ]]; then
                    while IFS=': ' read -r key value || [[ -n "$key" ]]; do
                        if [[ -n "$key" && -n "$value" && "$key" != "UPDATE_MUTED" ]]; then
                            printf "%s: %s\n" "$key" "$value" >> "$temp_file"
                        fi
                    done < "$version_file"
                fi

                # Add mute flag
                printf "UPDATE_MUTED: true\n" >> "$temp_file"
                mv "$temp_file" "$version_file"
            fi
        fi

        # Check for TSH updates
        if [[ "$tsh_update_available" == "true" ]] && [[ -n "$tsh_current_version" ]] && [[ -n "$tsh_latest_version" ]]; then
            printf "\n\033[1;33m⚠️  TSH Update Available\033[0m\n"
            printf "Current: %s → Latest: %s\n" "$tsh_current_version" "$tsh_latest_version"
            printf "Update available - consider updating your Teleport installation\n"
        fi
    fi
}

# Get changelog from GitHub release
get_changelog() {
    local version="$1"
    local repo="YouLend/homebrew-scripts"  # Update with your actual repo
    
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        # Fetch changelog from GitHub releases API
        local changelog_body=$(curl -s "https://api.github.com/repos/$repo/releases/tags/th-v$version" | jq -r '.body // empty' 2>/dev/null)

        if [[ -n "$changelog_body" && "$changelog_body" != "null" && "$changelog_body" != "empty" ]]; then
            # Extract content after "Summary:" header (with any number of hashtags)
            echo "$changelog_body" | awk '/^#.*Summary/,/^$/ {if (/^$/) exit; print}' | grep '^-' | head -10
        else
            echo "No changelog available for version $version"
        fi
    else
        echo "curl or jq not available - changelog unavailable"
    fi
}

