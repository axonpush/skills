# Changelog

All notable changes to this plugin are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [SemVer](https://semver.org/).

## [0.0.5] – 2026-09-16

### Added

- New `gateway` sub-skill: the zero-instrumentation path. It routes a
  project's OpenAI or Anthropic traffic through the axonpush gateway
  (`/gw/openai` or `/gw/anthropic`) by changing one `base_url` and adding
  an `x-axonpush-api-key` header. No SDK, callback handler, or framework
  wrapper is added. Every call, including tool calls and agent handoffs,
  is captured as a queryable span. Ships Python and TypeScript reference
  snippets for both the OpenAI and Anthropic SDKs.
- `axonpush-integrate` orchestrator now treats the gateway as a first
  integration family and recommends it ahead of framework sub-skills when
  a provider client (or a framework that exposes the provider `base_url`)
  is detected. Step 2 recommendation and default-selection logic, and
  Step 6 delegation, updated to pass the gateway sub-skill the provider
  and `AXONPUSH_API_KEY` instead of channel ids.

### Changed

- Repositioning across the README and orchestrator: axonpush is agent
  observability plus control with zero instrumentation. The docs now lead
  with the gateway and document the capabilities it unlocks: tool-call and
  handoff observability (spans with tool name, arguments, outcome;
  analytics by agent and by tool; agent, tool, and semantic-kind filters),
  inline moderation and enforcement (block, redact, or flag on the
  request, the response, or a specific tool call, before it executes),
  hard per-key and per-app cost caps that block pre-spend, and an
  immutable, queryable audit trail shaped for DORA, EU AI Act, and
  SR 11-7 reviews. Moderation rules and cost caps are noted as
  dashboard-authored, not wired by these skills.

## [0.0.4] – 2026-05-04

### Changed

- Renamed the marketplace from `axonpush` to `axonpush-plugins`. The
  marketplace and the plugin it lists used to share the same name,
  which made the install command read `/plugin install axonpush@axonpush`
  — technically valid, visually confusing, and bit awkward if/when a
  second plugin lands in the same catalog. The install command now
  reads `/plugin install axonpush@axonpush-plugins`. `/plugin
  marketplace add axonpush/skills` is unchanged (that points to the
  GitHub repo, not the marketplace `name`).
- Removed the duplicate `version` field from the `marketplace.json`
  plugin entry. Per Claude Code's docs, `plugin.json` `version` always
  silently wins when both are set, which means a stale duplicate in
  `marketplace.json` can mask the real version. Single source of truth
  is now `plugin.json`.

### Fixed

- README install snippet replaced with the canonical two-step Claude
  Code flow (`/plugin marketplace add axonpush/skills` then `/plugin
  install axonpush@axonpush-plugins`). The previous one-liner shorthand
  isn't part of Claude Code's plugin syntax.

## [0.0.3] – 2026-05-04

### Fixed

- `langchain` sub-skill now writes a per-call `axonpush_handler()`
  factory that pulls the active OpenTelemetry span's `trace_id` (when
  present) and binds the `AxonPushCallbackHandler` to it. The previous
  module-level handler captured the trace_id of process startup, which
  meant agent events never shared a trace with the FastAPI / Flask /
  Django HTTP span the request lived inside. Cross-source correlation
  in the AxonPush dashboard waterfall now just works when the
  `otel-python` skill is installed alongside `langchain`.
- `langchain` skill explicitly documents the per-call factory
  invariant (`axonpush_handler()` not `axonpush_handler`) so the AI
  agent rendering the integration doesn't pin to a single (invalid)
  trace_id forever.

### Documented

- `otel-python` skill: new "Common Pitfalls" section calling out
  AxonPush environment-slug validation (the server rejects publishes
  whose env slug isn't registered for the tenant; SDK >= 0.0.12 logs
  this at ERROR — old SDKs fail silently) and the now-resolved httpx
  self-instrumentation amplification loop (no
  `OTEL_PYTHON_HTTPX_EXCLUDED_URLS` workaround needed for SDK >= 0.0.12).

## [0.0.2] – 2026-05-03

### Added

- Multi-select integrations in `axonpush-integrate`: pick any combination
  of agent frameworks AND log forwarders in one run (e.g. `langchain` +
  `deepagents` + `logging` for a Django + DeepAgents stack).
- 6 new log-forwarder sub-skills, individually invocable:
  - `logging` (Python stdlib, also covers Django dict-config)
  - `loguru`, `structlog` (Python)
  - `pino`, `winston`, `console` (TypeScript / Node)
- Multi-channel creation: orchestrator suggests channels per integration
  type (`agent-events`, `app-logs`, `otel-traces`, `webhooks-in`) and
  loops through `api.sh create-channel` for each one the user picks.
  Primary channel is exposed via `AXONPUSH_CHANNEL_ID`; the full set
  via `AXONPUSH_CHANNELS=name1:id1,name2:id2,...`.
- `api.sh publish-event <channelId> <identifier> <payloadJSON>` and
  `api.sh list-events <channelId> [limit]` for end-to-end verification.
- New Step 7 in `axonpush-integrate`: publishes a real test event via
  the API and polls `list-events` to confirm receipt before declaring
  success — surfaces credential / quota issues immediately.

### Fixed

- `api.sh create-channel` was passing `appId` as a JSON number, but the
  backend DTO requires a string — silent 400. Now uses `--arg`.
- `api.sh list-app` was matching `(.id|tonumber) == $id` but app ids
  are UUID strings — match always failed. Now compares strings against
  both `.id` and `.appId`, then re-fetches via `GET /apps/<id>` so the
  returned object includes the `channels[]` array.
- Validate app + channel name length (≥5 chars) in `api.sh` before
  hitting the API. Backend `MinLength(5)` would otherwise return a
  cryptic 400 with no actionable hint.

## [0.0.1] – 2026-05-03

### Added

- Orchestrator skill `axonpush-integrate` that detects the host project's
  language and AI framework, signs the user in (browser flow or manual API
  key), creates an AxonPush app and channel, writes credentials to `.env`,
  and delegates to the matching framework sub-skill.
- 17 framework sub-skills, individually invocable:
  - Python: `anthropic`, `crewai`, `custom`, `deepagents`, `langchain`,
    `openai-agents`, `otel-python`.
  - TypeScript: `ts-anthropic`, `ts-custom`, `ts-google-adk`, `ts-langchain`,
    `ts-langgraph`, `ts-llamaindex`, `ts-mastra`, `ts-openai-agents`,
    `ts-vercel-ai`, `otel-ts`.
- Four bash helpers under `skills/axonpush-integrate/helpers/`:
  `detect.sh`, `login.sh`, `api.sh`, `env.sh`. Together they port the entire
  `@axonpush/wizard` npm CLI flow with no Node, React, or yargs runtime.
- Live SDK README fetch preamble in every framework sub-skill so generated
  integration code reflects the current shape of `axonpush-python` /
  `axonpush-ts` `master`. Static reference code remains as the offline
  fallback.
- Distribution via the Claude Code plugin marketplace
  (`/plugin install axonpush/skills`) and the cross-agent skills.sh
  installer (`npx skills add axonpush/skills`), which works in 50+ AI
  coding agents (Cursor, Codex, OpenCode, Cline, GitHub Copilot, Windsurf,
  Gemini, …).
