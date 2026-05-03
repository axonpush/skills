#!/usr/bin/env bash
# env.sh — idempotently set KEY=VALUE pairs in .env.local (preferred) or .env.
# Usage: bash env.sh KEY1=val1 KEY2=val2 ...
#
# Behavior:
#   - Picks .env.local if it exists, else .env (creates it if missing).
#   - For each KEY=VALUE arg: replace existing `KEY=...` line, or append.
#   - Quotes values only if they contain whitespace or shell-special chars.
#   - Skips writing when nothing changed (preserves mtime).
#   - Prints "wrote N keys to <file>" to stderr.

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "env.sh: usage: env.sh KEY=value [KEY=value ...]" >&2
  exit 2
fi

# Pick target file in CWD.
if   [[ -f ".env.local" ]]; then file=".env.local"
elif [[ -f ".env"       ]]; then file=".env"
else
  file=".env"
  : > "$file"
fi

needs_quoting() {
  # Return 0 if value should be wrapped in double quotes.
  local v="$1"
  if [[ -z "$v" ]]; then
    return 0
  fi
  if [[ "$v" =~ [[:space:]\"\'\$\`\\\#] ]]; then
    return 0
  fi
  return 1
}

format_value() {
  local v="$1"
  if needs_quoting "$v"; then
    # Escape backslashes, double-quotes, backticks, and dollar signs.
    local esc="${v//\\/\\\\}"
    esc="${esc//\"/\\\"}"
    esc="${esc//\`/\\\`}"
    esc="${esc//\$/\\\$}"
    printf '"%s"' "$esc"
  else
    printf '%s' "$v"
  fi
}

# Read existing lines into an array (handles missing trailing newline).
declare -a lines=()
if [[ -s "$file" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    lines+=("$line")
  done < "$file"
fi

changed=0
written_count=0

for arg in "$@"; do
  if [[ "$arg" != *=* ]]; then
    echo "env.sh: skipping malformed arg (no '='): $arg" >&2
    continue
  fi
  key="${arg%%=*}"
  val="${arg#*=}"
  if [[ -z "$key" ]]; then
    echo "env.sh: skipping arg with empty key: $arg" >&2
    continue
  fi
  formatted=$(format_value "$val")
  new_line="${key}=${formatted}"

  # Search for an existing assignment.
  found_idx=-1
  for i in "${!lines[@]}"; do
    case "${lines[$i]}" in
      "${key}="*)
        found_idx=$i
        break
        ;;
    esac
  done

  if (( found_idx >= 0 )); then
    if [[ "${lines[found_idx]}" != "$new_line" ]]; then
      lines[found_idx]="$new_line"
      changed=1
    fi
  else
    lines+=("$new_line")
    changed=1
  fi
  written_count=$(( written_count + 1 ))
done

if (( changed )); then
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  if (( ${#lines[@]} > 0 )); then
    printf '%s\n' "${lines[@]}" > "$tmp"
  else
    : > "$tmp"
  fi
  mv "$tmp" "$file"
  trap - EXIT
fi

echo "wrote ${written_count} keys to ${file}" >&2
