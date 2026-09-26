#!/usr/bin/env bash
# detect.sh — detect language, package manager, AI frameworks, log libraries,
# raw provider clients (gateway candidates), and error-tracking SDKs.
# Usage: bash detect.sh [dir]
# Outputs JSON to stdout:
#   { "language": "...", "packageManager": "...", "frameworks": [...],
#     "logLibraries": [...], "providers": [...], "errorTracking": [...] }

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

# Parse pyproject.toml with Python's stdlib `tomllib` (3.11+) — proper TOML,
# covering [project] deps, optional-dependencies, PEP 735 [dependency-groups],
# and poetry. Prints one lowercase base package name per line.
read_py_deps_tomllib() {
  python3 - "$1/pyproject.toml" <<'PY'
import re, sys, tomllib

with open(sys.argv[1], "rb") as fh:
    data = tomllib.load(fh)

names: list[str] = []

def add(spec) -> None:
    if not isinstance(spec, str):
        return
    m = re.match(r"[A-Za-z0-9][A-Za-z0-9._-]*", spec.strip())
    if m:
        names.append(m.group(0).lower())

project = data.get("project", {})
for dep in project.get("dependencies", []) or []:
    add(dep)
for group in (project.get("optional-dependencies", {}) or {}).values():
    for dep in group or []:
        add(dep)
for group in (data.get("dependency-groups", {}) or {}).values():
    for dep in group or []:
        add(dep)

poetry = data.get("tool", {}).get("poetry", {})
for section in ("dependencies", "dev-dependencies"):
    for name in poetry.get(section, {}) or {}:
        add(name)
for group in (poetry.get("group", {}) or {}).values():
    for name in (group.get("dependencies", {}) or {}):
        add(name)

for name in names:
    print(name)
PY
}

read_py_deps() {
  local d="$1"
  if [[ -f "$d/pyproject.toml" ]]; then
    if command -v python3 >/dev/null 2>&1 && python3 -c 'import tomllib' 2>/dev/null; then
      read_py_deps_tomllib "$d" 2>/dev/null || true
    else
      # Fallback when tomllib is unavailable: loose token extraction.
      grep -oE '"[A-Za-z0-9][A-Za-z0-9._-]*' "$d/pyproject.toml" \
        | tr -d '"' | tr '[:upper:]' '[:lower:]' || true
    fi
  fi
  if [[ -f "$d/requirements.txt" ]]; then
    sed -E 's/#.*$//; s/[[:space:]]+$//' "$d/requirements.txt" \
      | grep -v '^[[:space:]]*$' \
      | grep -v '^[[:space:]]*-' \
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

# ---- provider client detection (gateway candidates) -------------------------
# Raw provider SDKs whose base_url can be pointed at the axonpush gateway with
# no in-process instrumentation. These drive the "gateway" recommendation.
declare -a providers=()
if [[ "$language" == "python" || "$language" == "both" ]]; then
  py_match "openai"        && providers+=("openai")
  py_match "anthropic"     && providers+=("anthropic")
  py_match "litellm"       && providers+=("litellm")
  { py_match "google-genai" || py_match "google-generativeai"; } && providers+=("google")
  py_match "mistralai"     && providers+=("mistral")
  py_match "cohere"        && providers+=("cohere")
fi
if [[ "$language" == "typescript" || "$language" == "both" ]]; then
  ts_match "openai"                          && providers+=("openai")
  ts_match "@anthropic-ai/sdk"               && providers+=("anthropic")
  ts_match "@azure/openai"                   && providers+=("azure-openai")
  ts_match "@aws-sdk/client-bedrock-runtime" && providers+=("bedrock")
  { ts_match "@google/genai" || ts_match "@google/generative-ai"; } && providers+=("google")
  ts_match "@mistralai/mistralai"            && providers+=("mistral")
  ts_match "cohere-ai"                       && providers+=("cohere")
fi
if (( ${#providers[@]} > 0 )); then
  providers_json=$(printf '%s\n' "${providers[@]}" | awk '!seen[$0]++' | jq -R . | jq -s .)
else
  providers_json='[]'
fi

# ---- error-tracking detection (Sentry pillar) -------------------------------
declare -a error_tracking=()
if [[ "$language" == "python" || "$language" == "both" ]]; then
  py_match "sentry-sdk" && error_tracking+=("sentry")
fi
if [[ "$language" == "typescript" || "$language" == "both" ]]; then
  ts_match_prefix "@sentry/" && error_tracking+=("sentry")
fi
if (( ${#error_tracking[@]} > 0 )); then
  error_tracking_json=$(printf '%s\n' "${error_tracking[@]}" | awk '!seen[$0]++' | jq -R . | jq -s .)
else
  error_tracking_json='[]'
fi

# ---- emit JSON --------------------------------------------------------------
jq -n \
  --arg language "$language" \
  --arg packageManager "$packageManager" \
  --argjson frameworks "$frameworks_json" \
  --argjson logLibraries "$log_libs_json" \
  --argjson providers "$providers_json" \
  --argjson errorTracking "$error_tracking_json" \
  '{language: $language, packageManager: $packageManager, frameworks: $frameworks, logLibraries: $logLibraries, providers: $providers, errorTracking: $errorTracking}'
