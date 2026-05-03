---
name: otel-ts
description: Attach `AxonPushSpanExporter` to a TypeScript/Node project's OpenTelemetry `TracerProvider` so every OTel span is forwarded to AxonPush. Use for any Node service already instrumented with OpenTelemetry that wants its spans mirrored to AxonPush.
---

## Reference (live)

Before applying this integration, fetch the latest README from the SDK repo to capture any recent API changes:

- Python skills: `https://raw.githubusercontent.com/axonpush/axonpush-python/master/README.md`
- TypeScript skills: `https://raw.githubusercontent.com/axonpush/axonpush-ts/master/README.md`

Use the section relevant to this framework. If the fetch fails (offline, rate-limited), use the static reference code below as a fallback.

# AxonPush + OpenTelemetry (TypeScript) Integration

Forward OpenTelemetry spans from a Node.js service into AxonPush via `AxonPushSpanExporter`.

## What gets added

- `AxonPushSpanExporter` attached to the project's `TracerProvider` through a `BatchSpanProcessor`
- Every OTel span is re-emitted as an `app.span` event with full traceId, spanId, attributes, events, and links preserved

## Install

`@opentelemetry/api` and `@opentelemetry/sdk-trace-base` are optional peer dependencies. Install them alongside `@axonpush/sdk`:

```bash
bun add @axonpush/sdk @opentelemetry/api @opentelemetry/sdk-trace-base @opentelemetry/sdk-trace-node
# or pnpm / yarn / npm equivalents
```

## Reference Code — New Provider

```typescript
import { AxonPush } from "@axonpush/sdk";
import { AxonPushSpanExporter } from "@axonpush/sdk/integrations/otel";
import { NodeTracerProvider } from "@opentelemetry/sdk-trace-node";
import { BatchSpanProcessor } from "@opentelemetry/sdk-trace-base";
import { Resource } from "@opentelemetry/resources";
import { SemanticResourceAttributes } from "@opentelemetry/semantic-conventions";

const axonpush = new AxonPush({
  apiKey: process.env.AXONPUSH_API_KEY!,
  tenantId: process.env.AXONPUSH_TENANT_ID!,
  baseUrl: process.env.AXONPUSH_BASE_URL,
});

const provider = new NodeTracerProvider({
  resource: new Resource({ [SemanticResourceAttributes.SERVICE_NAME]: "my-service" }),
});

provider.addSpanProcessor(
  new BatchSpanProcessor(
    new AxonPushSpanExporter({
      client: axonpush,
      channelId: Number(process.env.AXONPUSH_CHANNEL_ID),
      serviceName: "my-service",
    }),
  ),
);

provider.register();
```

## Reference Code — Existing Provider

Use this path when the project already registers a `TracerProvider` (e.g. via `provider.register()` or `@opentelemetry/sdk-node`). Attach to the existing provider rather than creating a second one.

```typescript
import { trace } from "@opentelemetry/api";
import { BatchSpanProcessor, BasicTracerProvider } from "@opentelemetry/sdk-trace-base";
import { AxonPushSpanExporter } from "@axonpush/sdk/integrations/otel";

const provider = trace.getTracerProvider() as unknown as BasicTracerProvider;
provider.addSpanProcessor(
  new BatchSpanProcessor(
    new AxonPushSpanExporter({
      client: axonpush,
      channelId: Number(process.env.AXONPUSH_CHANNEL_ID),
      serviceName: "my-service",
    }),
  ),
);
```

## Steps

1. Install `@axonpush/sdk @opentelemetry/api @opentelemetry/sdk-trace-base @opentelemetry/sdk-trace-node` using the project's package manager
2. Add `AXONPUSH_API_KEY`, `AXONPUSH_TENANT_ID`, `AXONPUSH_BASE_URL`, `AXONPUSH_CHANNEL_ID` to `.env`
3. Detect whether a `TracerProvider` already exists in the project (search for `provider.register()`, `NodeTracerProvider(`, `NodeSDK(`, or auto-instrumentation setup)
4. If one exists, attach `AxonPushSpanExporter` to it via `BatchSpanProcessor`
5. If none exists, create one (see "New Provider") using the project name as `service.name`
6. Use `BatchSpanProcessor`, never `SimpleSpanProcessor`, in production

## Fail-Open

`new AxonPush({ failOpen: true })` is the default. If AxonPush is unreachable the exporter silently drops spans — no application impact.
