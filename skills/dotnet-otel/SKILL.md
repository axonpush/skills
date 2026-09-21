---
name: dotnet-otel
description: Wire AxonPush tracing into any .NET OpenTelemetry project via `AxonPushSpanExporter`. Use when the project already instruments code with `System.Diagnostics.Activity` or OpenTelemetry auto-instrumentation, and wants those spans forwarded to AxonPush.
---

## Reference (live)

Before applying this integration, fetch the latest README from the SDK repo to capture any recent API changes:

- `https://raw.githubusercontent.com/AxonPush/axonpush-dotnet/main/README.md`

If the fetch fails (offline or rate-limited), fall back to the reference code below.

# AxonPush + .NET OpenTelemetry integration

Send OpenTelemetry spans from any .NET application to AxonPush.

## What gets added

- `AxonPushSpanExporter`, a `BaseExporter<Activity>` that maps each `Activity` to an AxonPush `app.span` event.
- `AddAxonPushExporter` extensions on `TracerProviderBuilder` (overloads for "supply your own `AxonPushClient`" and "configure one in-place").
- Span payloads serialised in the same JSON shape the Python (`axonpush`) and TypeScript (`@axonpush/sdk`) SDKs use. Traces emitted by any client land in the AxonPush UI with an identical schema.

## Install

```bash
dotnet add package AxonPush.Otel
```

## Reference Code

Plain console or worker app:

```csharp
using OpenTelemetry;
using OpenTelemetry.Trace;
using AxonPush.Otel;

using var tracerProvider = Sdk.CreateTracerProviderBuilder()
    .AddSource("MyApp")
    .ConfigureResource(r => r.AddService("my-app", serviceVersion: "1.0.0"))
    .AddAxonPushExporter(
        client =>
        {
            client.ApiKey = Environment.GetEnvironmentVariable("AXONPUSH_API_KEY")!;
            client.TenantId = Environment.GetEnvironmentVariable("AXONPUSH_TENANT_ID")!;
        },
        exporter =>
        {
            exporter.ChannelId = Environment.GetEnvironmentVariable("AXONPUSH_CHANNEL_ID")!;
            exporter.Environment = "production";
        })
    .Build();
```

ASP.NET Core (with `Microsoft.Extensions.Hosting`):

```csharp
using OpenTelemetry.Trace;
using AxonPush.Otel;

builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddAxonPushExporter(
            client => { /* AXONPUSH_* */ },
            exporter => { exporter.ChannelId = "..."; }));
```

## Steps

1. Add the NuGet package: `dotnet add package AxonPush.Otel`.
2. Add `AXONPUSH_API_KEY`, `AXONPUSH_TENANT_ID`, `AXONPUSH_CHANNEL_ID`, and (optionally) `AXONPUSH_ENVIRONMENT` to the project's secret store.
3. Add `AddAxonPushExporter(...)` to the project's existing `TracerProviderBuilder` configuration. If the project does not have one yet, follow the ASP.NET Core snippet above.
4. Decide whether to share a single `AxonPushClient` across the application (e.g. for `AxonPush.Otel` and the raw `AxonPush` events client). To share, construct the client once via DI and pass it to the overload `AddAxonPushExporter(builder, AxonPushClient client, Action<AxonPushSpanExporterOptions> configure)`.
5. Verify in the AxonPush UI that spans land on the configured channel within a few seconds.

## Cross-Source Correlation

The exporter uses the same JSON envelope as `axonpush` (Python) and `@axonpush/sdk` (TypeScript). When a .NET request is correlated to a Python downstream call via trace propagation (W3C `traceparent`), both sides emit spans with the same `traceId`. The AxonPush UI renders them in one waterfall.

## Fail-Open

By default, the exporter is fail-open: if AxonPush is unreachable, the exception is logged at warning level and the OpenTelemetry SDK is told the export succeeded. Set `AxonPushOptions.FailOpen = false` (or `AXONPUSH_FAIL_OPEN=false`) to surface failures to the SDK so they bubble up as `ExportResult.Failure`.
