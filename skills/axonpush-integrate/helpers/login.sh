#!/usr/bin/env bash
# login.sh: browser-based axonpush authentication.
# Usage: bash login.sh [app_url]   (default: https://app.axonpush.xyz)
#
# Picks a free port on 127.0.0.1, opens ${app_url}/wizard-auth?port=$PORT in
# the user's browser, and waits up to 120s for a callback to
#   /callback?api_key=...&tenant_id=...
# On success prints {"api_key": "...", "tenant_id": "..."} to stdout.
#
# Exit codes:
#   0  success
#   1  timeout / missing fields
#   2  no listener tool available (python3 and nc both missing)

set -euo pipefail

APP_URL="${1:-https://app.axonpush.xyz}"
TIMEOUT=120

# ---- prereq probe -----------------------------------------------------------
have_python=0; have_nc=0
command -v python3 >/dev/null 2>&1 && have_python=1
command -v nc      >/dev/null 2>&1 && have_nc=1
if (( have_python == 0 && have_nc == 0 )); then
  echo "login.sh: neither 'python3' nor 'nc' found; cannot run callback listener." >&2
  exit 2
fi

# ---- pick a free port -------------------------------------------------------
pick_port() {
  if (( have_python )); then
    python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
  else
    # Fallback: try random ports until one binds.
    local p
    for _ in $(seq 1 50); do
      p=$(( (RANDOM % 20000) + 30000 ))
      if ! (echo > "/dev/tcp/127.0.0.1/$p") >/dev/null 2>&1; then
        echo "$p"; return 0
      fi
    done
    echo "login.sh: could not find a free port" >&2
    exit 1
  fi
}

PORT=$(pick_port)
AUTH_URL="${APP_URL}/wizard-auth?port=${PORT}"
RESULT_FILE=$(mktemp)
trap 'rm -f "$RESULT_FILE"' EXIT

# ---- callback pages ------------------------------------------------------------
# page <state> <title> <message>: a small self-contained page (no external
# assets) in the dashboard's monochrome style, light or dark per the OS.
# state is ok | wait | error.
page() {
  local state=$1 title=$2 message=$3 mark
  case "$state" in
    ok)    mark='<path d="M5 12.5l4.5 4.5L19 7.5"/>' ;;
    error) mark='<path d="M12 7v6"/><path d="M12 16.5v.5"/>' ;;
    *)     mark='<circle cx="12" cy="12" r="7" class="spin"/>' ;;
  esac
  cat <<HTML
<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title} · axonpush</title>
<style>
:root{--bg:#fafafa;--card:#fff;--fg:#1c1c1c;--muted:#6b6b6b;--border:rgba(0,0,0,.09);--ok:#16a34a;--err:#dc2626;color-scheme:light dark}
@media (prefers-color-scheme:dark){:root{--bg:#0d0d0d;--card:#161616;--fg:#ededed;--muted:#a3a3a3;--border:rgba(255,255,255,.09);--ok:#4ade80;--err:#f87171}}
*{box-sizing:border-box}html,body{height:100%}
body{margin:0;display:grid;place-items:center;padding:16px;background:var(--bg);color:var(--fg);font:15px/1.5 ui-sans-serif,system-ui,-apple-system,"Segoe UI",sans-serif}
main{width:100%;max-width:400px;padding:32px;border:1px solid var(--border);border-radius:24px;background:var(--card);text-align:center}
.word{margin:0 0 28px;font:600 13px/1 ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.18em;text-transform:lowercase;color:var(--muted)}
.mark{display:inline-grid;place-items:center;width:48px;height:48px;margin-bottom:16px;border:1px solid var(--border);border-radius:14px}
.mark svg{width:24px;height:24px;fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round}
.ok .mark svg{stroke:var(--ok)}.error .mark svg{stroke:var(--err)}.wait .mark svg{stroke:var(--muted)}
.spin{stroke-dasharray:30 14;transform-origin:center;animation:spin 1s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}
@media (prefers-reduced-motion:reduce){.spin{animation:none}}
h1{margin:0 0 6px;font-size:18px;font-weight:600;letter-spacing:-.01em}
p{margin:0;color:var(--muted)}
</style></head><body class="${state}"><main>
<p class="word">axonpush</p>
<div class="mark" aria-hidden="true"><svg viewBox="0 0 24 24">${mark}</svg></div>
<h1>${title}</h1>
<p>${message}</p>
</main></body></html>
HTML
}

export AXONPUSH_OK_HTML AXONPUSH_WAIT_HTML AXONPUSH_ERR_HTML
AXONPUSH_OK_HTML=$(page ok "You're signed in" "Your terminal has what it needs. You can close this tab and return to it.")
AXONPUSH_WAIT_HTML=$(page wait "Waiting for sign-in" "Finish signing in to axonpush in the other tab. This page isn't needed.")
AXONPUSH_ERR_HTML=$(page error "That didn't finish" "No credentials arrived. Run the login again from your terminal.")

# ---- start listener (background) -------------------------------------------
LISTENER_PID=""
start_python_listener() {
  python3 - "$PORT" "$RESULT_FILE" <<'PY' &
import json, os, socket, sys, urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(sys.argv[1])
out_path = sys.argv[2]

OK_HTML = os.environ["AXONPUSH_OK_HTML"].encode()
WAIT_HTML = os.environ["AXONPUSH_WAIT_HTML"].encode()
ERR_HTML = os.environ["AXONPUSH_ERR_HTML"].encode()

class H(BaseHTTPRequestHandler):
    def log_message(self, *a, **kw):
        pass
    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if u.path == "/callback":
            q = urllib.parse.parse_qs(u.query)
            api_key = (q.get("api_key") or [""])[0]
            tenant_id = (q.get("tenant_id") or [""])[0]
            if api_key and tenant_id:
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(OK_HTML)
                with open(out_path, "w") as f:
                    json.dump({"api_key": api_key, "tenant_id": tenant_id}, f)
                # Schedule shutdown after this request completes.
                import threading
                threading.Thread(target=self.server.shutdown, daemon=True).start()
                return
            self.send_response(400)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(ERR_HTML)
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(WAIT_HTML)

srv = HTTPServer(("127.0.0.1", port), H)
srv.serve_forever()
PY
  LISTENER_PID=$!
}

start_nc_listener() {
  # Loop accepting connections; on each request, parse the GET line, write
  # response, and stop once we capture credentials.
  (
    while :; do
      req=$( { printf 'HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n%s' "$AXONPUSH_WAIT_HTML"; } \
        | nc -l -p "$PORT" -q 1 2>/dev/null | head -n 1 || true)
      [[ -z "$req" ]] && continue
      # req looks like: GET /callback?api_key=X&tenant_id=Y HTTP/1.1
      path=$(echo "$req" | awk '{print $2}')
      case "$path" in
        /callback*)
          query="${path#*\?}"
          api_key=""; tenant_id=""
          IFS='&' read -ra parts <<< "$query"
          for kv in "${parts[@]}"; do
            k="${kv%%=*}"; v="${kv#*=}"
            # urldecode minimal
            v=$(printf '%b' "${v//%/\\x}")
            [[ "$k" == "api_key"   ]] && api_key="$v"
            [[ "$k" == "tenant_id" ]] && tenant_id="$v"
          done
          if [[ -n "$api_key" && -n "$tenant_id" ]]; then
            printf '{"api_key":"%s","tenant_id":"%s"}' "$api_key" "$tenant_id" > "$RESULT_FILE"
            # Send a final 200 to a fresh connection then exit.
            { printf 'HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n%s' "$AXONPUSH_OK_HTML"; } \
              | nc -l -p "$PORT" -q 1 >/dev/null 2>&1 || true
            exit 0
          fi
          ;;
      esac
    done
  ) &
  LISTENER_PID=$!
}

if (( have_python )); then
  start_python_listener
else
  start_nc_listener
fi

# shellcheck disable=SC2317  # invoked via `trap`
# shellcheck disable=SC2329 # invoked via trap
cleanup() {
  if [[ -n "$LISTENER_PID" ]] && kill -0 "$LISTENER_PID" 2>/dev/null; then
    kill "$LISTENER_PID" 2>/dev/null || true
  fi
  rm -f "$RESULT_FILE"
}
trap cleanup EXIT INT TERM

# ---- open browser -----------------------------------------------------------
opener=""
if   command -v xdg-open >/dev/null 2>&1; then opener="xdg-open"
elif command -v open     >/dev/null 2>&1; then opener="open"
elif command -v start    >/dev/null 2>&1; then opener="start"
fi

if [[ -n "$opener" ]]; then
  ( "$opener" "$AUTH_URL" >/dev/null 2>&1 & ) || true
  echo "login.sh: opened $AUTH_URL in browser; waiting for callback..." >&2
else
  echo "login.sh: no browser opener found. Please open this URL manually:" >&2
  echo "  $AUTH_URL" >&2
fi

# ---- wait for callback ------------------------------------------------------
elapsed=0
while (( elapsed < TIMEOUT )); do
  if [[ -s "$RESULT_FILE" ]]; then
    cat "$RESULT_FILE"
    echo
    exit 0
  fi
  sleep 1
  elapsed=$(( elapsed + 1 ))
done

echo "login.sh: timed out after ${TIMEOUT}s waiting for browser authentication." >&2
exit 1
