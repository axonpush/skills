---
name: otel-python
description: Attach `AxonPushSpanExporter` to a Python project's OpenTelemetry `TracerProvider` so every OTel span is forwarded to AxonPush. Use for any service already instrumented with OpenTelemetry that wants its spans mirrored to AxonPush.
---

## Reference (live)

Before applying this integration, fetch the latest README from the SDK repo to capture any recent API changes:

- Python skills: `https://raw.githubusercontent.com/axonpush/axonpush-python/master/README.md`
- TypeScript skills: `https://raw.githubusercontent.com/axonpush/axonpush-ts/master/README.md`

Use the section relevant to this framework. If the fetch fails (offline, rate-limited), use the static reference code below as a fallback.

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

## Common Pitfalls

### Environment slug must match a registered tenant environment

If you set `AXONPUSH_ENVIRONMENT`, the value has to match a slug already registered for the tenant (visit the Environments page in the AxonPush dashboard). Passing your application's own env name (e.g. `"development"` or `"production"`) when the tenant only has `dev` / `staging` / `prod` configured causes the server to reject every publish. The SDK's background publisher logs this at ERROR (`axonpush publish rejected by server: ... [code=...]`); look there if events stop flowing after deploy.

Either omit `AXONPUSH_ENVIRONMENT` (the server treats unset as the tenant default) or set it to one of the configured slugs.

### Self-instrumentation amplification (resolved in axonpush ≥ 0.0.12)

OTel's `HTTPXClientInstrumentor` previously created a span for every SDK publish, which the exporter would publish, generating another span, etc. The SDK now suppresses OTel instrumentation around its own httpx requests (sets the `suppress_instrumentation` and `suppress_http_instrumentation` context keys), so this is handled automatically — no `OTEL_PYTHON_HTTPX_EXCLUDED_URLS` workaround needed for axonpush ≥ 0.0.12.
