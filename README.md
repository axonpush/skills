# AxonPush Skills

Claude Code plugin and cross-agent skill bundle that wires the AxonPush
observability SDK into any AI agent project. The orchestrator detects the
project's language and framework, handles AxonPush sign-in and app/channel
creation, writes `.env` credentials, and applies framework-specific
integration code.

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

## Sub-skills

| Skill | Language | Purpose |
| --- | --- | --- |
| `axonpush-integrate` | – | Orchestrator. Detects project, signs in, creates app/channel, delegates. |
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
