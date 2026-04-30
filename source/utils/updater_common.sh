#!/bin/bash
# Common utility functions for all updater scripts

# Configuration
VERSION_FILE="${EGG_DIR:-/home/container}/game/versions.txt"
TEMP_DIR="./temps"

# Get GitHub release info (supports prerelease via PRERELEASE env var)
# Outputs JSON: {version, asset_url, asset_name, is_prerelease}
get_github_release() {
    local repo="$1"
    local asset_pattern="${2:-.*}"
    local url="https://api.github.com/repos/$repo/releases"

    # Select endpoint based on prerelease setting (log to stderr to not pollute output)
    if [ "${PRERELEASE:-0}" = "1" ]; then
        log_message "Checking releases (prereleases enabled) for $repo" "debug" >&2
    else
        url="$url/latest"
        log_message "Checking latest stable release for $repo" "debug" >&2
    fi

    curl -s "$url" 2>/dev/null | jq --arg p "$asset_pattern" '
        (if type == "array" then .[0] else . end) //empty |
        {
            version: .tag_name,
            is_prerelease: .prerelease,
            asset_url: (first(.assets[] | select(.name | test($p)) | .browser_download_url) // ""),
            asset_name: (first(.assets[] | select(.name | test($p)) | .name) // "")
        }
    ' 2>/dev/null
}

# Compare two semantic versions (semver)
# Returns:
#   0: if v1 == v2
#   1: if v1 > v2
#   2: if v1 < v2
semver_compare() {
    local v1=$(echo "$1" | sed 's/v//')
    local v2=$(echo "$2" | sed 's/v//')

    # Handle equality first for performance
    if [ "$v1" = "$v2" ]; then
        return 0
    fi

    # Use sort -V to find the "largest" version
    local highest=$(printf "%s\n%s" "$v1" "$v2" | sort -V | tail -n1)

    if [ "$v1" = "$highest" ]; then
        return 1 # v1 > v2
    else
        return 2 # v1 < v2
    fi
}

# Get current version from version file
get_current_version() {
    local addon="$1"
    if [ -f "$VERSION_FILE" ]; then
        grep "^$addon=" "$VERSION_FILE" | cut -d'=' -f2
    else
        echo ""
    fi
}

# Update version file
update_version_file() {
    local addon="$1"
    local new_version="$2"

    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$VERSION_FILE")"

    if [ -f "$VERSION_FILE" ] && grep -q "^$addon=" "$VERSION_FILE"; then
        sed -i.bak "s/^$addon=.*/$addon=$new_version/" "$VERSION_FILE" && rm -f "$VERSION_FILE.bak"
    else
        echo "$addon=$new_version" >> "$VERSION_FILE"
    fi
}

# Centralized download and extract function
handle_download_and_extract() {
    local url="$1"
    local output_file="$2"
    local extract_dir="$3"
    local file_type="$4"  # "zip" or "tar.gz"
    # For GitHub URLs, build a list of mirrors to try (helps users in restricted regions)
    local -a _urls=("$url")
    if [[ "$url" == *"github.com"* ]] || [[ "$url" == *"githubusercontent.com"* ]]; then
        _urls+=(
            "https://ghproxy.net/$url"
            "https://gh.llkk.cc/$url"
        )
    fi

    local _ok=false
    for _url in "${_urls[@]}"; do
        log_message "Downloading from: $_url" "debug"
        if curl -fsSL -m 300 -A "Mozilla/5.0" -o "$output_file" "$_url"; then
            _ok=true
            break
        fi
        log_message "Download failed, trying next mirror..." "warning"
    done

    if ! $_ok; then
        log_message "All download sources failed" "error"
        return 1
    fi

    if [ ! -s "$output_file" ]; then
        log_message "Downloaded file is empty" "error"
        return 1
    fi

    mkdir -p "$extract_dir"

    case $file_type in
        "zip")
            unzip -qq -o "$output_file" -d "$extract_dir" || {
                log_message "Failed to extract zip file" "error"
                return 1
            }
            ;;
        "tar.gz")
            tar -xzf "$output_file" -C "$extract_dir" || {
                log_message "Failed to extract tar.gz file" "error"
                return 1
            }
            ;;
    esac

    return 0
}

# Centralized version checking using semver
check_version() {
    local addon="$1"
    local current="${2:-none}"
    local new="$3"

    if [ "$current" = "none" ] || [ -z "$current" ]; then
        log_message "Update available for $addon: $new (current: none)" "info"
        return 0 # New install
    fi

    semver_compare "$new" "$current"
    case $? in
        0) # Equal
            log_message "$addon is up-to-date ($current)" "debug"
            return 1
            ;;
        1) # new > current
            log_message "Update available for $addon: $new (current: $current)" "info"
            return 0
            ;;
        2) # new < current
            log_message "$addon is at a newer version ($current) than latest ($new). Skipping downgrade." "info"
            return 1
            ;;
    esac
}
