---
name: otel-python
description: Wire AxonPushSpanExporter into a Python project's OpenTelemetry TracerProvider
---

# AxonPush + OpenTelemetry (Python) Integration

Forward OpenTelemetry spans from a Python service into AxonPush via `AxonPushSpanExporter`.

## What gets added

- `AxonPushSpanExporter` attached to the project's `TracerProvider` through a `BatchSpanProcessor`
- Every OTel span is re-emitted as an `app.span` event with full trace_id, span_id, attributes, events, and links preserved

## Install

Requires the `otel` extra:

```bash
pip install "axonpush[otel]"
# or: uv add "axonpush[otel]"
# or: poetry add "axonpush[otel]"
```

## Reference Code — New Provider

Use this path when the project does **not** already have a `TracerProvider`.

```python
import os
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

from axonpush import AxonPush
from axonpush.integrations.otel import AxonPushSpanExporter

axonpush_client = AxonPush(
    api_key=os.environ["AXONPUSH_API_KEY"],
    tenant_id=os.environ["AXONPUSH_TENANT_ID"],
    base_url=os.environ.get("AXONPUSH_BASE_URL", "https://api.axonpush.xyz"),
)

provider = TracerProvider(resource=Resource.create({"service.name": "my-service"}))
provider.add_span_processor(
    BatchSpanProcessor(
        AxonPushSpanExporter(
            client=axonpush_client,
            channel_id=int(os.environ["AXONPUSH_CHANNEL_ID"]),
            service_name="my-service",
        )
    )
)
trace.set_tracer_provider(provider)

tracer = trace.get_tracer(__name__)
```

## Reference Code — Existing Provider

Use this path when the project already calls `trace.set_tracer_provider(...)` or uses an auto-instrumentation entrypoint. Never register a second global provider — attach to the existing one.

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

from axonpush import AxonPush
from axonpush.integrations.otel import AxonPushSpanExporter

provider = trace.get_tracer_provider()
if isinstance(provider, TracerProvider):
    provider.add_span_processor(
        BatchSpanProcessor(
            AxonPushSpanExporter(
                client=AxonPush(api_key=os.environ["AXONPUSH_API_KEY"], tenant_id=os.environ["AXONPUSH_TENANT_ID"]),
                channel_id=int(os.environ["AXONPUSH_CHANNEL_ID"]),
                service_name="my-service",
            )
        )
    )
```

## Steps

1. Install `axonpush[otel]` using the project's package manager
2. Add `AXONPUSH_API_KEY`, `AXONPUSH_TENANT_ID`, `AXONPUSH_BASE_URL`, `AXONPUSH_CHANNEL_ID` to `.env`
3. Detect whether a `TracerProvider` already exists in the project (search for `set_tracer_provider`, `TracerProvider(`, or auto-instrumentation setup in the main module)
4. If one exists, attach `AxonPushSpanExporter` to it via `BatchSpanProcessor`
5. If none exists, create one (see "New Provider") using the project name as `service.name`
6. Use `BatchSpanProcessor`, never `SimpleSpanProcessor`, in production

## Fail-Open

`AxonPush(fail_open=True)` is the default. If AxonPush is unreachable the exporter silently drops spans — no application impact.
