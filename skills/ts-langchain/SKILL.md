---
name: ts-langchain
description: Integrate AxonPush tracing into a TypeScript LangChain project
---

# AxonPush + LangChain (TypeScript) Integration

Integrate AxonPush tracing into a TypeScript LangChain project.

## What gets added

- `AxonPushCallbackHandler` that auto-traces chain/LLM/tool lifecycle events
- Events: `chain.start`, `chain.end`, `llm.start`, `llm.end`, `tool.*.start`, `tool.end`

## Reference Code

```typescript
import { AxonPush } from "@axonpush/sdk";
import { AxonPushCallbackHandler } from "@axonpush/sdk/integrations/langchain";

const axonpush = new AxonPush({
  apiKey: process.env.AXONPUSH_API_KEY!,
  tenantId: process.env.AXONPUSH_TENANT_ID!,
  baseUrl: process.env.AXONPUSH_BASE_URL,
});

const handler = new AxonPushCallbackHandler({
  client: axonpush,
  channelId: Number(process.env.AXONPUSH_CHANNEL_ID),
  agentId: "my-agent",
});

// For any chain:
// const result = await chain.invoke(input, { callbacks: [handler] });

// For an agent executor:
// const result = await agentExecutor.invoke(input, { callbacks: [handler] });
```

## Steps

1. Install `@axonpush/sdk` using the project's package manager
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find the main file where chains/agents are invoked
4. Add the imports and client initialization (as module-level code)
5. Add `{ callbacks: [handler] }` to `.invoke()` calls

## Fail-Open

The SDK is fail-open by default (`failOpen: true`). If AxonPush is unreachable, tracing callbacks are silently suppressed.
