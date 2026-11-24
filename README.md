# axonpush skills

Workflow verification and business observability, set up with your coding agent.

Define one customer commitment, generate typed hooks and check its outcome against evidence from your own systems. Start with an AI booking request and its actual appointment record when that fits your application. Repository-owned YAML, Zod and Effect contracts use the same deterministic Go verifier locally and on the server. Your application keeps provider credentials and performs business actions.

Existing business profiles, activity views, Nova Hiring Room integrations, OpenTelemetry and error investigation remain available. The integration skill includes a separate business-observability path.

The flow these skills follow:

1. Connect the axonpush MCP (OAuth, no keys to copy).
2. Resolve a workspace/development environment and call `workflows_describe` for questions, exact tool names and a synthetic example.
3. Define the promise, authoritative record, stable case ID and timing. Generate hooks and test satisfied, missing-record and unavailable-source fixtures.
4. Publish the reviewed definition and explicitly activate its version for the selected environment.
5. `workspaces_connect` returns a claim link for the signed-in user to save secrets locally. Bind the source to that connection's publisher ID.
6. Implement reliable post-commit fact publication and reconciliation, then inspect an evaluated case. A receipt or registered source is not verification.

These tools require a server/SDK release that includes workflow verification; check the connected server and installed package capabilities first. If MCP authentication fails, report it once and use local fixtures while the connection is resolved.

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
| `axonpush-integrate` | Workflow-first setup: guided questions, deterministic hooks/tests, definition activation, source binding and evaluated cases. Optional business-observability setup is preserved. |
| `axonpush-tailor-dashboard` | Revise the workspace spec through the shared draft and activate a new revision. |
| `axonpush-investigate` | Investigate a failed or slow run, or a stuck entity, from issue, trace and workspace evidence. |
| `axonpush-compliance` | Add declared tasks, reported decisions, policy outcomes and notice delivery using a compatible SDK. |
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
