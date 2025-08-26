# Background update checker
check_th_updates_background() {
    local daily_cache_file="$HOME/.cache/th_update_check"
    local session_cache_file="/tmp/.th_update_check_$$"
    local tap_name="youlend/tools"
    local package_name="th"
    
    # Create cache directory if it doesn't exist
    mkdir -p "$(dirname "$daily_cache_file")"
    
    # Check if we already checked today
    if [ -f "$daily_cache_file" ]; then
        local cache_time=$(stat -c %Y "$daily_cache_file" 2>/dev/null || stat -f %m "$daily_cache_file" 2>/dev/null)
        local current_time=$(date +%s)
        local time_diff=$((current_time - cache_time))
        
        # If cache is less than 24 hours old, use cached result
        if [ $time_diff -lt 3600 ]; then
            local cached_result=$(cat "$daily_cache_file" 2>/dev/null)
            # If muted, keep it muted until 24 hours pass
            if [[ "$cached_result" == "MUTED_UNTIL_TOMORROW" ]]; then
                cp "$daily_cache_file" "$session_cache_file" 2>/dev/null
                echo "$session_cache_file"
                return
            else
                cp "$daily_cache_file" "$session_cache_file" 2>/dev/null
                echo "$session_cache_file"
                return
            fi
        fi
    fi
    
    # Start background process like create_proxy does
    {
        set +m
        if command -v brew >/dev/null 2>&1; then
            # Use brew outdated to check for updates - it handles everything for us
            local outdated_info=$(brew outdated $tap_name/$package_name 2>/dev/null)
            
            if [ -n "$outdated_info" ]; then
                # Get current version from brew list
                local current_version=$(brew list --versions $package_name 2>/dev/null | awk '{print $2}' | head -1)
                # Get latest version from brew info - extract version number after package name
                local latest_version=$(brew info $tap_name/$package_name 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
                
                if [ -n "$current_version" ] && [ -n "$latest_version" ]; then
                    echo "UPDATE_AVAILABLE:$current_version:$latest_version" | tee "$daily_cache_file" > "$session_cache_file"
                else
                    echo "UP_TO_DATE" | tee "$daily_cache_file" > "$session_cache_file"
                fi
            else
                # Either up to date or not installed via brew
                local installed_version=$(brew list --versions $package_name 2>/dev/null | awk '{print $2}' | head -1)
                if [ -n "$installed_version" ]; then
                    echo "UP_TO_DATE" | tee "$daily_cache_file" > "$session_cache_file"
                else
                    echo "NOT_INSTALLED_VIA_BREW" | tee "$daily_cache_file" > "$session_cache_file"
                fi
            fi
        else
            echo "BREW_NOT_FOUND" | tee "$daily_cache_file" > "$session_cache_file"
        fi
        disown
        set -m
    } > /dev/null 2>&1 &
    
    echo "$session_cache_file"
}

# Check for update results and display notification
show_update_notification() {
    local update_cache_file="$1"
    
    # Don't wait - just check if file exists
    if [ -f "$update_cache_file" ]; then
        local result=$(cat "$update_cache_file")
        rm -f "$update_cache_file" 2>/dev/null
        
        # Check if notifications are muted
        if [[ "$result" == "MUTED_UNTIL_TOMORROW" ]]; then
            return 0  # Skip notification silently
        elif [[ "$result" == UPDATE_AVAILABLE:* ]]; then
            local current_version=$(echo "$result" | cut -d':' -f2)
            local latest_version=$(echo "$result" | cut -d':' -f3)

            # Get changelog from GitHub release
            local changelog=""
            changelog=$(get_changelog "$latest_version")

            create_notification "$current_version" "$latest_version" "$changelog"

            return 0
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
            echo "$changelog_body" | sed -n '/^### Summary/,$ p' | grep '^-' | head -10
        else
            echo "No changelog available for version $version"
        fi
    else
        echo "curl or jq not available - changelog unavailable"
    fi
}