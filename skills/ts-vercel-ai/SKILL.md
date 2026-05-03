---
name: ts-vercel-ai
description: Integrate AxonPush tracing into a Vercel AI SDK project
---

# AxonPush + Vercel AI SDK Integration

Integrate AxonPush tracing into a project using the Vercel AI SDK.

## What gets added

- `axonPushMiddleware` that wraps generateText/streamText with tracing
- Events: `llm.start`, `llm.end`, `llm.token` (streaming)

## Reference Code

```typescript
import { AxonPush } from "@axonpush/sdk";
import { axonPushMiddleware } from "@axonpush/sdk/integrations/vercel-ai";
import { generateText, streamText, wrapLanguageModel } from "ai";

const axonpush = new AxonPush({
  apiKey: process.env.AXONPUSH_API_KEY!,
  tenantId: process.env.AXONPUSH_TENANT_ID!,
  baseUrl: process.env.AXONPUSH_BASE_URL,
});

const middleware = axonPushMiddleware({
  client: axonpush,
  channelId: Number(process.env.AXONPUSH_CHANNEL_ID),
  agentId: "vercel-ai",
});

// Option A: wrap the model
// const tracedModel = wrapLanguageModel({ model: openai("gpt-4o"), middleware });
// const result = await generateText({ model: tracedModel, prompt: "..." });

// Option B: pass middleware directly (if supported)
// const result = await generateText({ model, prompt: "...", experimental_telemetry: { middleware } });
```

## Steps

1. Install `@axonpush/sdk` using the project's package manager
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find files that call `generateText()` or `streamText()`
4. Add imports and create the middleware
5. Wrap the language model using `wrapLanguageModel({ model, middleware })`

## Fail-Open

The SDK is fail-open by default (`failOpen: true`). If AxonPush is unreachable, the middleware passes through without tracing.
