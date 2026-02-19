#!/bin/bash
# Test dispatcher enhancement for Track 2b Mode Control
# This is a standalone test script that processes dispatches with mode control

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
VNX_DIR="$PROJECT_ROOT/.claude/vnx-system"
TEST_DIR="$VNX_DIR/tests"

PROVIDER="${VNX_T1_PROVIDER:-claude_code}"
PROVIDER="$(echo "$PROVIDER" | tr '[:upper:]' '[:lower:]')"
clear_cmd="/clear"
case "$PROVIDER" in
  codex_cli|codex) clear_cmd="/new" ;;
esac

echo "=== TEST DISPATCHER WITH MODE CONTROL ==="
echo "Provider: $PROVIDER"
echo ""

# Function to extract mode field from dispatch
extract_mode() {
    local file="$1"
    local mode=$(grep "^Mode:" "$file" 2>/dev/null | sed 's/.*Mode:\s*//' | sed 's/#.*//' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    echo "${mode:-none}"
}

# Function to extract ClearContext field
extract_clear_context() {
    local file="$1"
    local clear=$(grep "^ClearContext:" "$file" 2>/dev/null | sed 's/.*ClearContext:\s*//' | sed 's/#.*//' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    echo "${clear:-false}"
}

# Function to extract Requires-Model field
extract_requires_model() {
    local file="$1"
    local model=$(grep "^Requires-Model:" "$file" 2>/dev/null | sed 's/.*Requires-Model:\s*//' | sed 's/#.*//' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    echo "${model:-}"
}

# Function to detect mode from keywords
detect_mode_from_keywords() {
    local file="$1"
    local content=$(cat "$file" | tr '[:upper:]' '[:lower:]')

    if echo "$content" | grep -q "planning gate\|create.*plan\|architecture.*design"; then
        echo "planning"
    elif echo "$content" | grep -q "deep cognition\|think hard\|complex.*analysis"; then
        echo "thinking"
    else
        echo "none"
    fi
}

# Function to apply mode configuration to T1
apply_mode_config() {
    local dispatch_file="$1"
    local target_pane="%1"  # Always T1 for testing

    echo "Processing: $(basename "$dispatch_file")"

    # Extract configuration
    local mode=$(extract_mode "$dispatch_file")
    local clear_context=$(extract_clear_context "$dispatch_file")
    local requires_model=$(extract_requires_model "$dispatch_file")

    # If no explicit mode, try keyword detection
    if [[ "$mode" == "none" ]]; then
        mode=$(detect_mode_from_keywords "$dispatch_file")
        if [[ "$mode" != "none" ]]; then
            echo "  AUTO-DETECTED mode from keywords: $mode"
        fi
    else
        echo "  EXPLICIT mode field: $mode"
    fi

    echo "  Configuration: clear=$clear_context, model=$requires_model, mode=$mode"

    # Step 1: Clear context if requested
    if [[ "$clear_context" == "true" ]]; then
        echo "  → Clearing context..."
        tmux send-keys -t "vnx:0.$target_pane" "$clear_cmd"
        tmux send-keys -t "vnx:0.$target_pane" "Enter"
        sleep 3
    fi

    # Step 2: Switch model if specified
    if [[ -n "$requires_model" ]]; then
        echo "  → Switching to model: $requires_model"
        tmux send-keys -t "vnx:0.$target_pane" "/model $requires_model"
        tmux send-keys -t "vnx:0.$target_pane" "Enter"
        sleep 3
    fi

    # Step 3: Activate mode
    if [[ "$PROVIDER" == "claude_code" ]]; then
        case "$mode" in
            planning)
                echo "  → Activating PLAN mode..."
                tmux send-keys -t "vnx:0.$target_pane" -l $'\e[Z'  # First Shift+Tab
                sleep 0.5
                tmux send-keys -t "vnx:0.$target_pane" -l $'\e[Z'  # Second Shift+Tab
                sleep 2
                ;;
            thinking)
                echo "  → Activating THINKING mode..."
                tmux send-keys -t "vnx:0.$target_pane" Tab
                sleep 2
                ;;
            none|normal)
                echo "  → Staying in NORMAL mode"
                ;;
            *)
                echo "  → Unknown mode: $mode"
                ;;
        esac
    else
        echo "  → Skipping mode toggles (provider '$PROVIDER')"
    fi

    # Step 4: Send the dispatch content (simplified for testing)
    echo "  → Sending dispatch content..."
    local instruction=$(awk '/^Instruction:/{flag=1; next} /^\[\[DONE\]\]/{flag=0} flag' "$dispatch_file")
    echo "$instruction" | tmux load-buffer -
    tmux paste-buffer -t "vnx:0.$target_pane"
    sleep 0.5
    tmux send-keys -t "vnx:0.$target_pane" "Enter"

    echo "  ✓ Dispatch processed"
    echo ""
}

# Main test execution
echo "Select test dispatch to process:"
echo "1) test-dispatch-explicit-mode.md (Mode: planning, ClearContext: true, Model: opus)"
echo "2) test-dispatch-thinking-mode.md (Mode: thinking)"
echo "3) test-dispatch-keyword-detection.md (Auto-detect from 'planning gate')"
echo "4) Process all test dispatches"
echo ""
echo "Enter choice (1-4):"
read -r choice

case $choice in
    1)
        apply_mode_config "$TEST_DIR/test-dispatch-explicit-mode.md"
        ;;
    2)
        apply_mode_config "$TEST_DIR/test-dispatch-thinking-mode.md"
        ;;
    3)
        apply_mode_config "$TEST_DIR/test-dispatch-keyword-detection.md"
        ;;
    4)
        echo "Processing all test dispatches..."
        apply_mode_config "$TEST_DIR/test-dispatch-explicit-mode.md"
        sleep 10
        apply_mode_config "$TEST_DIR/test-dispatch-thinking-mode.md"
        sleep 10
        apply_mode_config "$TEST_DIR/test-dispatch-keyword-detection.md"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo "=== TEST COMPLETE ==="
echo "Check T1 for mode indicators and responses"
