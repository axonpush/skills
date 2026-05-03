---
name: deepagents
description: Wire AxonPush tracing into a Python project using LangChain Deep Agents (`deepagents` package, `create_deep_agent`). Use when the user wants planning, subagent, filesystem, sandbox, and tool lifecycle events from a deep-agent workflow.
---

## Reference (live)

Before applying this integration, fetch the latest README from the SDK repo to capture any recent API changes:

- Python skills: `https://raw.githubusercontent.com/axonpush/axonpush-python/master/README.md`
- TypeScript skills: `https://raw.githubusercontent.com/axonpush/axonpush-ts/master/README.md`

Use the section relevant to this framework. If the fetch fails (offline, rate-limited), use the static reference code below as a fallback.

# AxonPush + Deep Agents Integration

Integrate AxonPush tracing into a project using LangChain Deep Agents (`deepagents` package).

## What gets added

- `AxonPushDeepAgentHandler` that auto-traces chain/LLM/tool lifecycle events with Deep Agent-specific awareness
- Planning events: `planning.update`, `planning.complete` (when `write_todos` is called)
- Subagent events: `subagent.spawn`, `subagent.complete` (when `task` tool delegates work)
- Filesystem events: `filesystem.read`, `filesystem.write` (for `read_file`, `write_file`, `edit_file`, `ls`, `glob`, `grep`)
- Sandbox events: `sandbox.execute` (for `execute` tool)
- Standard events: `chain.start/end`, `llm.start/end`, `tool.*.start`, `tool.end`

## Reference Code

```python
import os
from deepagents import create_deep_agent
from axonpush import AxonPush
from axonpush.integrations.deepagents import AxonPushDeepAgentHandler

axonpush_client = AxonPush(
    api_key=os.environ["AXONPUSH_API_KEY"],
    tenant_id=os.environ["AXONPUSH_TENANT_ID"],
    base_url=os.environ.get("AXONPUSH_BASE_URL", "https://api.axonpush.xyz"),
)

axonpush_handler = AxonPushDeepAgentHandler(
    client=axonpush_client,
    channel_id=int(os.environ["AXONPUSH_CHANNEL_ID"]),
    agent_id="deep-agent",
)

agent = create_deep_agent(
    tools=[],
    system_prompt="You are a helpful assistant.",
)

# Run with AxonPush tracing
result = agent.invoke(
    {"messages": [{"role": "user", "content": "Research AI frameworks"}]},
    config={"callbacks": [axonpush_handler]},
)
```

## Steps

1. Install `axonpush[deepagents]` using the project's package manager
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find the main file where `create_deep_agent()` or `agent.invoke()` is called
4. Add the imports and client initialization (as module-level code)
5. Add `config={"callbacks": [axonpush_handler]}` to `.invoke()` calls

## Fail-Open

The SDK is fail-open by default (`fail_open=True`). If AxonPush is unreachable, tracing callbacks are silently suppressed — the Deep Agents integration will never crash or block the user's application.
