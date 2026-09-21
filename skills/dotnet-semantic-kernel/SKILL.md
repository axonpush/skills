---
name: dotnet-semantic-kernel
description: Wire AxonPush tracing into a .NET Microsoft Semantic Kernel project via `AddAxonPushTelemetry`. Use when the user wants chat-completion, function-call, and prompt-render lifecycle events from a kernel built with `Kernel.CreateBuilder()` or `Host.CreateApplicationBuilder()`.
---

## Reference (live)

Before applying this integration, fetch the latest README from the SDK repo to capture any recent API changes:

- `https://raw.githubusercontent.com/AxonPush/axonpush-dotnet/main/README.md`

If the fetch fails (offline or rate-limited), fall back to the reference code below.

# AxonPush + Microsoft Semantic Kernel integration

Integrate AxonPush tracing into a .NET Semantic Kernel project.

## What gets added

- `AxonPushKernelBuilderExtensions.AddAxonPushTelemetry` on `IKernelBuilder` and a sibling extension on `IServiceCollection`.
- Two `AppContext` switches flipped: `Microsoft.SemanticKernel.Experimental.GenAI.EnableOTelDiagnostics` and (when sensitive-data export is opted in) `...EnableOTelDiagnosticsSensitive`.
- A registered `TracerProvider` listening to every `Microsoft.SemanticKernel.*` activity source, with the AxonPush exporter attached via a `BatchActivityExportProcessor`.
- Spans: `Kernel.InvokeAsync`, `chat.completions <model>` from the OpenAI or Azure OpenAI connector, plus a span per kernel function call. Each carries the OpenTelemetry GenAI semantic-convention attributes (`gen_ai.system`, `gen_ai.request.model`, `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`, `gen_ai.response.finish_reasons`).

## Install

```bash
dotnet add package AxonPush.SemanticKernel
```

This pulls in `AxonPush` and `AxonPush.Otel` transitively.

## Reference Code

```csharp
using Microsoft.SemanticKernel;
using AxonPush.SemanticKernel;

var builder = Kernel.CreateBuilder();

builder.AddAzureOpenAIChatCompletion(
    deploymentName: Environment.GetEnvironmentVariable("AZURE_OPENAI_DEPLOYMENT")!,
    endpoint: Environment.GetEnvironmentVariable("AZURE_OPENAI_ENDPOINT")!,
    apiKey: Environment.GetEnvironmentVariable("AZURE_OPENAI_API_KEY")!);

builder.AddAxonPushTelemetry(
    client =>
    {
        client.ApiKey = Environment.GetEnvironmentVariable("AXONPUSH_API_KEY")!;
        client.TenantId = Environment.GetEnvironmentVariable("AXONPUSH_TENANT_ID")!;
        client.Environment = Environment.GetEnvironmentVariable("AXONPUSH_ENVIRONMENT") ?? "development";
    },
    exporter =>
    {
        exporter.ChannelId = Environment.GetEnvironmentVariable("AXONPUSH_CHANNEL_ID")!;
        exporter.ServiceName = "my-semantic-kernel-app";
    });

var kernel = builder.Build();
```

In a hosted app (`Host.CreateApplicationBuilder`), use the sibling extension on `IServiceCollection`:

```csharp
builder.Services.AddAxonPushTelemetryForSemanticKernel(
    client => { /* ... */ },
    exporter => { /* ... */ });
```

To forward prompts and completions as span events (sensitive), opt in explicitly:

```csharp
builder.AddAxonPushTelemetry(client => { /* ... */ }, exporter => { /* ... */ }, enableSensitiveData: true);
```

## Steps

1. Add the NuGet package: `dotnet add package AxonPush.SemanticKernel`.
2. Add `AXONPUSH_API_KEY`, `AXONPUSH_TENANT_ID`, `AXONPUSH_CHANNEL_ID`, and (optionally) `AXONPUSH_ENVIRONMENT` to the project's secret store. Use `dotnet user-secrets` locally and the host's secret manager (Azure Key Vault, etc.) in production.
3. Call `builder.AddAxonPushTelemetry(...)` in the same place that constructs the kernel. Do this before any kernel function is invoked so the GenAI diagnostic switches are set before Semantic Kernel JITs its diagnostic helpers.
4. Verify in the AxonPush UI that spans land on the configured channel within a few seconds of running a chat completion.
5. Decide whether to enable sensitive-data export. Off by default; only flip it on for environments where it is safe to log raw prompts and completions.

## Cross-Source Correlation (when both `dotnet-semantic-kernel` and `dotnet-otel` skills are applied)

`AddAxonPushTelemetry` registers a `TracerProvider`. If the host already configures one (for ASP.NET Core, EF Core, HttpClient instrumentation, etc.) you have two providers, and the SK activity source needs to be attached to whichever provider you want to receive its spans.

Recommended setup: call `AddAxonPushExporter` on your existing `TracerProviderBuilder` and add `"Microsoft.SemanticKernel*"` to its `AddSource` list, instead of calling `AddAxonPushTelemetry`. The Semantic Kernel switch needs to be flipped manually in that case:

```csharp
AppContext.SetSwitch("Microsoft.SemanticKernel.Experimental.GenAI.EnableOTelDiagnostics", true);

using var tracerProvider = Sdk.CreateTracerProviderBuilder()
    .AddSource("Microsoft.SemanticKernel*")
    .AddAspNetCoreInstrumentation()
    .AddHttpClientInstrumentation()
    .AddAxonPushExporter(client => { /* ... */ }, exporter => { /* ... */ })
    .Build();
```

Trace identifiers propagate naturally, so an HTTP request span and the Semantic Kernel spans rendered from inside it appear in one waterfall in the AxonPush UI.

## Fail-Open

The exporter is fail-open by default. If AxonPush is unreachable, export failures are logged at warning level and the OpenTelemetry SDK is told the export succeeded, so the kernel keeps responding to prompts. Set `AXONPUSH_FAIL_OPEN=false` (or `AxonPushOptions.FailOpen = false` in code) to surface failures to callers.
