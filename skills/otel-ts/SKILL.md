---
name: otel-ts
description: Forward a TypeScript/Node service's OpenTelemetry spans and logs into axonpush, either by pointing the stock OTLP exporter at the axonpush OTLP endpoint (no code) or by attaching AxonPushSpanExporter to the existing TracerProvider (adds agent attributes). Use for any Node service already instrumented with OpenTelemetry.
---

# axonpush + OpenTelemetry (TypeScript/Node)

axonpush speaks OTLP/HTTP natively, so a service that already emits OpenTelemetry needs no new SDK. There are two paths; pick per the project, and they can coexist.

## Reference (live)

Before applying, fetch the current SDK monorepo README to catch any recent API change:

- `https://raw.githubusercontent.com/axonpush/sdks/HEAD/README.md` (source under `packages/typescript`)

The published package is **`@axonpush/sdk`** on npm. Ignore the archived `axonpush/ts-sdk` repo, it is stale and still resolves. If the fetch fails (offline, rate-limited), use the static reference below.

## Path A: stock OTLP exporter (no axonpush package, recommended when already instrumented)

Point the standard OpenTelemetry `otlphttp` exporter at axonpush. The endpoint is the bare host; the exporter appends `/v1/traces` and `/v1/logs`. Auth is an axonpush API key in the `X-API-Key` header.

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="https://api.axonpush.xyz"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export OTEL_EXPORTER_OTLP_HEADERS="X-API-Key=$AXONPUSH_API_KEY"
```

Or in code:

```ts
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";

const exporter = new OTLPTraceExporter({
  url: "https://api.axonpush.xyz/v1/traces",
  headers: { "X-API-Key": process.env.AXONPUSH_API_KEY! },
});
```

**Routing**: an **app-scoped** API key auto-routes, `/v1/traces` to a channel named `otlp-traces` and `/v1/logs` to `otlp-logs`, both created in the key's app on first use. A key with no app returns `400`: pin the key to an app, or add `X-Axonpush-Channel: <channelId>`. A public `pt_…` token always needs `X-Axonpush-Channel`.

This path forwards raw OTel spans; it has no field for agent semantics. Use Path B or a framework sub-skill for those.

## Path B: AxonPushSpanExporter (adds agent attributes)

`@opentelemetry/api` and `@opentelemetry/sdk-trace-base` are optional peer deps. Install them with `@axonpush/sdk` using the project's package manager:

```bash
npm install @axonpush/sdk @opentelemetry/api @opentelemetry/sdk-trace-base @opentelemetry/sdk-trace-node
# or the bun / pnpm / yarn equivalent
```

If a `TracerProvider` already exists (via `provider.register()` or `@opentelemetry/sdk-node`), **attach to it** rather than creating a second one:

```ts
import { trace } from "@opentelemetry/api";
import { BatchSpanProcessor, BasicTracerProvider } from "@opentelemetry/sdk-trace-base";
import { AxonPush } from "@axonpush/sdk";
import { AxonPushSpanExporter } from "@axonpush/sdk/integrations/otel";

const axonpush = new AxonPush({
  apiKey: process.env.AXONPUSH_API_KEY!,
  tenantId: process.env.AXONPUSH_TENANT_ID!,
  baseUrl: process.env.AXONPUSH_BASE_URL,
});

const provider = trace.getTracerProvider() as unknown as BasicTracerProvider;
provider.addSpanProcessor(
  new BatchSpanProcessor(
    new AxonPushSpanExporter({
      client: axonpush,
      channelId: process.env.AXONPUSH_CHANNEL_ID,
      serviceName: "my-service",
    }),
  ),
);
```

When no provider exists yet, create a `NodeTracerProvider` with a `service.name` resource, add the same processor, and `provider.register()`.

Use `BatchSpanProcessor`, never `SimpleSpanProcessor`, in production.

## Which path

Path A touches no application code; take it when the service is already instrumented and you only have spans/logs. Path B is right when you want agent attributes on the spans or already run the axonpush SDK. Both end in the same store and the same trace.

## Correlation

OTel spans join gateway spans and Sentry events on one trace when they share a trace id. axonpush maps an OTel 32-hex trace id to and from its own UUID4 trace id deterministically, so two services that both run OTel and let the standard W3C propagators carry `traceparent` land in the same axonpush trace with no manual work. Across a non-OTel boundary, propagate `traceparent` yourself.

## Fail-open

`new AxonPush({ failOpen: true })` is the default, and the stock OTLP exporter drops on failure by design. If axonpush is unreachable, spans are dropped, never blocking the application.

## Common pitfalls

**Environment slug must match a registered tenant environment.** If you set `X-Axonpush-Environment`, it must match a slug registered for the tenant. An unknown slug is rejected. Confirm from `curl` via the `x-axonpush-resolved-environment` and `x-axonpush-resolved-via` response headers.
