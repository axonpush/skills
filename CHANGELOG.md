# Changelog

All notable changes to this plugin are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [SemVer](https://semver.org/).

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
