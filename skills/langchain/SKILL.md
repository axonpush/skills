---
name: langchain
description: Wire AxonPush tracing into a Python LangChain or LangGraph project via `AxonPushCallbackHandler`. Use when the user wants chain, LLM, and tool lifecycle events from any chain, agent executor, or LangGraph graph invoked with `.invoke()`.
---

## Reference (live)

Before applying this integration, fetch the latest README from the SDK repo to capture any recent API changes:

- Python skills: `https://raw.githubusercontent.com/axonpush/axonpush-python/master/README.md`
- TypeScript skills: `https://raw.githubusercontent.com/axonpush/axonpush-ts/master/README.md`

Use the section relevant to this framework. If the fetch fails (offline, rate-limited), use the static reference code below as a fallback.

# AxonPush + LangChain Integration

Integrate AxonPush tracing into a LangChain or LangGraph project.

## What gets added

- `AxonPushCallbackHandler` that auto-traces chain/LLM/tool lifecycle events
- Events: `chain.start`, `chain.end`, `llm.start`, `llm.end`, `tool.*.start`, `tool.end`
- A small `axonpush_handler()` factory the user calls at each `.invoke()` site, which reads the active OpenTelemetry trace_id (when present) and binds the callback handler to it. This is what makes the dashboard waterfall include the backend HTTP span and the LangChain agent events together when the project is also OTel-instrumented (FastAPI/Flask/Django + the `otel-python` skill).

## Reference Code

```python
import os
from typing import Optional

from axonpush import AxonPush
from axonpush.integrations.langchain import AxonPushCallbackHandler

axonpush_client = AxonPush(
    api_key=os.environ["AXONPUSH_API_KEY"],
    tenant_id=os.environ["AXONPUSH_TENANT_ID"],
    base_url=os.environ.get("AXONPUSH_BASE_URL", "https://api.axonpush.xyz"),
)


def _current_otel_trace_id() -> Optional[str]:
    """Return the active OTel span's trace_id (32-char hex), or None.

    Soft-imports opentelemetry so this helper is harmless when the project
    isn't OTel-instrumented. When OTel is active and a span is in scope
    (e.g. inside a FastAPI request handler under FastAPIInstrumentor), the
    AxonPush events published from this request share their trace_id with
    the backend HTTP span — both render in one waterfall in the dashboard.
    """
    try:
        from opentelemetry import trace
    except ImportError:
        return None
    span = trace.get_current_span()
    ctx = span.get_span_context()
    if not ctx.is_valid:
        return None
    return format(ctx.trace_id, "032x")


def axonpush_handler(agent_id: str = "my-agent") -> AxonPushCallbackHandler:
    """Build a callback handler for one chain/agent invocation.

    Construct it at each `.invoke()` call site rather than once at import
    time, so it picks up the OTel trace_id of the *current* request. (A
    module-level handler captures the trace_id of process startup, which
    is meaningless.)
    """
    return AxonPushCallbackHandler(
        client=axonpush_client,
        channel_id=int(os.environ["AXONPUSH_CHANNEL_ID"]),
        agent_id=agent_id,
        trace_id=_current_otel_trace_id(),
    )

# At each .invoke() / .ainvoke() call site:
# result = chain.invoke(input, config={"callbacks": [axonpush_handler()]})
# result = await agent.ainvoke(input, config={"callbacks": [axonpush_handler("researcher")]})
```

## Steps

1. Install `axonpush[langchain]` using the project's package manager
2. Add `AXONPUSH_API_KEY`, `AXONPUSH_TENANT_ID`, `AXONPUSH_BASE_URL`, `AXONPUSH_CHANNEL_ID` to `.env`
3. Pick a single shared module the project already uses for cross-cutting infra (e.g. `app/observability.py`, `app/utils/axonpush.py`). Write the `axonpush_client`, `_current_otel_trace_id`, and `axonpush_handler` definitions there. Do not duplicate the client across files — there should be exactly one `AxonPush(...)` constructor call in the project.
4. At each `.invoke()` / `.ainvoke()` call site, import `axonpush_handler` and pass `config={"callbacks": [axonpush_handler("<descriptive-agent-id>")]}`. Use one agent_id per logical agent (e.g. `"researcher"`, `"writer"`) so the dashboard separates their event lanes.
5. **Important — call the factory per invocation, not once at import.** `[axonpush_handler()]` (with parens at the call site) reads the current OTel trace_id; `[axonpush_handler]` (no parens) would pass the function object itself, breaking everything. Module-level `handler = AxonPushCallbackHandler(...)` is also wrong for the same reason: it pins to a single (invalid) trace_id forever.

## Cross-Source Correlation (when both `langchain` and `otel-python` skills are applied)

The reference code above already supports this — no extra wiring needed. With the `otel-python` skill in place, FastAPI / Flask / Django auto-instrumentation creates an HTTP span on every request, and `_current_otel_trace_id()` returns that span's trace_id. The LangChain events published by `axonpush_handler()` get tagged with the same trace_id. The AxonPush dashboard renders both lanes in one waterfall.

If the project isn't OTel-instrumented, `_current_otel_trace_id()` returns `None`, the SDK auto-generates a fresh trace_id, and you still get a clean per-invocation waterfall — just without the backend span attached.

## Fail-Open

The SDK is fail-open by default (`fail_open=True`). If AxonPush is unreachable, tracing callbacks are silently suppressed — the LangChain integration will never crash or block the user's application.
