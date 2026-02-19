#!/bin/bash
# Safe mode configuration function with optional reset
# Handles the mode persistence issue

configure_terminal_mode_safe() {
    local target_pane="$1"      # e.g., %1, %2, %3
    local dispatch_file="$2"     # Full dispatch file path

    echo "=== SAFE MODE CONFIGURATION ==="

    # Extract configuration
    local mode=$(grep "^Mode:" "$dispatch_file" 2>/dev/null | sed 's/.*Mode:\s*//' | sed 's/#.*//' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    local clear_context=$(grep "^ClearContext:" "$dispatch_file" 2>/dev/null | sed 's/.*ClearContext:\s*//' | sed 's/#.*//' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    local requires_model=$(grep "^Requires-Model:" "$dispatch_file" 2>/dev/null | sed 's/.*Requires-Model:\s*//' | sed 's/#.*//' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    local force_normal=$(grep "^ForceNormalMode:" "$dispatch_file" 2>/dev/null | sed 's/.*ForceNormalMode:\s*//' | sed 's/#.*//' | tr -d ' ' | tr '[:upper:]' '[:lower:]')

    echo "Configuration:"
    echo "  Mode: ${mode:-none}"
    echo "  ClearContext: ${clear_context:-false}"
    echo "  Requires-Model: ${requires_model:-none}"
    echo "  ForceNormalMode: ${force_normal:-false}"
    echo ""

    # Step 1: Force reset to normal mode if requested
    if [[ "${force_normal:-false}" == "true" ]] || [[ -n "$mode" && "$mode" != "none" ]]; then
        echo "→ Resetting to normal mode (cycling 4 times)..."
        for i in {1..4}; do
            tmux send-keys -t "vnx:0.$target_pane" -l $'\e[Z'
            sleep 0.3
        done
        echo "  ✓ Reset to normal mode"
        sleep 1
    fi

    # Step 2: Clear context if requested
    if [[ "${clear_context:-false}" == "true" ]]; then
        echo "→ Clearing context..."
        tmux send-keys -t "vnx:0.$target_pane" "/clear"
        tmux send-keys -t "vnx:0.$target_pane" "Enter"
        sleep 3
        echo "  ✓ Context cleared"
    fi

    # Step 3: Switch model if specified
    if [[ -n "$requires_model" && "$requires_model" != "none" ]]; then
        echo "→ Switching to model: $requires_model"
        tmux send-keys -t "vnx:0.$target_pane" "/model $requires_model"
        tmux send-keys -t "vnx:0.$target_pane" "Enter"
        sleep 3
        echo "  ✓ Model switched"
    fi

    # Step 4: Activate requested mode (only if we reset first)
    case "${mode:-none}" in
        planning)
            echo "→ Activating PLAN mode..."
            tmux send-keys -t "vnx:0.$target_pane" -l $'\e[Z'  # First Shift+Tab
            sleep 0.5
            tmux send-keys -t "vnx:0.$target_pane" -l $'\e[Z'  # Second Shift+Tab
            sleep 2
            echo "  ✓ Plan mode activated"
            ;;
        thinking)
            echo "→ Activating THINKING mode..."
            tmux send-keys -t "vnx:0.$target_pane" Tab
            sleep 2
            echo "  ✓ Thinking mode activated"
            ;;
        normal|none)
            echo "→ Staying in NORMAL mode"
            ;;
        *)
            echo "→ Unknown mode: $mode"
            ;;
    esac

    echo "=== MODE CONFIGURATION COMPLETE ==="
}

# Test with a sample dispatch
if [[ "$1" == "test" ]]; then
    # Create a test dispatch with ForceNormalMode
    cat > /tmp/test_dispatch_safe.md << 'EOF'
[[TARGET:A]]
Role: architect
Track: A
Terminal: T1
Gate: planning
Priority: P1
Cognition: normal
Mode: planning
ClearContext: true
Requires-Model: opus
ForceNormalMode: true    # NEW: Force reset to normal before applying mode
Dispatch-ID: TEST-SAFE-001

Instruction:
- Test safe mode configuration
- Should reset to normal first, then activate plan mode

[[DONE]]
EOF

    echo "Testing safe mode configuration..."
    configure_terminal_mode_safe "%1" "/tmp/test_dispatch_safe.md"
fi