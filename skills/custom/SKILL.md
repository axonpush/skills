---
name: custom
description: Wire direct AxonPush event publishing into a Python project that does not use a supported framework. Use when no specific framework integration applies and the user wants to emit custom events with `client.events.publish()`.
---

## Reference (live)

Before applying this integration, fetch the latest README from the SDK repo to capture any recent API changes:

- Python skills: `https://raw.githubusercontent.com/axonpush/python-sdk/master/README.md`
- TypeScript skills: `https://raw.githubusercontent.com/axonpush/ts-sdk/master/README.md`

Use the section relevant to this framework. If the fetch fails (offline, rate-limited), use the static reference code below as a fallback.

# AxonPush Custom Framework Integration

Integrate AxonPush event publishing directly for custom or unsupported frameworks.

## What gets added

- `AxonPush` client for publishing custom events
- Use `client.events.publish()` to send events from anywhere in your code

## Reference Code

```python
import os
from axonpush import AxonPush, EventType

axonpush_client = AxonPush(
    api_key=os.environ["AXONPUSH_API_KEY"],
    tenant_id=os.environ["AXONPUSH_TENANT_ID"],
    base_url=os.environ.get("AXONPUSH_BASE_URL", "https://api.axonpush.xyz"),
)

# Publish events from your code:
# axonpush_client.events.publish(
#     identifier="my.event",
#     payload={"key": "value"},
#     channel_id=os.environ["AXONPUSH_CHANNEL_ID"],
#     agent_id="my-agent",
#     event_type=EventType.CUSTOM,
# )
```

## Steps

1. Install `axonpush` from the latest GitHub commit -- e.g. `uv add "axonpush @ git+https://github.com/axonpush/python-sdk.git"` (or the `pip install`/`poetry add` equivalent)
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find the main entry point of the project
4. Add imports and create the client as a module-level singleton
5. Add example publish calls at key points (e.g., start, end, error handling)

## Custom dimensions (business attributes)

Put low-cardinality business attributes in the event payload under an
`attributes` map. axonpush preserves them and each key becomes a discoverable
dimension — so you can break down, trend, and filter your usage by your own
domain, from the dashboard's Usage explorer or the MCP `analytics_dimensions`
tool.

```python
axonpush_client.events.publish(
    identifier="agent.turn",
    payload={
        "attributes": {
            "participant_role": role,   # "candidate" | "recruiter"
            "tenant": tenant_id,
            "plan": plan_tier,
        },
    },
    channel_id=os.environ["AXONPUSH_CHANNEL_ID"],
    event_type=EventType.CUSTOM,
)
```

They then appear in `GET /analytics/dimensions`, and you can break down
(`dimension=tag&tagKey=participant_role`) or filter
(`filterTagKey=participant_role&filterTagValue=candidate`) by them.

**Naming guidance:** use stable, low-cardinality keys and values. axonpush drops
id-shaped values (UUIDs, long hex/number runs) and very long strings from the
dimension catalog — put per-request identifiers elsewhere in the payload, not in
an attribute meant to be a dimension.

## Fail-Open

The SDK is fail-open by default (`fail_open=True`). If AxonPush is unreachable, publish calls return `None` instead of raising — the SDK will never crash or block the user's application.
