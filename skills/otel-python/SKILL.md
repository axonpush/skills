---
name: otel-python
description: Forward a Python service's OpenTelemetry spans and logs into axonpush, either by pointing the stock OTLP exporter at the axonpush OTLP endpoint (no code) or by attaching AxonPushSpanExporter to the existing TracerProvider (adds agent attributes). Use for any Python service already instrumented with OpenTelemetry.
---

# axonpush + OpenTelemetry (Python)

axonpush speaks OTLP/HTTP natively, so a service that already emits OpenTelemetry needs no new SDK. There are two paths; pick per the project, and they can coexist.

## Reference (live)

Before applying, fetch the current SDK monorepo README to catch any recent API change:

- `https://raw.githubusercontent.com/axonpush/sdks/HEAD/README.md` (source under `packages/python`)

The published package is **`axonpush`** on PyPI. Ignore the archived `axonpush/python-sdk` repo, it is stale and still resolves. If the fetch fails (offline, rate-limited), use the static reference below.

## Path A: stock OTLP exporter (no axonpush package, recommended when already instrumented)

Point the standard OpenTelemetry `otlphttp` exporter at axonpush. Nothing about the application changes except one exporter block or a few environment variables.

The endpoint is the bare host; the exporter appends `/v1/traces` and `/v1/logs` itself. Auth is an axonpush API key in the `X-API-Key` header.

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="https://api.axonpush.xyz"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export OTEL_EXPORTER_OTLP_HEADERS="X-API-Key=$AXONPUSH_API_KEY"
# Optional: pin the environment slug (must exist on the tenant).
# export OTEL_EXPORTER_OTLP_HEADERS="X-API-Key=$AXONPUSH_API_KEY,X-Axonpush-Environment=prod"
```

Or in code, per signal:

```python
import os
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

exporter = OTLPSpanExporter(
    endpoint="https://api.axonpush.xyz/v1/traces",  # explicit path in per-signal mode
    headers={"X-API-Key": os.environ["AXONPUSH_API_KEY"]},
)
provider = TracerProvider()
provider.add_span_processor(BatchSpanProcessor(exporter))
```

**Routing**: an **app-scoped** API key auto-routes, `/v1/traces` to a channel named `otlp-traces` and `/v1/logs` to `otlp-logs`, both created in the key's app on first use. A key with no app returns `400` (nothing to route into): pin the key to an app, or add `X-Axonpush-Channel: <channelId>` to name a channel explicitly. A public `pt_…` token always needs `X-Axonpush-Channel`.

This path forwards raw OTel spans. It has no field for agent semantics (`agent.tool_call.start`, `agent.handoff`), use Path B or a framework sub-skill for those.

## Path B: AxonPushSpanExporter (adds agent attributes)

Use this when you want the same spans to carry axonpush agent attributes, or you already build the client for other axonpush features. It writes through the events API, not `/v1/traces`.

Install the `otel` extra:

```bash
uv add "axonpush[otel]"   # or: pip install "axonpush[otel]"  /  poetry add "axonpush[otel]"
```

If a `TracerProvider` already exists in the project, **attach to it**, never register a second global provider:

```python
import os
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
                client=AxonPush(
                    api_key=os.environ["AXONPUSH_API_KEY"],
                    tenant_id=os.environ["AXONPUSH_TENANT_ID"],
                    base_url=os.environ.get("AXONPUSH_BASE_URL", "https://api.axonpush.xyz"),
                ),
                channel_id=os.environ["AXONPUSH_CHANNEL_ID"],
                service_name="my-service",
            )
        )
    )
```

When no provider exists yet, create one with `TracerProvider(resource=Resource.create({"service.name": "my-service"}))`, add the same processor, then `trace.set_tracer_provider(provider)`.

Use `BatchSpanProcessor`, never `SimpleSpanProcessor`, in production.

## Which path

Path A is simpler and touches no application code; take it when the service is already instrumented and you only have spans/logs. Path B is right when you want agent attributes on the spans or already run the axonpush SDK. Both end in the same store and the same trace, so a large service commonly uses Path A for its HTTP/DB layers and a framework sub-skill (or Path B) around the agent.

## Correlation

OTel spans join gateway spans and Sentry events on one trace when they share a trace id. axonpush maps an OTel 32-hex trace id to and from its own UUID4 trace id deterministically, so if two services both run OTel and let the standard W3C propagators carry `traceparent`, their spans land in the same axonpush trace with no manual work. Across a non-OTel boundary, propagate `traceparent` yourself.

## Fail-open

`AxonPush(fail_open=True)` is the default, and the stock OTLP exporter drops on failure by design. If axonpush is unreachable, spans are dropped, never blocking the application.

## Common pitfalls

**Environment slug must match a registered tenant environment.** If you set `X-Axonpush-Environment` / `AXONPUSH_ENVIRONMENT`, it must match a slug already registered for the tenant (Environments page in the dashboard). An unknown slug is rejected. Omit it to use the tenant default. Confirm from `curl` via the `x-axonpush-resolved-environment` and `x-axonpush-resolved-via` response headers.

**Self-instrumentation amplification (resolved in axonpush ≥ 0.0.12).** The SDK now suppresses OTel instrumentation around its own httpx requests, so the Path B exporter no longer creates a span per publish. No `OTEL_PYTHON_HTTPX_EXCLUDED_URLS` workaround is needed.
