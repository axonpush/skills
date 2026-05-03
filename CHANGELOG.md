# Changelog

All notable changes to this plugin are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [SemVer](https://semver.org/).

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
