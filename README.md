# axonpush skills

Passive, metadata-only observability for agent and business operations, set up by your coding agent.

axonpush never sits in your request path. Your app sends observations (opaque ids, states, outcomes, timings) and its existing OpenTelemetry, framework or Sentry telemetry; axonpush projects them into a workspace built for your business. Each installation declares its own spec: a data dictionary of attributes, the entities being tracked, the events that update them, and the views, funnels and alerts the dashboard shows. Nothing is hardcoded to one domain; templates such as Nova (a hiring room) and a support desk are starting points.

The flow these skills follow:

1. Connect the axonpush MCP (OAuth, no keys to copy).
2. `workspaces_describe` and `workspaces_catalog` show the spec format and what the app already sends.
3. The agent builds the spec in a shared draft with typed, version-checked ops (`workspaces_applyDraftOps`), which the user can watch and edit in the dashboard.
4. The user reviews and activates the draft.
5. `workspaces_connect` mints a publish-only key and returns the env the app needs.
6. The agent adds `observe` and `identify` calls and any OTLP, framework or Sentry wiring, then verifies a test event.

## Install

Claude Code (add the marketplace, then install the plugin from it):

```
/plugin marketplace add axonpush/skills
/plugin install axonpush@axonpush-plugins
```

Any other agent (Cursor, Codex, OpenCode, Cline, GitHub Copilot, Windsurf,
Gemini, and 40+ more) via [skills.sh](https://skills.sh):

```
npx skills add axonpush/skills
```

## Usage

Connect the MCP first:

```
claude mcp add --transport http axonpush https://api.axonpush.xyz/mcp
```

Then ask your agent to run `/axonpush-integrate` (or, in chat-style hosts,
"run the axonpush-integrate skill"). Run `/axonpush-tailor-dashboard` later to
reshape the workspace as the app grows, and `/axonpush-investigate` to debug a
failed run or a stuck entity from the code. Framework sub-skills can be invoked
directly, for example `/axonpush-langchain`.

## Sub-skills

| Skill | Purpose |
| --- | --- |
| `axonpush-integrate` | End-to-end setup: MCP, workspace spec, activation, `workspaces_connect`, instrumentation and verification. |
| `axonpush-tailor-dashboard` | Revise the workspace spec through the shared draft and activate a new revision. |
| `axonpush-investigate` | Investigate a failed or slow run, or a stuck entity, from issue, trace and workspace evidence. |
| `custom`, `ts-custom` | `observe` and `identify` calls for business state and profiles. |
| `otel-python`, `otel-ts`, `dotnet-otel` | Export spans from an existing OpenTelemetry setup. |
| `langchain`, `deepagents`, `crewai`, `anthropic`, `openai-agents`, `ts-*`, `dotnet-semantic-kernel` | Model and tool span metadata from agent frameworks, without changing routing. |
| `logging`, `loguru`, `structlog`, `pino`, `winston`, `console` | Forward structured diagnostics. |
| `sentry` | Point an existing Sentry SDK at axonpush. |

Framework skills read the matching SDK README from `axonpush/sdks`
(`packages/python`, `packages/typescript`, `packages/dotnet`; published as
`axonpush` on PyPI, `@axonpush/sdk` on npm and `AxonPush.*` on NuGet). The code
in each `SKILL.md` is the offline fallback.

## Local development

Both installers accept a path, so the plugin can be exercised end to end
before publishing:

```bash
# Claude Code, from a local checkout
claude
/plugin install --local ~/gits/axonpush-skills

# Cross-agent install from a local checkout
npx skills add ~/gits/axonpush-skills
```

CI runs `shellcheck` against the helpers and lints SKILL.md frontmatter
with `yq`. To replicate locally:

```bash
shellcheck skills/axonpush-integrate/helpers/*.sh
find skills -name SKILL.md -exec yq e '.name, .description' {} \;
```

## License

MIT. See [LICENSE](LICENSE).
