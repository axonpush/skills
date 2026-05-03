---
name: crewai
description: Wire AxonPush tracing into a Python CrewAI project (`crewai` package). Use when the user wants to observe crew lifecycle, agent steps, tool calls, and task completion across a multi-agent CrewAI workflow.
---

## Reference (live)

Before applying this integration, fetch the latest README from the SDK repo to capture any recent API changes:

- Python skills: `https://raw.githubusercontent.com/axonpush/axonpush-python/master/README.md`
- TypeScript skills: `https://raw.githubusercontent.com/axonpush/axonpush-ts/master/README.md`

Use the section relevant to this framework. If the fetch fails (offline, rate-limited), use the static reference code below as a fallback.

# AxonPush + CrewAI Integration

Integrate AxonPush tracing into a CrewAI project.

## What gets added

- `AxonPushCrewCallbacks` with manual callback methods for crew lifecycle
- Events: `crew.start`, `crew.end`, `agent.step`, `tool.*.start`, `tool.*.end`, `task.complete`

## Reference Code

```python
import os
from axonpush import AxonPush
from axonpush.integrations.crewai import AxonPushCrewCallbacks

axonpush_client = AxonPush(
    api_key=os.environ["AXONPUSH_API_KEY"],
    tenant_id=os.environ["AXONPUSH_TENANT_ID"],
    base_url=os.environ.get("AXONPUSH_BASE_URL", "https://api.axonpush.xyz"),
)

axonpush_callbacks = AxonPushCrewCallbacks(
    client=axonpush_client,
    channel_id=int(os.environ["AXONPUSH_CHANNEL_ID"]),
    agent_id="crewai",
)

# Usage:
# axonpush_callbacks.on_crew_start()
# crew = Crew(
#     agents=[...],
#     tasks=[...],
#     step_callback=axonpush_callbacks.on_step,
#     task_callback=axonpush_callbacks.on_task_complete,
# )
# result = crew.kickoff()
# axonpush_callbacks.on_crew_end(result)
```

## Steps

1. Install `axonpush[crewai]` using the project's package manager
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find the file where `Crew(...)` is instantiated
4. Add imports and create the callbacks object
5. Add `step_callback=axonpush_callbacks.on_step` and `task_callback=axonpush_callbacks.on_task_complete` to `Crew()`
6. Add `axonpush_callbacks.on_crew_start()` before `crew.kickoff()`
7. Add `axonpush_callbacks.on_crew_end(result)` after

## Fail-Open

The SDK is fail-open by default (`fail_open=True`). If AxonPush is unreachable, tracing callbacks are silently suppressed — the CrewAI integration will never crash or block the user's application.
