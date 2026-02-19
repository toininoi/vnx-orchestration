# Permission Settings for VNX Terminals
**Status**: Active
**Last Updated**: 2026-02-05
**Owner**: T-MANAGER
**Purpose**: Documentation for Permission Settings for VNX Terminals.

## Overview
Claude Code CLI permission settings have been configured to allow seamless access between all VNX terminals (T0-T3) without repeated permission prompts.

## Configuration

### Location
The main settings file is at: `.claude/settings.json`

Since all terminal directories (T0-T3) have symlinks to the main `.claude` directory, they all share the same settings.

### additionalDirectories Setting

The `additionalDirectories` setting in the permissions section grants Claude Code read access to specified directories without interactive permission prompts:

```json
{
  "permissions": {
    "additionalDirectories": [
      "terminals/T0",
      "terminals/T1",
      "terminals/T2", 
      "terminals/T3",
      "vnx-system",
      "./"
    ],
    // ... other permissions
  }
}
```

## How It Works

1. **Symlink Structure**: Each terminal has a `.claude` symlink:
   ```
   terminals/T0/.claude -> /Users/.../<project>/.claude
   terminals/T1/.claude -> /Users/.../<project>/.claude
   terminals/T2/.claude -> /Users/.../<project>/.claude
   terminals/T3/.claude -> /Users/.../<project>/.claude
   ```

2. **Shared Configuration**: All terminals use the same `.claude/settings.json`

3. **Directory Access**: The `additionalDirectories` setting allows any Claude instance started in a terminal subdirectory to access:
   - All other terminal directories (T0-T3)
   - The vnx-system directory
   - The project root directory

## Benefits

1. **No Permission Prompts**: Claude in T0 can read files from T1, T2, T3 without asking
2. **Cross-Terminal Collaboration**: Terminals can inspect each other's work
3. **VNX System Access**: All terminals can access orchestration files
4. **Seamless Workflow**: No interruptions for file access permissions

## Important Notes

### Official Documentation
According to Claude Code documentation, `additionalDirectories` should be placed inside the `permissions` object, not at the root level. The screenshot information was partially correct but needed the proper nesting.

### Relative Paths
Paths in `additionalDirectories` are relative to the `.claude` directory location, not the current working directory.

### Security Considerations
- This grants READ access only by default
- Write operations still require explicit permission or must be in the `allow` list
- Sensitive files can still be protected using the `deny` list

## Verification

To verify the settings are working:

1. Start Claude in any terminal (T0-T3)
2. Try reading a file from another terminal:
   ```bash
   cat ../T1/somefile.txt  # From T0
   ```
3. Should work without permission prompt

## Troubleshooting

If permission prompts still appear:

1. **Check symlinks**: Ensure `.claude` symlinks are intact
2. **Restart Claude**: Settings apply on session start
3. **Verify paths**: Paths must be relative to `.claude` directory
4. **Check syntax**: JSON must be valid with proper nesting

## Future Improvements

Currently, Claude Code doesn't support `additionalDirectories` in project-specific settings files (feature request #3146). When this feature is added, we could have more granular control per terminal.