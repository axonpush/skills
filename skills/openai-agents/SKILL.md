---
name: openai-agents
description: Integrate AxonPush tracing into a project using the OpenAI Agents SDK
---

# AxonPush + OpenAI Agents SDK Integration

Integrate AxonPush tracing into a project using the OpenAI Agents SDK.

## What gets added

- `AxonPushRunHooks` that traces agent runs, tool calls, and handoffs
- Events: `agent.run.start`, `agent.run.end`, `tool.*.start`, `tool.*.end`, `agent.handoff`

## Reference Code

```python
import os
from axonpush import AsyncAxonPush
from axonpush.integrations.openai_agents import AxonPushRunHooks

axonpush_client = AsyncAxonPush(
    api_key=os.environ["AXONPUSH_API_KEY"],
    tenant_id=os.environ["AXONPUSH_TENANT_ID"],
    base_url=os.environ.get("AXONPUSH_BASE_URL", "https://api.axonpush.xyz"),
)

axonpush_hooks = AxonPushRunHooks(
    client=axonpush_client,
    channel_id=int(os.environ["AXONPUSH_CHANNEL_ID"]),
)

# Usage:
# result = await Runner.run(agent, input="...", hooks=axonpush_hooks)
```

## Steps

1. Install `axonpush[openai-agents]` using the project's package manager
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find the main file where Runner.run() is called
4. Add the imports and AsyncAxonPush client (this SDK is async-only)
5. Pass `hooks=axonpush_hooks` to `Runner.run()`

## Important

- OpenAI Agents SDK is **async-only**, so use `AsyncAxonPush` (not `AxonPush`)
- Make sure to close the client when done: `await axonpush_client.close()`
- Or use `async with AsyncAxonPush(...) as client:` context manager

## Fail-Open

The SDK is fail-open by default (`fail_open=True`). If AxonPush is unreachable, tracing hooks are silently suppressed — the OpenAI Agents integration will never crash or block the user's application.
