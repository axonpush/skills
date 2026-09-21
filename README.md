# axonpush skills

Agent observability and control with zero instrumentation. Change one
`base_url`, see and block the tool call or handoff before it executes, on
request and response, and keep a regulator-ready audit trail.

This is a Claude Code plugin and cross-agent skill bundle that wires axonpush
into any AI agent project. The orchestrator detects the project's language
and framework, handles axonpush sign-in and app/channel creation, writes
`.env` credentials, and then either routes the project's LLM traffic through
the axonpush gateway (the zero-instrumentation path) or applies a
framework-specific integration, whichever fits.

## What axonpush gives you

- **Zero-instrumentation gateway.** Point your OpenAI or Anthropic
  `base_url` at the axonpush gateway (`/gw/openai` or `/gw/anthropic`) and
  add an `x-axonpush-api-key` header. No SDK or framework needed. Every
  call, including tool calls and agent handoffs, is captured as a queryable
  span.
- **Tool-call and handoff observability.** Tool calls appear as spans with
  the tool name, arguments, and outcome. Analytics break down by agent and
  by tool, with agent, tool, and semantic-kind event filters.
- **Custom dimensions and tailored dashboards.** Stamp your own business
  attributes on spans (e.g. `participant_role`, `tenant`, `plan`) and axonpush
  makes each one a discoverable dimension you can break down, trend, and filter
  by — from the dashboard's Usage explorer or the MCP `analytics_dimensions`
  tool. Because a dashboard is a JSON widget spec bound to the analytics API,
  your coding agent can scan your backend and author one tailored to your domain
  over MCP. See the `axonpush-tailor-dashboard` skill.
- **Inline moderation and enforcement.** Rules can block, redact, or flag on
  the request, the response, or a specific tool call, for example block a
  tool named `transfer_funds`, or block a call whose `amount` argument is
  over a threshold. Enforcement runs before the tool call or handoff
  executes.
- **Spend policies.** Cost governance shaped as scope x window x
  threshold ladder. A policy targets a scope (app, env, model, provider,
  api-key, user, or tag), a window (daily, weekly, monthly, or
  cumulative), and a USD limit, then climbs a ladder of rungs where each
  rung is a threshold percent mapped to an action (notify, block, or
  fallback to a cheaper model). Blocks can be soft or hard, so a runaway
  agent is throttled or stopped before it burns the limit.
- **Audit trail.** An immutable, queryable record of what each agent did and
  what axonpush allowed, redacted, or blocked, shaped for compliance reviews
  (DORA, EU AI Act, SR 11-7).

Moderation rules and spend policies are authored in the dashboard, not in
project code. These skills wire the traffic; you configure the rules and
policies in your app's settings.

## Install

Claude Code (two-step — Claude Code's plugin system requires adding the
marketplace before installing plugins from it):

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

Ask your agent to run `/axonpush-integrate` (or, in chat-style hosts,
"run the axonpush-integrate skill"). The orchestrator will walk through
detection, login, app/channel selection, `.env` writing, and code edits.

Power users can invoke any framework sub-skill directly, e.g.
`/axonpush-langchain`.

Once telemetry is flowing, run `/axonpush-tailor-dashboard` to have your agent
scan the backend, discover (and if needed instrument) the business dimensions
your app emits, and save a dashboard tailored to it over the axonpush MCP.

## Sub-skills

| Skill | Language | Purpose |
| --- | --- | --- |
| `axonpush-integrate` | – | Orchestrator. Detects project, signs in, creates app/channel, delegates. |
| `axonpush-tailor-dashboard` | – | Scans the backend, discovers/instruments business dimensions, and authors a dashboard tailored to the project over the axonpush MCP. |
| `gateway` | any | Zero-instrumentation gateway. Change one `base_url` plus a header; captures every call, tool call, and handoff, and runs moderation and spend policies inline. |
| `anthropic` | Python | Anthropic SDK message tracing. |
| `crewai` | Python | CrewAI crew, agent, tool, and task callbacks. |
| `custom` | Python | Direct event publishing for unsupported frameworks. |
| `deepagents` | Python | LangChain Deep Agents handler with planning/subagent/sandbox events. |
| `langchain` | Python | LangChain / LangGraph callback handler. |
| `openai-agents` | Python | OpenAI Agents SDK run hooks (async). |
| `otel-python` | Python | `AxonPushSpanExporter` for an OpenTelemetry `TracerProvider`. |
| `ts-anthropic` | TypeScript | Anthropic SDK message tracing. |
| `ts-custom` | TypeScript | Direct event publishing for unsupported frameworks. |
| `ts-google-adk` | TypeScript | Google AI Development Kit lifecycle callbacks. |
| `ts-langchain` | TypeScript | LangChain.js callback handler. |
| `ts-langgraph` | TypeScript | LangGraph.js handler with graph node tracing. |
| `ts-llamaindex` | TypeScript | LlamaIndex.ts query/retriever/LLM tracing. |
| `ts-mastra` | TypeScript | Mastra workflow and tool hooks. |
| `ts-openai-agents` | TypeScript | OpenAI Agents SDK run hooks. |
| `ts-vercel-ai` | TypeScript | Vercel AI SDK middleware. |
| `otel-ts` | TypeScript | `AxonPushSpanExporter` for a Node `TracerProvider`. |

Every framework sub-skill fetches the matching section of the live SDK
README at runtime to stay in sync with `axonpush-python` /
`axonpush-ts` `master`. Static reference code in each `SKILL.md` is the
offline fallback.

## Local development

Both installers accept a path, so the plugin can be exercised end-to-end
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
