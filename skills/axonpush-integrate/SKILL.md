---
name: axonpush-integrate
description: Wire the AxonPush observability SDK into the current project. Detects language and AI framework, browser-logs the user in (or reads creds from env), creates an app+channel, and delegates to the matching framework sub-skill (langchain, crewai, anthropic, openai-agents, vercel-ai, mastra, langgraph, llamaindex, google-adk, deepagents, otel, or custom). Use when the user asks to "set up axonpush", "add tracing", "integrate axonpush", or runs the axonpush-integrate skill.
---

# AxonPush Integration Orchestrator

You are integrating the AxonPush observability SDK into the user's project. Follow the seven steps below in order. Do not skip steps. Do not invent flags or arguments not listed here. All paths are relative to the project root (the directory the user invoked you from) unless otherwise stated.

When you need user input, phrase it as a plain question and list the options. The host UI will pick the best widget it has (button picker, chat prompt, etc.).

## Prereq Preamble

Before step 1, run this once:

```bash
command -v curl >/dev/null || { echo "curl is required. Install it first."; exit 1; }
command -v jq >/dev/null || { echo "jq is required. Install: brew install jq / apt install jq"; exit 1; }
```

If either fails, stop. Tell the user what to install and exit.

## Step 1 — Detect

Run:

```bash
bash skills/axonpush-integrate/helpers/detect.sh
```

It prints a single JSON object on stdout with shape:

```json
{"language": "python|typescript|both|unknown",
 "packageManager": "uv|poetry|pip|pnpm|bun|npm|yarn|unknown",
 "frameworks": ["langchain", "anthropic", ...],
 "logLibraries": ["loguru", "pino", ...]}
```

Parse it with `jq`. Hold these values for the rest of the procedure.

If `language == "both"`, ask the user: "Both Python and TypeScript detected. Which SDK do you want to integrate? Options: python, typescript."

If `language == "unknown"`, ask the user: "Could not detect project language. Which SDK? Options: python, typescript."

## Step 2 — Pick Integrations (multi-select)

A project usually wants more than one integration: an agent framework AND a log forwarder, or multiple agent frameworks side by side, or just logging without any agent framework. This step builds a list of sub-skills to invoke; **the user can pick as many as apply.**

Two integration families:

**A) Agent-framework integrations** — instrument LLM calls, agent runs, tool invocations.

| Detected key | Python sub-skill | TypeScript sub-skill |
|---|---|---|
| `anthropic` | `anthropic` | `ts-anthropic` |
| `crewai` | `crewai` | — |
| `langchain` | `langchain` | `ts-langchain` |
| `langgraph` | — | `ts-langgraph` |
| `llamaindex` | — | `ts-llamaindex` |
| `mastra` | — | `ts-mastra` |
| `openai-agents` | `openai-agents` | `ts-openai-agents` |
| `vercel-ai` | — | `ts-vercel-ai` |
| `google-adk` | — | `ts-google-adk` |
| `deepagents` | `deepagents` | — |
| `otel` (OpenTelemetry) | `otel-python` | `otel-ts` |
| (none of the above, raw event publish) | `custom` | `ts-custom` |

**B) Log-forwarder integrations** — funnel existing log calls into AxonPush as `eventType: "log"` events.

| Detected log lib | Sub-skill |
|---|---|
| Python `logging` (stdlib, also covers Django) | `logging` |
| Python `loguru` | `loguru` |
| Python `structlog` | `structlog` |
| Node `pino` | `pino` |
| Node `winston` | `winston` |
| Node `console` (fallback when no other lib) | `console` |

Behaviour:

1. Build `RECOMMENDED[]` from `detect.sh` output:
   - For each entry in `frameworks[]`, look up the matching agent sub-skill for `language`.
   - For each entry in `logLibraries[]`, look up the matching log sub-skill.
   - Drop any unmapped (e.g. `console` is only in TS, `logging` only in Python).
2. Show the user the recommended list and the full menu of unmapped options. Ask: **"Which integrations should I wire up? Pick all that apply."** Default-select the recommended ones.
3. If the user picks none and `frameworks[]` was empty, default to `custom` (Python) or `ts-custom` (TypeScript) so they at least get raw event publishing.

Hold the user's selection as `INTEGRATIONS=()` (bash-style array of sub-skill names). Order: agent frameworks first, log forwarders last (so the project boots logging after the agent client exists).

## Step 3 — Resolve Credentials

First check the environment:

```bash
[ -n "${AXONPUSH_API_KEY:-}" ] && [ -n "${AXONPUSH_TENANT_ID:-}" ] && echo "creds-from-env"
```

If both are set, hold them as `API_KEY` and `TENANT_ID` and skip to step 4.

Otherwise ask the user: "How do you want to authenticate with AxonPush? Options: Sign in via browser (recommended), Paste API key manually, Skip — I'll configure selfhost or a custom base URL."

### 3a — Browser sign-in (default)

Run:

```bash
bash skills/axonpush-integrate/helpers/login.sh "${APP_URL:-https://app.axonpush.xyz}"
```

On success it prints JSON `{"api_key": "...", "tenant_id": "..."}` on stdout. Parse with `jq` into `API_KEY` and `TENANT_ID`.

If it exits non-zero (no listener available, browser can't open, timeout), tell the user the browser flow failed and fall through to 3b.

### 3b — Paste manually

Tell the user: "Get an API key at https://app.axonpush.xyz/settings/api-keys and paste it here."

Ask for `AXONPUSH_API_KEY`. Ask for `AXONPUSH_TENANT_ID` (default `1`). Hold both.

### 3c — Skip / selfhost

Ask the user for `AXONPUSH_BASE_URL` (e.g. `https://api.your-selfhost.com`). Hold it as `BASE_URL`. Then run 3b to get key + tenant against that base URL.

If the user picked the default flow, leave `BASE_URL` unset (the helper writes the production default in step 5).

## Step 4 — Pick or Create App + Channel

Export creds for the helper:

```bash
export AXONPUSH_API_KEY="$API_KEY"
export AXONPUSH_TENANT_ID="$TENANT_ID"
[ -n "${BASE_URL:-}" ] && export AXONPUSH_BASE_URL="$BASE_URL"
```

**Naming constraints (enforced by the backend, fail before you call):**

- Both app names and channel names must be **at least 5 characters**. Reject short names up front rather than letting the API return a 400.
- App names should be project-scoped (e.g. `acme-prod-api`, not `app1`). Channel names should describe what flows through them (`agent-events`, `app-logs`, `webhooks-in`).

### 4a — App

```bash
bash skills/axonpush-integrate/helpers/api.sh list-apps
```

Output is a JSON array of `{id, appId, name, ...}`.

- If empty, ask the user: "No AxonPush apps yet. Name the new app (min 5 chars)." Default suggestion: the project directory name (sanitize to lowercase + hyphens; pad if under 5 chars). Then run:
  ```bash
  bash skills/axonpush-integrate/helpers/api.sh create-app "<name>"
  ```
  Output is the new app object. Hold `id` as `APP_ID`.
- If non-empty, list app names and ask: "Which app should this project use? Options: <names>, or create a new one." If they pick existing, hold its `id` as `APP_ID`. If they pick "create new", run the create-app flow above.

### 4b — Channels (multi-channel: ask for all upfront)

Once `APP_ID` is held, fetch the app's existing channels:

```bash
bash skills/axonpush-integrate/helpers/api.sh list-app "$APP_ID"
```

Output is the full app object with `channels: [...]` populated.

Now decide which channels this project needs. **A project usually wants more than one channel** — common pattern: one per logical event stream so subscribers can filter cheaply. Suggest sensible defaults based on the integrations the user picked in step 2:

| Picked integrations | Suggested channel(s) |
|---|---|
| Any agent framework (langchain, crewai, anthropic, etc.) | `agent-events` |
| Any log forwarder (logging, loguru, pino, winston, console, structlog) | `app-logs` |
| `otel-python` / `otel-ts` | `otel-traces` |
| Webhooks/external events expected | `webhooks-in` |
| User explicitly wants just one | `default-channel` |

Behaviour:

1. From the suggestion table, build `SUGGESTED_CHANNELS=()` based on the user's `INTEGRATIONS[]` selection. De-duplicate.
2. Show the user the suggested list AND the channels that already exist on this app. Ask: **"Which channels should I create or reuse? Edit the list to add/remove. Each name must be at least 5 characters."**
3. For each channel in the user's final list:
   - If it already exists in `channels[]`, reuse its `id`.
   - Otherwise call:
     ```bash
     bash skills/axonpush-integrate/helpers/api.sh create-channel "<name>" "$APP_ID"
     ```
     Hold the new channel's `id`.
4. Build `CHANNEL_IDS=()` (the array of all channel ids the user picked) and `CHANNEL_NAMES=()` in matching order.
5. **Pick the primary channel**: if the user picked exactly one, that's it. If multiple, prefer (in order) `agent-events` → `default-channel` → first in the list. Hold as `PRIMARY_CHANNEL_ID` and `PRIMARY_CHANNEL_NAME`. The primary is what `AXONPUSH_CHANNEL_ID` in `.env` points to; sub-skills publish to it by default.

## Step 5 — Write `.env`

Write the credentials and channel ids idempotently. The primary channel id is what the SDK reads by default; the secondary `AXONPUSH_CHANNELS` map lets advanced code address other channels by name without hardcoding ids.

```bash
# Build the AXONPUSH_CHANNELS map: "name1:id1,name2:id2,..."
CHANNELS_MAP=""
for i in "${!CHANNEL_IDS[@]}"; do
  [[ -n "$CHANNELS_MAP" ]] && CHANNELS_MAP+=","
  CHANNELS_MAP+="${CHANNEL_NAMES[$i]}:${CHANNEL_IDS[$i]}"
done

bash skills/axonpush-integrate/helpers/env.sh \
  AXONPUSH_API_KEY="$API_KEY" \
  AXONPUSH_TENANT_ID="$TENANT_ID" \
  AXONPUSH_APP_ID="$APP_ID" \
  AXONPUSH_CHANNEL_ID="$PRIMARY_CHANNEL_ID" \
  AXONPUSH_CHANNELS="$CHANNELS_MAP" \
  AXONPUSH_BASE_URL="${BASE_URL:-https://api.axonpush.xyz}"
```

The helper appends missing keys and updates existing ones in place; it picks `.env.local` if present, otherwise `.env`. Do not write the file yourself.

If a `.gitignore` exists and does not already ignore `.env*`, append the relevant lines. Do not commit anything.

## Step 6 — Delegate to Each Sub-Skill in Order

Loop over `INTEGRATIONS[]` from step 2. Invoke each sub-skill once. On Claude Code that means using the Skill tool with the sub-skill's name. On other hosts, read `skills/<name>/SKILL.md` from the plugin install directory and follow its instructions against the user's project.

Pass this context into every sub-skill's execution (state it out loud at the top of each run):

- `language` (python or typescript)
- `packageManager` (from step 1)
- `logLibraries[]` (from step 1)
- `APP_ID`, `PRIMARY_CHANNEL_ID`, `PRIMARY_CHANNEL_NAME` (from step 4)
- `CHANNEL_IDS[]`, `CHANNEL_NAMES[]` for projects publishing to multiple channels
- The fact that `.env` is already written

If a sub-skill fails (e.g. requires a package not installable in the user's lockfile), report the failure, skip it, and continue with the rest. Don't abort the whole orchestrator.

## Step 7 — Verify with a real test event

After all sub-skills finish, prove the wiring end-to-end by **publishing a real test event via the API** and **reading it back** to confirm receipt. Do not just print a command for the user — run it yourself.

```bash
TEST_ID="skill-test-$(date +%s)"
bash skills/axonpush-integrate/helpers/api.sh publish-event \
  "$PRIMARY_CHANNEL_ID" \
  "$TEST_ID" \
  '{"ok": true, "source": "axonpush-integrate skill"}'
```

Capture the response. The publish should return a `2xx` and a JSON body with the event's stored shape.

Then poll for the event:

```bash
sleep 1
RECEIVED=$(bash skills/axonpush-integrate/helpers/api.sh list-events "$PRIMARY_CHANNEL_ID" 5 \
  | jq --arg id "$TEST_ID" '[.events[]? // .[]?] | map(select(.identifier == $id)) | length')
```

If `RECEIVED >= 1`: print "**Test event landed.** Channel `$PRIMARY_CHANNEL_NAME` received `$TEST_ID`." Then tell the user where to view it: `https://app.axonpush.xyz/apps/<appId>/channels/<channelName>`.

If `RECEIVED == 0`: try once more with `sleep 3` (backend ingest can take a moment under cold start). If still zero, surface this as a failure with the publish response body — likely a credential or quota issue, and the user needs to know now (not after they've shipped to prod).

Then offer the language-specific one-liner so the user can verify from their own code path:

**Python:**

```bash
python -c "import os; from axonpush import AxonPush; AxonPush().events.publish(channel_id=os.environ['AXONPUSH_CHANNEL_ID'], identifier='from-my-code', payload={'ok': True})"
```

**TypeScript (Node):**

```bash
node -e "import('@axonpush/sdk').then(({AxonPush}) => new AxonPush().events.publish({channelId: process.env.AXONPUSH_CHANNEL_ID, identifier: 'from-my-code', payload: {ok: true}}))"
```

**TypeScript (Bun):**

```bash
bun -e "import {AxonPush} from '@axonpush/sdk'; await new AxonPush().events.publish({channelId: process.env.AXONPUSH_CHANNEL_ID, identifier: 'from-my-code', payload: {ok: true}})"
```

End with a brief summary (3–5 bullets): which integrations were wired, which channels were created/reused, the test-event result, and what command the user should run next to exercise their real agent.

## Rules (non-negotiable)

These apply at every step. Violating them is a regression.

1. **Never hardcode API keys, tenant IDs, channel IDs, or base URLs in source files.** All credential reads go through environment variables loaded from `.env`.
2. **Never use a generic file-write tool to modify `.env`.** Always go through `helpers/env.sh` so the write is idempotent and key-merging.
3. **Always read a file before modifying it.** Never guess file contents; never overwrite without inspecting first.
4. **Do not remove or modify existing functionality.** Only add AxonPush integration code. Minimal diffs only.
5. **Add AxonPush imports at the top of the file** alongside other imports — not scattered mid-function.
6. **Create the AxonPush client as a module-level singleton**, not inside each function call.
7. **Centralize AxonPush configuration** in a dedicated module (e.g. `axonpush_config.py` for Python, `lib/axonpush.ts` for TS). Other modules import from that single source. Never scatter `os.environ['AXONPUSH_...']` lookups across files.
8. **Use `int(os.environ['AXONPUSH_CHANNEL_ID'])` (Python) or `Number(process.env.AXONPUSH_CHANNEL_ID)` (TS).** Never hardcode channel IDs.
9. **Use the detected package manager** from step 1 for installs (`uv add`, `poetry add`, `pip install`, `bun add`, `pnpm add`, `npm install`, `yarn add`). Do not switch the user's package manager.
10. **For async Python frameworks** (OpenAI Agents, async LangChain), use `AsyncAxonPush` with `async with AsyncAxonPush(...) as client:`.
11. **If a `TracerProvider` already exists** in the project (OTel users), attach `AxonPushSpanExporter` to that provider. Never register a second global provider.
12. **Prefer `BatchSpanProcessor`** over `SimpleSpanProcessor` in production OTel setups.
13. **Detect the existing logging library** (stdlib `logging`, `loguru`, `structlog`, Pino, Winston, console) and wire the matching AxonPush integration. Do not introduce a new logging library.
14. **Never commit secrets or any files.** This skill writes `.env` and source edits; it does not run `git add`, `git commit`, or `git push`. The orchestrator above this skill handles commits.
15. **If `.gitignore` is missing `.env*`, add it.** Never check creds into version control.
16. **Fail open.** If the user's environment is missing a prereq for an optional step (e.g. browser can't open), fall back gracefully — never block the integration.
17. **Be terse.** Only summarize at the end. Do not narrate every shell command.
18. **When unsure which file to modify**, search with the host's grep/glob equivalent for the agent/chain entry point. Do not guess paths.
