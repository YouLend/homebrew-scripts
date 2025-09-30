# yep
get_th_version() {
    local version_cache="$HOME/.cache/th_version"
    if [ -f "$version_cache" ]; then
        cat "$version_cache"
    else
        # First time or cache missing - create it
        mkdir -p "$(dirname "$version_cache")"
        brew list --versions th 2>/dev/null | awk '{print $2}' > "$version_cache"
        cat "$version_cache" 2>/dev/null || echo "unknown"
    fi
}

# yessir
find_available_port() {
    local port
    for i in {1..100}; do
        port=$((RANDOM % 20000 + 40000))
        if ! nc -z localhost $port &> /dev/null; then
            echo $port
            return 0
        fi
    done
    echo 50000
}

# Job loader - Sets wave_loader while a given job runs in the background.
load() {
    local job="$1"
    local message="${2:-"Loading.."}"
    {
        set +m
        $job &
        wave_loader $! "$message"
        wait
        set -m
    }   2>/dev/null
}