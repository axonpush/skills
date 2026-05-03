---
name: ts-langgraph
description: Integrate AxonPush tracing into a TypeScript LangGraph project
---

# AxonPush + LangGraph (TypeScript) Integration

Integrate AxonPush tracing into a TypeScript LangGraph project.

## What gets added

- `AxonPushLangGraphHandler` that extends `AxonPushCallbackHandler` with graph node-level tracing
- Events: `chain.start`, `chain.end`, `graph.node.start`, `graph.node.end`, `llm.start`, `llm.end`, `tool.*.start`, `tool.end`

## Reference Code

```typescript
import { AxonPush } from "@axonpush/sdk";
import { AxonPushLangGraphHandler } from "@axonpush/sdk/integrations/langgraph";

const axonpush = new AxonPush({
  apiKey: process.env.AXONPUSH_API_KEY!,
  tenantId: process.env.AXONPUSH_TENANT_ID!,
  baseUrl: process.env.AXONPUSH_BASE_URL,
});

const handler = new AxonPushLangGraphHandler({
  client: axonpush,
  channelId: Number(process.env.AXONPUSH_CHANNEL_ID),
  agentId: "langgraph-agent",
});

// const result = await graph.invoke(input, { callbacks: [handler] });
```

## Steps

1. Install `@axonpush/sdk` using the project's package manager
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find the main file where the LangGraph graph is invoked
4. Add the imports and client initialization (as module-level code)
5. Add `{ callbacks: [handler] }` to `.invoke()` calls

## Fail-Open

The SDK is fail-open by default (`failOpen: true`). If AxonPush is unreachable, tracing callbacks are silently suppressed.
