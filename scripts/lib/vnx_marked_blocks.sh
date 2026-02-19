#!/usr/bin/env bash

# Helpers for inserting and updating VNX marker blocks in markdown files.

vnx_build_block_file() {
  local snippet_file="$1"
  local block_file="$2"
  local marker_begin="$3"
  local marker_end="$4"

  {
    printf '%s\n' "$marker_begin"
    cat "$snippet_file"
    printf '%s\n' "$marker_end"
  } > "$block_file"
}

vnx_upsert_marked_block() {
  local target_file="$1"
  local snippet_file="$2"
  local marker_begin="$3"
  local marker_end="$4"

  local block_file
  block_file="$(mktemp)"
  vnx_build_block_file "$snippet_file" "$block_file" "$marker_begin" "$marker_end"

  if [ ! -f "$target_file" ]; then
    cat "$block_file" > "$target_file"
    rm -f "$block_file"
    return 1
  fi

  local has_begin=0
  local has_end=0
  if grep -Fq "$marker_begin" "$target_file"; then
    has_begin=1
  fi
  if grep -Fq "$marker_end" "$target_file"; then
    has_end=1
  fi

  local tmp_file
  tmp_file="$(mktemp)"

  if [ "$has_begin" -eq 1 ] && [ "$has_end" -eq 1 ]; then
    awk -v begin="$marker_begin" -v end="$marker_end" -v block_file="$block_file" '
      BEGIN {
        while ((getline line < block_file) > 0) {
          block = block line ORS
        }
        close(block_file)
        in_block = 0
        replaced = 0
      }
      {
        if (!in_block && index($0, begin) > 0) {
          if (!replaced) {
            printf "%s", block
            replaced = 1
          }
          in_block = 1
          next
        }
        if (in_block) {
          if (index($0, end) > 0) {
            in_block = 0
          }
          next
        }
        print
      }
      END {
        if (!replaced) {
          if (NR > 0) {
            print ""
          }
          printf "%s", block
        }
      }
    ' "$target_file" > "$tmp_file"
  else
    cat "$target_file" > "$tmp_file"
    if [ -s "$tmp_file" ]; then
      printf '\n' >> "$tmp_file"
    fi
    cat "$block_file" >> "$tmp_file"
  fi

  local result=2
  if cmp -s "$target_file" "$tmp_file"; then
    result=0
  else
    mv "$tmp_file" "$target_file"
    result=2
  fi

  rm -f "$block_file" "$tmp_file" 2>/dev/null || true
  return "$result"
}
