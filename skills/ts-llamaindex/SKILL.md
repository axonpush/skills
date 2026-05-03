---
name: ts-llamaindex
description: Wire AxonPush tracing into a TypeScript LlamaIndex.ts project via `AxonPushLlamaIndexHandler`. Use when the user wants LLM, embedding, retriever, and query lifecycle events from a query engine or retrieval pipeline.
---

## Reference (live)

Before applying this integration, fetch the latest README from the SDK repo to capture any recent API changes:

- Python skills: `https://raw.githubusercontent.com/axonpush/axonpush-python/master/README.md`
- TypeScript skills: `https://raw.githubusercontent.com/axonpush/axonpush-ts/master/README.md`

Use the section relevant to this framework. If the fetch fails (offline, rate-limited), use the static reference code below as a fallback.

# AxonPush + LlamaIndex (TypeScript) Integration

Integrate AxonPush tracing into a TypeScript LlamaIndex project.

## What gets added

- `AxonPushLlamaIndexHandler` with LLM, embedding, retriever, and query lifecycle methods
- Events: `llm.start`, `llm.end`, `llm.token`, `embedding.start`, `embedding.end`, `retriever.query`, `retriever.result`, `query.start`, `query.end`

## Reference Code

```typescript
import { AxonPush } from "@axonpush/sdk";
import { AxonPushLlamaIndexHandler } from "@axonpush/sdk/integrations/llamaindex";

const axonpush = new AxonPush({
  apiKey: process.env.AXONPUSH_API_KEY!,
  tenantId: process.env.AXONPUSH_TENANT_ID!,
  baseUrl: process.env.AXONPUSH_BASE_URL,
});

const handler = new AxonPushLlamaIndexHandler({
  client: axonpush,
  channelId: Number(process.env.AXONPUSH_CHANNEL_ID),
  agentId: "llamaindex",
});

// Call handler methods at the appropriate points:
// handler.onQueryStart("What is...");
// handler.onLLMStart("gpt-4", 1);
// handler.onLLMEnd(output);
// handler.onRetrieverStart("What is...");
// handler.onRetrieverEnd(5);
// handler.onQueryEnd(response);
```

## Steps

1. Install `@axonpush/sdk` using the project's package manager
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find the main query engine or retrieval pipeline
4. Add imports and create the handler
5. Call the appropriate handler methods at each lifecycle point

## Fail-Open

The SDK is fail-open by default (`failOpen: true`). If AxonPush is unreachable, handler calls are silently suppressed.
