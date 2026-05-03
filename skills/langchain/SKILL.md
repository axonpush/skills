---
name: langchain
description: Integrate AxonPush tracing into a LangChain or LangGraph project
---

# AxonPush + LangChain Integration

Integrate AxonPush tracing into a LangChain or LangGraph project.

## What gets added

- `AxonPushCallbackHandler` that auto-traces chain/LLM/tool lifecycle events
- Events: `chain.start`, `chain.end`, `llm.start`, `llm.end`, `tool.*.start`, `tool.end`

## Reference Code

```python
import os
from axonpush import AxonPush
from axonpush.integrations.langchain import AxonPushCallbackHandler

axonpush_client = AxonPush(
    api_key=os.environ["AXONPUSH_API_KEY"],
    tenant_id=os.environ["AXONPUSH_TENANT_ID"],
    base_url=os.environ.get("AXONPUSH_BASE_URL", "https://api.axonpush.xyz"),
)

axonpush_handler = AxonPushCallbackHandler(
    client=axonpush_client,
    channel_id=int(os.environ["AXONPUSH_CHANNEL_ID"]),
    agent_id="my-agent",
)

# For any chain:
# result = chain.invoke(input, config={"callbacks": [axonpush_handler]})

# For an agent executor:
# result = agent_executor.invoke(input, config={"callbacks": [axonpush_handler]})
```

## Steps

1. Install `axonpush[langchain]` using the project's package manager
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find the main file where chains/agents are invoked
4. Add the imports and client initialization (as module-level code)
5. Add `config={"callbacks": [axonpush_handler]}` to `.invoke()` calls

## Fail-Open

The SDK is fail-open by default (`fail_open=True`). If AxonPush is unreachable, tracing callbacks are silently suppressed — the LangChain integration will never crash or block the user's application.
