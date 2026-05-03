---
name: ts-llamaindex
description: Integrate AxonPush tracing into a TypeScript LlamaIndex project
---

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
