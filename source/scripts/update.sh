#!/bin/bash
source /utils/logging.sh
source /utils/updater_common.sh

# Directories
GAME_DIRECTORY="./game/csgo"
OUTPUT_DIR="./game/csgo/addons"
TEMP_DIR="./temps"

# Source modular updaters
source /scripts/updaters/metamod.sh
source /scripts/updaters/counterstrikesharp.sh

# Backwards compatibility: Map old ADDON_SELECTION to new boolean variables
migrate_addon_selection() {
    if [ -n "${ADDON_SELECTION}" ]; then
        case "${ADDON_SELECTION}" in
            "Metamod Only")
                METAMOD_AUTOUPDATE=1
                ;;
            "Metamod + CounterStrikeSharp")
                METAMOD_AUTOUPDATE=1
                CSS_AUTOUPDATE=1
                ;;
        esac
    fi
}

# Main addon update function based on boolean variables
update_addons() {
    # Cleanup if enabled
    if [ "${CLEANUP_ENABLED:-0}" -eq 1 ]; then
        cleanup
    fi

    mkdir -p "$TEMP_DIR"

    # Backwards compatibility migration
    migrate_addon_selection

    # Dependency check: CSS requires MetaMod
    if [ "${CSS_AUTOUPDATE:-0}" -eq 1 ] && [ "${METAMOD_AUTOUPDATE:-0}" -ne 1 ]; then
        log_message "CounterStrikeSharp requires MetaMod:Source, auto-enabling..." "warning"
        METAMOD_AUTOUPDATE=1
    fi

    # Consolidated ModSharp incompatibility check
    modsharp_is_present=false
    if [ "${INSTALL_MODSHARP:-0}" -eq 1 ] || grep -q "Game[[:space:]]*sharp" "/home/container/game/csgo/gameinfo.gi" 2>/dev/null; then
        modsharp_is_present=true
    fi

    if [ "$modsharp_is_present" = true ]; then
        if [ "${CSS_AUTOUPDATE:-0}" -eq 1 ]; then
            log_message "ModSharp is present alongside CounterStrikeSharp. These addons may be incompatible and may cause conflicts. It is recommended to use only one of them." "warning"
        fi

        if [ "${INSTALL_SWIFTLY:-0}" -eq 1 ]; then
            log_message "ModSharp is present alongside SwiftlyS2. These addons may be incompatible and may cause conflicts. It is recommended to use only one of them." "warning"
        fi
    fi

    # MetaMod:Source
    if [ "${METAMOD_AUTOUPDATE:-0}" -eq 1 ]; then
        if type update_metamod &>/dev/null; then
            update_metamod
        else
            log_message "update_metamod function not available" "error"
        fi
    fi

    # CounterStrikeSharp
    if [ "${CSS_AUTOUPDATE:-0}" -eq 1 ]; then
        if type update_counterstrikesharp &>/dev/null; then
            update_counterstrikesharp
        else
            log_message "update_counterstrikesharp function not available" "error"
        fi
    fi

    # Clean up
    rm -rf "$TEMP_DIR"
}
