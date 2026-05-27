#!/bin/bash
source /utils/logging.sh

# Format bytes to human readable string
format_bytes() {
    local size="$1"
    if [[ ! "$size" =~ ^[0-9]+$ ]]; then
        echo "0 B"
        return 1
    fi
    if [ "$size" -ge 1099511627776 ]; then # TB
        awk -v s="$size" 'BEGIN { printf "%.2f TB", s/1099511627776 }'
    elif [ "$size" -ge 1073741824 ]; then # GB
        awk -v s="$size" 'BEGIN { printf "%.2f GB", s/1073741824 }'
    elif [ "$size" -ge 1048576 ]; then # MB
        awk -v s="$size" 'BEGIN { printf "%.2f MB", s/1048576 }'
    elif [ "$size" -ge 1024 ]; then # KB
        awk -v s="$size" 'BEGIN { printf "%.2f KB", s/1024 }'
    else
        echo "${size} B"
    fi
}

# VPK Sync Feature - saves TONS of space by symlinking game files
# Instead of each server having 30GB of game files, they share one centralized copy
# Benefits:
# - Each server only needs ~3GB (just configs and workshop stuff)
# - Update once, all servers get it instantly
# - Way less bandwidth and disk usage
# - Configs stay separate per-server

# ! TODO: Remove sync_files() and sync_cfg_files() after 2026-10-01 (SYNC_LOCATION deprecated)
sync_files() {
    # Bail early if sync isn't configured
    if [ ! "${SYNC_LOCATION+defined}" = "defined" ] || [ -z "${SYNC_LOCATION}" ]; then
        return 0
    fi

    local src_dir="${SYNC_LOCATION}"
    local dest_dir="/home/container"

    # Make sure the source directory actually exists
    if [ ! -d "$src_dir" ]; then
        log_warn_code "KL-DMN-05" "SYNC_LOCATION directory not found: $src_dir - skipping VPK sync" \
            "If using centralized VPK push, clear the SYNC_LOCATION variable on this server."
        return 0
    fi

    log_message "Syncing VPK files..." "info"
    # Now create symlinks for all the VPK files
    # This is where we save the big bucks (~56GB of VPKs)
    local vpk_count=0
    local vpk_total_size=0
    while IFS= read -r -d '' vpk_file; do
        rel_path="${vpk_file#$src_dir/}"
        link_path="$dest_dir/$rel_path"

        # Make sure the directory exists before linking
        mkdir -p "$(dirname "$link_path")" 2>/dev/null

        # Determine file size
        file_size=$(stat -c %s "$vpk_file" 2>/dev/null || stat -f %z "$vpk_file" 2>/dev/null || echo 0)
        [[ "$file_size" =~ ^[0-9]+$ ]] || file_size=0

        # Remove existing file/link if present
        if [ -e "$link_path" ] || [ -L "$link_path" ]; then
            rm -f "$link_path" 2>/dev/null
        fi

        # Create the symlink
        if ln -sf "$vpk_file" "$link_path" 2>/dev/null; then
            ((vpk_count++))
            vpk_total_size=$((vpk_total_size + file_size))
        else
            log_message "Failed to link: $rel_path" "warning"
        fi
    done < <(find "$src_dir" -type f -name "*.vpk" -print0 2>/dev/null)

    local human_total
    human_total=$(format_bytes "$vpk_total_size")
    log_message "VPK sync complete - linked ${vpk_count} file(s), total VPK size ${human_total}" "success"

    return 0
}