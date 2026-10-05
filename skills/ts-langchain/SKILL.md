---
name: ts-langchain
description: Wire axonpush tracing into a TypeScript LangChain.js project via `AxonPushCallbackHandler`. Use when the user wants chain, LLM, and tool lifecycle events from any chain or agent executor invoked with `.invoke()`.
---

## Reference (live)

Before applying this integration, fetch the latest README from the `axonpush/sdks` monorepo to capture any recent API changes:

- Python skills: `https://raw.githubusercontent.com/axonpush/sdks/master/packages/python/README.md`
- TypeScript skills: `https://raw.githubusercontent.com/axonpush/sdks/master/packages/typescript/README.md`

Use the section relevant to this framework. If the fetch fails (offline, rate-limited), use the static reference code below as a fallback.

# axonpush + LangChain (TypeScript) Integration

Integrate axonpush tracing into a TypeScript LangChain project.

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
  channelId: process.env.AXONPUSH_CHANNEL_ID,
  agentId: "my-agent",
});

// For any chain:
// const result = await chain.invoke(input, { callbacks: [handler] });

// For an agent executor:
// const result = await agentExecutor.invoke(input, { callbacks: [handler] });
```

## Steps

1. Install `@axonpush/sdk` with the project's package manager, e.g. `npm install @axonpush/sdk` (or the `pnpm add`/`bun add`/`yarn add` equivalent)
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find the main file where chains/agents are invoked
4. Add the imports and client initialisation (as module-level code)
5. Add `{ callbacks: [handler] }` to `.invoke()` calls

## Fail-Open

The SDK is fail-open by default (`failOpen: true`). If axonpush is unreachable, tracing callbacks are silently suppressed.
