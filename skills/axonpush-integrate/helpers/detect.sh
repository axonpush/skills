#!/usr/bin/env bash
# detect.sh — detect language, package manager, AI frameworks, and log libraries.
# Usage: bash detect.sh [dir]
# Outputs JSON to stdout:
#   { "language": "...", "packageManager": "...", "frameworks": [...], "logLibraries": [...] }

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "detect.sh: 'jq' is required. Install: brew install jq  |  apt-get install jq" >&2
  exit 127
fi

dir="${1:-.}"
if [[ ! -d "$dir" ]]; then
  echo "detect.sh: directory not found: $dir" >&2
  exit 2
fi

# ---- language ---------------------------------------------------------------
has_python=0
has_ts=0
[[ -f "$dir/pyproject.toml" || -f "$dir/requirements.txt" ]] && has_python=1
[[ -f "$dir/package.json" ]] && has_ts=1

if (( has_python && has_ts )); then
  language="both"
elif (( has_ts )); then
  language="typescript"
elif (( has_python )); then
  language="python"
else
  # Default to python when nothing detected (matches wizard's fallback path).
  language="python"
fi

# ---- package manager --------------------------------------------------------
# When language is "both", prefer TS package manager (orchestrator can override).
pm_lang="$language"
[[ "$pm_lang" == "both" ]] && pm_lang="typescript"

if [[ "$pm_lang" == "typescript" ]]; then
  if   [[ -f "$dir/bun.lock"      || -f "$dir/bun.lockb" ]]; then packageManager="bun"
  elif [[ -f "$dir/pnpm-lock.yaml" ]];                            then packageManager="pnpm"
  elif [[ -f "$dir/yarn.lock"      ]];                            then packageManager="yarn"
  else                                                                packageManager="npm"
  fi
else
  if   [[ -f "$dir/uv.lock"     ]]; then packageManager="uv"
  elif [[ -f "$dir/poetry.lock" ]]; then packageManager="poetry"
  else                                   packageManager="pip"
  fi
fi

# ---- read dependency names --------------------------------------------------
# We collect lowercase package names into newline-separated lists in temp files,
# then ask jq to dedupe + match.

py_deps_file=$(mktemp); ts_deps_file=$(mktemp)
trap 'rm -f "$py_deps_file" "$ts_deps_file"' EXIT

read_py_deps() {
  local d="$1"
  # pyproject.toml — grab [project] dependencies via a tolerant grep.
  if [[ -f "$d/pyproject.toml" ]]; then
    awk '
      /^\[project\]/                  { in_proj=1; next }
      /^\[/                           { in_proj=0; in_deps=0 }
      in_proj && /^[[:space:]]*dependencies[[:space:]]*=[[:space:]]*\[/ { in_deps=1; next }
      in_deps && /\]/                 { in_deps=0; next }
      in_deps                         { print }
      # Also catch [project.optional-dependencies.*] groups loosely.
      /^\[project\.optional-dependencies/ { in_opt=1; next }
      /^\[/                           { in_opt=0 }
      in_opt && /=[[:space:]]*\[/     { in_opt_arr=1; next }
      in_opt_arr && /\]/              { in_opt_arr=0; next }
      in_opt_arr                      { print }
    ' "$d/pyproject.toml" \
      | sed -E 's/^[[:space:]]*"([^"]+)".*$/\1/; s/^[[:space:]]*'\''([^'\'']+)'\''.*$/\1/' \
      | sed -E 's/[][><=!~;].*$//; s/[[:space:]]+$//' \
      | tr '[:upper:]' '[:lower:]' \
      | grep -E '^[a-z0-9][a-z0-9._-]*' \
      || true
  fi
  if [[ -f "$d/requirements.txt" ]]; then
    sed -E 's/#.*$//; s/[[:space:]]+$//' "$d/requirements.txt" \
      | grep -v '^[[:space:]]*$' \
      | sed -E 's/[][><=!~;].*$//' \
      | tr '[:upper:]' '[:lower:]' \
      | grep -E '^[a-z0-9][a-z0-9._-]*' \
      || true
  fi
}

read_ts_deps() {
  local d="$1"
  if [[ -f "$d/package.json" ]]; then
    jq -r '
      ((.dependencies // {}) + (.devDependencies // {}) + (.peerDependencies // {}) + (.optionalDependencies // {}))
      | keys[]
    ' "$d/package.json" 2>/dev/null || true
  fi
}

read_py_deps "$dir" | sort -u > "$py_deps_file"
read_ts_deps "$dir" | sort -u > "$ts_deps_file"

# ---- framework detection ----------------------------------------------------
# Match against the dependency list. Prefix matches use grep -E patterns.
frameworks_json='[]'

py_match() {
  # $1 = exact package name (lowercase)
  grep -Fxq -- "$1" "$py_deps_file"
}
py_match_prefix() {
  # $1 = prefix (lowercase)
  grep -Eq "^${1}" "$py_deps_file"
}
ts_match() {
  grep -Fxq -- "$1" "$ts_deps_file"
}
ts_match_prefix() {
  grep -Eq "^${1}" "$ts_deps_file"
}

declare -a frameworks=()

if [[ "$language" == "python" || "$language" == "both" ]]; then
  py_match "anthropic"        && frameworks+=("anthropic")
  py_match "crewai"           && frameworks+=("crewai")
  { py_match_prefix "langchain" || py_match "langgraph"; } && frameworks+=("langchain")
  py_match "openai-agents"    && frameworks+=("openai-agents")
  py_match "deepagents"       && frameworks+=("deepagents")
  py_match_prefix "opentelemetry-" && frameworks+=("otel")
fi

if [[ "$language" == "typescript" || "$language" == "both" ]]; then
  ts_match "@anthropic-ai/sdk"          && frameworks+=("ts-anthropic")
  { ts_match "langchain" || ts_match_prefix "@langchain/"; } && frameworks+=("ts-langchain")
  ts_match "@langchain/langgraph"       && frameworks+=("ts-langgraph")
  ts_match "llamaindex"                 && frameworks+=("ts-llamaindex")
  ts_match "@mastra/core"               && frameworks+=("ts-mastra")
  ts_match "@openai/agents"             && frameworks+=("ts-openai-agents")
  ts_match "ai"                         && frameworks+=("ts-vercel-ai")
  { ts_match "@google/genai" || ts_match "@google/generative-ai"; } && frameworks+=("ts-google-adk")
  ts_match_prefix "@opentelemetry/"     && frameworks+=("otel-ts")
fi

# Dedupe while preserving order.
if (( ${#frameworks[@]} > 0 )); then
  frameworks_json=$(printf '%s\n' "${frameworks[@]}" | awk '!seen[$0]++' | jq -R . | jq -s .)
fi

# ---- log library detection --------------------------------------------------
declare -a log_libs=()
if [[ "$language" == "typescript" ]]; then
  ts_match "pino"    && log_libs+=("pino")
  ts_match "winston" && log_libs+=("winston")
  ts_match "bunyan"  && log_libs+=("bunyan")
  log_libs+=("console")
else
  # python (or both — orchestrator decides; default to python log libs)
  py_match "loguru"   && log_libs+=("loguru")
  py_match "structlog" && log_libs+=("structlog")
  log_libs+=("logging")
  log_libs+=("print")
fi

log_libs_json=$(printf '%s\n' "${log_libs[@]}" | jq -R . | jq -s .)

# ---- emit JSON --------------------------------------------------------------
jq -n \
  --arg language "$language" \
  --arg packageManager "$packageManager" \
  --argjson frameworks "$frameworks_json" \
  --argjson logLibraries "$log_libs_json" \
  '{language: $language, packageManager: $packageManager, frameworks: $frameworks, logLibraries: $logLibraries}'
