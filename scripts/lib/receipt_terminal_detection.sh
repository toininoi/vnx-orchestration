#!/usr/bin/env bash

# Receipt report filename helpers.
# Filename convention: YYYYMMDD-HHMMSS-{TRACK}-description.md
#   Track letters: A=T1, B=T2, C=T3
#   Legacy format:  YYYYMMDD-HHMMSS-T1-description.md

vnx_receipt_terminal_from_report_name() {
    local report_name="$1"
    local basename="${report_name##*/}"  # Strip path

    # Priority 1: Track letter convention (YYYYMMDD-HHMMSS-A-...)
    if [[ $basename =~ ^[0-9]{8}-[0-9]{6}-([A-C])- ]]; then
        local track="${BASH_REMATCH[1]}"
        case "$track" in
            A) echo "T1" ;;
            B) echo "T2" ;;
            C) echo "T3" ;;
        esac
        return
    fi

    # Priority 2: Track letter anywhere in filename (fallback for custom naming)
    if [[ $basename =~ (^|[-_])([A-C])([-_]|\\.) ]]; then
        local loose_track="${BASH_REMATCH[2]}"
        case "$loose_track" in
            A) echo "T1" ;;
            B) echo "T2" ;;
            C) echo "T3" ;;
        esac
        return
    fi

    # Priority 3: Literal terminal ID in filename
    if [[ $basename == *"T1"* ]]; then
        echo "T1"
    elif [[ $basename == *"T2"* ]]; then
        echo "T2"
    elif [[ $basename == *"T3"* ]]; then
        echo "T3"
    elif [[ $basename == *"T-MANAGER"* ]] || [[ $basename == *"MANAGER"* ]]; then
        echo "T-MANAGER"
    else
        echo ""
    fi
}
