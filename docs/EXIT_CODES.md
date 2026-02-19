# VNX Exit Codes

## Summary
- `0`: Success
- `10-19`: Validation/config errors
- `20-29`: IO/storage errors
- `30-39`: External dependency errors

## Standard Codes
- `0` Success
- `10` Invalid arguments or usage
- `11` Health/validation check failed (e.g., non-healthy status)
- `20` Read/write failures, missing state files, or storage access issues
- `30` Missing dependencies, subprocess failures, or external service errors

## Notes
- Scripts should default to JSON output for machine parsing.
- Add `--human` to emit human-readable output for operators.
- Keep dispatch/receipt formats unchanged when adding JSON-first outputs.
