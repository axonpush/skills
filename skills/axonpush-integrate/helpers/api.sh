#!/usr/bin/env bash
# api.sh — thin AxonPush REST client.
# Usage:
#   bash api.sh list-apps
#   bash api.sh create-app <name>
#   bash api.sh list-app <appId>
#   bash api.sh create-channel <name> <appId>
#   bash api.sh publish-event <channelId> <identifier> <payloadJSON>
#   bash api.sh list-events <channelId> [limit]
#
# Reads from env:
#   AXONPUSH_API_KEY    (required)
#   AXONPUSH_TENANT_ID  (required)
#   AXONPUSH_BASE_URL   (default: https://api.axonpush.xyz)
#
# Auth headers (verified against the wizard's api-helper.ts and api-client.ts):
#   X-API-Key: <key>
#   x-tenant-id: <tenant>
#
# All commands print JSON to stdout. Errors go to stderr with non-zero exit.

set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
  echo "api.sh: 'curl' is required." >&2
  exit 127
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "api.sh: 'jq' is required. Install: brew install jq  |  apt-get install jq" >&2
  exit 127
fi

cmd="${1:-}"
shift || true

# Help / usage must work without creds.
case "$cmd" in
  ""|-h|--help|help)
    cat >&2 <<EOF
api.sh — AxonPush REST client.

Commands:
  list-apps
  create-app <name>                                      (name min 5 chars)
  list-app <appId>
  create-channel <name> <appId>                          (name min 5 chars)
  publish-event <channelId> <identifier> <payloadJSON>
  list-events <channelId> [limit]                        (default limit=10)

Env: AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL (default https://api.axonpush.xyz)
EOF
    [[ -z "$cmd" ]] && exit 2 || exit 0
    ;;
esac

: "${AXONPUSH_API_KEY:?api.sh: AXONPUSH_API_KEY is required}"
: "${AXONPUSH_TENANT_ID:?api.sh: AXONPUSH_TENANT_ID is required}"
BASE_URL="${AXONPUSH_BASE_URL:-https://api.axonpush.xyz}"

req() {
  # $1 method, $2 path, $3 (optional) JSON body
  local method="$1" path="$2" body="${3:-}"
  local url="${BASE_URL}${path}"
  local args=(
    -sS -L
    -X "$method"
    -H "X-API-Key: ${AXONPUSH_API_KEY}"
    -H "x-tenant-id: ${AXONPUSH_TENANT_ID}"
    -H "Content-Type: application/json"
    -w '\n__HTTP_STATUS__:%{http_code}'
  )
  if [[ -n "$body" ]]; then
    args+=( --data "$body" )
  fi
  local raw
  raw=$(curl "${args[@]}" "$url")
  local status="${raw##*__HTTP_STATUS__:}"
  local payload="${raw%$'\n'__HTTP_STATUS__:*}"
  if (( status < 200 || status >= 300 )); then
    echo "api.sh: ${method} ${path} failed (HTTP ${status})" >&2
    [[ -n "$payload" ]] && echo "$payload" >&2
    exit 1
  fi
  if [[ -z "$payload" ]]; then
    echo "{}"
  elif echo "$payload" | jq -e . >/dev/null 2>&1; then
    echo "$payload" | jq .
  else
    # Non-JSON success body — pass through verbatim.
    printf '%s\n' "$payload"
  fi
}

case "$cmd" in
  list-apps)
    req GET /apps
    ;;
  create-app)
    name="${1:-}"
    [[ -z "$name" ]] && { echo "api.sh: create-app <name>" >&2; exit 2; }
    if (( ${#name} < 5 )); then
      echo "api.sh: app name must be at least 5 characters (got ${#name}: '$name')" >&2
      exit 2
    fi
    req POST /apps "$(jq -n --arg name "$name" '{name: $name}')"
    ;;
  list-app)
    app_id="${1:-}"
    [[ -z "$app_id" ]] && { echo "api.sh: list-app <appId>" >&2; exit 2; }
    apps=$(req GET /apps)
    # App identifiers are UUID strings — match against both .id and .appId.
    match=$(echo "$apps" | jq --arg id "$app_id" 'map(select(.id == $id or .appId == $id)) | .[0] // empty')
    if [[ -z "$match" || "$match" == "null" ]]; then
      echo "api.sh: app not found: $app_id" >&2
      exit 1
    fi
    # GET /apps/<id> includes channels[]; fetch by .id (UUID) for accuracy.
    real_id=$(echo "$match" | jq -r '.id')
    req GET "/apps/${real_id}"
    ;;
  create-channel)
    name="${1:-}"; app_id="${2:-}"
    [[ -z "$name" || -z "$app_id" ]] && { echo "api.sh: create-channel <name> <appId>" >&2; exit 2; }
    if (( ${#name} < 5 )); then
      echo "api.sh: channel name must be at least 5 characters (got ${#name}: '$name')" >&2
      exit 2
    fi
    # Backend DTO requires appId as a string — use --arg, not --argjson.
    req POST /channel "$(jq -n --arg name "$name" --arg appId "$app_id" '{name: $name, appId: $appId}')"
    ;;
  publish-event)
    channel_id="${1:-}"; identifier="${2:-}"; payload="${3:-}"
    [[ -z "$channel_id" || -z "$identifier" || -z "$payload" ]] && {
      echo "api.sh: publish-event <channelId> <identifier> <payloadJSON>" >&2; exit 2;
    }
    # Sanity-check payload is valid JSON before sending.
    if ! echo "$payload" | jq -e . >/dev/null 2>&1; then
      echo "api.sh: payload must be valid JSON" >&2; exit 2;
    fi
    req POST /event "$(jq -n --arg id "$identifier" --arg ch "$channel_id" --argjson p "$payload" \
      '{identifier: $id, channel_id: $ch, payload: $p, eventType: "custom"}')"
    ;;
  list-events)
    channel_id="${1:-}"; limit="${2:-10}"
    [[ -z "$channel_id" ]] && { echo "api.sh: list-events <channelId> [limit]" >&2; exit 2; }
    req GET "/event/${channel_id}/list?limit=${limit}"
    ;;
  *)
    echo "api.sh: unknown command '$cmd'" >&2
    exit 2
    ;;
esac
