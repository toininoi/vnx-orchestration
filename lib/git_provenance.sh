#!/bin/bash
# .claude/vnx-system/lib/git_provenance.sh
# Git provenance capture helper functions for VNX receipt system
#
# Purpose: Capture git repository state at receipt creation time
# Usage: source this file and call capture_git_provenance()
# Output: JSON object with git_ref, branch, is_dirty, dirty_files, diff_summary

capture_git_provenance() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)

    # Not a git repository
    if [ -z "$repo_root" ]; then
        printf '{"git_ref":"not_a_repo","branch":"unknown","is_dirty":false,"dirty_files":0,"diff_summary":null,"captured_at":"%s","captured_by":"receipt_processor"}' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        return 0
    fi

    # Capture git metadata
    local git_ref branch dirty_count is_dirty
    git_ref=$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || echo "unknown")
    branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    dirty_count=$(git -C "$repo_root" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

    # Determine dirty status
    if [ "$dirty_count" -gt 0 ]; then
        is_dirty="true"
    else
        is_dirty="false"
    fi

    # Extract diff summary (only if dirty)
    local diff_json="null"
    if [ "$is_dirty" = "true" ]; then
        local shortstat
        shortstat=$(git -C "$repo_root" diff --shortstat 2>/dev/null)
        if [ -n "$shortstat" ]; then
            # Parse: " 12 files changed, 342 insertions(+), 87 deletions(-)"
            local files_changed insertions deletions
            files_changed=$(echo "$shortstat" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo "0")
            insertions=$(echo "$shortstat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
            deletions=$(echo "$shortstat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
            diff_json="{\"files_changed\":${files_changed:-0},\"insertions\":${insertions:-0},\"deletions\":${deletions:-0}}"
        fi
    fi

    # Output JSON
    printf '{"git_ref":"%s","branch":"%s","is_dirty":%s,"dirty_files":%d,"diff_summary":%s,"captured_at":"%s","captured_by":"receipt_processor"}' \
        "$git_ref" "$branch" "$is_dirty" "$dirty_count" "$diff_json" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

# Export function for use in scripts that source this file
export -f capture_git_provenance
