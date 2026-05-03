#!/usr/bin/env bash
# login.sh — browser-based AxonPush authentication.
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

# ---- start listener (background) -------------------------------------------
LISTENER_PID=""
start_python_listener() {
  python3 - "$PORT" "$RESULT_FILE" <<'PY' &
import json, socket, sys, urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(sys.argv[1])
out_path = sys.argv[2]

OK_HTML = b"<html><body><h2>Authenticated! You can close this tab.</h2></body></html>"
WAIT_HTML = b"<html><body><h2>Waiting for authentication...</h2></body></html>"
ERR_HTML = b"<html><body><h2>Missing credentials. Please try again.</h2></body></html>"

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
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                self.wfile.write(OK_HTML)
                with open(out_path, "w") as f:
                    json.dump({"api_key": api_key, "tenant_id": tenant_id}, f)
                # Schedule shutdown after this request completes.
                import threading
                threading.Thread(target=self.server.shutdown, daemon=True).start()
                return
            self.send_response(400)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(ERR_HTML)
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
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
      req=$( { echo -e 'HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n<html><body><h2>Waiting...</h2></body></html>'; } \
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
            { echo -e 'HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n<html><body><h2>Authenticated! You can close this tab.</h2></body></html>'; } \
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
