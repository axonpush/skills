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

## Step 2 — Confirm Framework

Use this lookup table to map detected frameworks to the sub-skill that will handle them:

**Python (`language == "python"`):**

| Framework key | Sub-skill name |
|---|---|
| `anthropic` | `anthropic` |
| `crewai` | `crewai` |
| `langchain` | `langchain` |
| `openai-agents` | `openai-agents` |
| `deepagents` | `deepagents` |
| `otel` | `otel-python` |
| (none / other) | `custom` |

**TypeScript (`language == "typescript"`):**

| Framework key | Sub-skill name |
|---|---|
| `anthropic` | `ts-anthropic` |
| `langchain` | `ts-langchain` |
| `langgraph` | `ts-langgraph` |
| `llamaindex` | `ts-llamaindex` |
| `mastra` | `ts-mastra` |
| `openai-agents` | `ts-openai-agents` |
| `vercel-ai` | `ts-vercel-ai` |
| `google-adk` | `ts-google-adk` |
| `otel` | `otel-ts` |
| (none / other) | `ts-custom` |

Behaviour:

- If `frameworks[]` has exactly one entry, ask the user: "Detected `<framework>`. Integrate AxonPush with this framework? Options: yes, pick a different one."
- If `frameworks[]` has multiple entries, ask: "Multiple frameworks detected. Which one to integrate? Options: <list of detected frameworks>, other."
- If `frameworks[]` is empty, ask: "No supported framework detected. Pick one to integrate, or use `custom` for direct event publishing. Options: <full list of framework keys for the chosen language>."

Resolve the user's choice to a sub-skill name via the table. Hold this as `SUB_SKILL`.

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

### 4a — App

```bash
bash skills/axonpush-integrate/helpers/api.sh list-apps
```

Output is a JSON array of `{id, name, channels: [...]}`.

- If empty, ask the user: "No AxonPush apps yet. What should the new app be called?" Default to the project directory name. Then run:
  ```bash
  bash skills/axonpush-integrate/helpers/api.sh create-app "<name>"
  ```
  Output is the new app object. Hold `id` as `APP_ID`.
- If non-empty, list app names and ask: "Which app should this project use? Options: <names>, create a new one." If they pick existing, hold its `id` as `APP_ID`. If they pick "create new", run the create-app flow above.

### 4b — Channel

Once `APP_ID` is held, list channels:

```bash
bash skills/axonpush-integrate/helpers/api.sh list-app "$APP_ID"
```

Output includes `channels: [...]` for that app.

- If empty, ask: "No channels yet for `<app name>`. What should the new channel be called?" Default `default`. Then:
  ```bash
  bash skills/axonpush-integrate/helpers/api.sh create-channel "<name>" "$APP_ID"
  ```
  Hold the new channel's `id` as `CHANNEL_ID`.
- If non-empty, ask: "Which channel? Options: <channel names>, create a new one." Hold the chosen `id` as `CHANNEL_ID`, or create.

## Step 5 — Write `.env`

Write all five values idempotently:

```bash
bash skills/axonpush-integrate/helpers/env.sh \
  AXONPUSH_API_KEY="$API_KEY" \
  AXONPUSH_TENANT_ID="$TENANT_ID" \
  AXONPUSH_APP_ID="$APP_ID" \
  AXONPUSH_CHANNEL_ID="$CHANNEL_ID" \
  AXONPUSH_BASE_URL="${BASE_URL:-https://api.axonpush.xyz}"
```

The helper appends missing keys and updates existing ones in place; it picks `.env.local` if present, otherwise `.env`. Do not write the file yourself.

If a `.gitignore` exists and does not already ignore `.env*`, append the relevant lines. Do not commit anything.

## Step 6 — Delegate to the Framework Sub-Skill

Invoke `SUB_SKILL` (resolved in step 2). On Claude Code that means using the Skill tool with the sub-skill's name. On other hosts, read the file `skills/<SUB_SKILL>/SKILL.md` from the plugin install directory and follow its instructions verbatim against the user's project.

Pass the following context into the sub-skill's execution (state them out loud at the top of its run so the model can use them):

- `language` (python or typescript)
- `packageManager` (from step 1)
- `logLibraries[]` (from step 1)
- `APP_ID`, `CHANNEL_ID` (from step 4)
- The fact that `.env` is already written (no need to re-prompt for creds)

Do not duplicate work the sub-skill will do (package install, code edits). Your job ends once the sub-skill completes.

## Step 7 — Verify

After the sub-skill returns, print a one-liner the user can run to emit a test event. Pick by language:

**Python:**

```bash
python -c "import os; from axonpush import AxonPush; AxonPush(api_key=os.environ['AXONPUSH_API_KEY'], tenant_id=os.environ['AXONPUSH_TENANT_ID']).events.publish(channel_id=int(os.environ['AXONPUSH_CHANNEL_ID']), identifier='test', payload={'ok': True})"
```

**TypeScript (Node):**

```bash
node -e "import('@axonpush/sdk').then(({AxonPush}) => new AxonPush({apiKey: process.env.AXONPUSH_API_KEY, tenantId: process.env.AXONPUSH_TENANT_ID}).events.publish({channelId: Number(process.env.AXONPUSH_CHANNEL_ID), identifier: 'test', payload: {ok: true}}))"
```

**TypeScript (Bun):**

```bash
bun -e "import {AxonPush} from '@axonpush/sdk'; await new AxonPush({apiKey: process.env.AXONPUSH_API_KEY, tenantId: process.env.AXONPUSH_TENANT_ID}).events.publish({channelId: Number(process.env.AXONPUSH_CHANNEL_ID), identifier: 'test', payload: {ok: true}})"
```

Tell the user: "Run the above (after sourcing your `.env`), then watch https://app.axonpush.xyz for the `test` event on channel `<channel name>`. Then run your real agent and confirm traces appear."

End with a brief summary (3–5 bullets) of what was changed and what to do next.

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
