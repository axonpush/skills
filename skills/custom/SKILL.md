---
name: custom
description: Send business observations and profile traits from a Python project to an axonpush workspace with `observe()` and `identify()`. Use for committed state transitions, joins, waits and outcomes that no framework integration captures, or when no supported framework applies.
---

## Reference (live)

Before applying this integration, fetch the latest SDK README to capture recent API changes:

- `https://raw.githubusercontent.com/axonpush/sdks/master/packages/python/README.md` ("Agent operations" section)

If the fetch fails, use the reference code below.

# Python observations

`observe()` sends a metadata-only observation to a workspace. The workspace spec decides what it means: each entity whose type appears in `refs` and has a rule matching the event stores its declared fields from `attributes`, then applies the rule's `set` literals. `identify()` attaches profile traits (names, plans) to an entity.

The event names, ref types and attribute keys must exist in the workspace spec. Undeclared attribute keys are dropped and listed in the report's `dropped`. Build or extend the spec first with `axonpush-integrate` or `axonpush-tailor-dashboard`.

## Reference code

```python
import os
from axonpush import AxonPush

axonpush = AxonPush()  # reads AXONPUSH_API_KEY, AXONPUSH_BASE_URL and AXONPUSH_ENVIRONMENT
WORKSPACE = os.environ["AXONPUSH_WORKSPACE_ID"]

axonpush.observe(
    WORKSPACE,
    "ticket.solved",
    refs={"ticket": ticket.id, "agent": agent.id},
    attributes={"status": "solved", "handle_ms": handle_ms},
    source_event_id=f"ticket:{ticket.id}:rev:{ticket.revision}",
)

axonpush.identify(WORKSPACE, "customer", customer.id, {"display_name": customer.name, "plan": None})
```

`observe` also takes `occurred_at`, `trace_id`, `span_id`, `environment`, `snapshot` and `source` (`{"ref": ..., "revision": ...}`); `observe_many` sends a list in batches of 100. `identify` merges traits restricted to the entity's `profile` keys, and `None` deletes a trait. `group` is the same call, for company-like entities. `AsyncAxonPush` has the same methods.

## Steps

1. Install `axonpush` with the project's package manager (`uv add axonpush`, `pip install axonpush` or `poetry add axonpush`). If the installed version has no `AxonPush.observe`, install from source: `uv add "axonpush @ git+https://github.com/axonpush/sdks.git@dev#subdirectory=packages/python"`.
2. Make sure `AXONPUSH_API_KEY`, `AXONPUSH_BASE_URL`, `AXONPUSH_WORKSPACE_ID` and `AXONPUSH_ENVIRONMENT` are in the app's git-ignored env file. `workspaces_connect` returns them; do not ask the user to copy keys.
3. Create the client once at module level.
4. Call `observe` where each declared transition is committed, after the transaction commits, and `identify` where profile data changes.
5. Send one test observation and confirm it in `workspaces_catalog` or `activity_timeline`.

## Rules

- Metadata only: opaque ids, bounded enum values, numbers, durations and timestamps. Never send prompts, model output, message bodies, tool arguments or results, documents, credentials, full URLs or raw exception text. Personal values belong only in attributes declared `personal: true`.
- Reuse a stable `source_event_id` when the same fact may be retried, and pass the original `occurred_at` when sending late, so duplicates and late deliveries do not distort state.
- Use `snapshot=True` when seeding current state from existing records. Snapshots update state without counting as activity or funnel progress.
- Never call axonpush inside a business transaction, and never let a failed export change the response. For must-not-lose transitions, send from an outbox or background worker with retries.

## Fail-open

The SDK is fail-open by default (`fail_open=True`). If axonpush is unreachable, `observe` and `identify` return `None` instead of raising, so the application keeps working.
