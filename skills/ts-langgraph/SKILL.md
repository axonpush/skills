---
name: ts-langgraph
description: Wire axonpush tracing into a TypeScript LangGraph.js project via `AxonPushLangGraphHandler`, including per-node graph events on top of the standard chain/LLM/tool lifecycle. Use when the user wants graph node-level observability.
---

## Reference (live)

Before applying this integration, fetch the latest README from the `axonpush/sdks` monorepo to capture any recent API changes:

- Python skills: `https://raw.githubusercontent.com/axonpush/sdks/master/packages/python/README.md`
- TypeScript skills: `https://raw.githubusercontent.com/axonpush/sdks/master/packages/typescript/README.md`

Use the section relevant to this framework. If the fetch fails (offline, rate-limited), use the static reference code below as a fallback.

# axonpush + LangGraph (TypeScript) Integration

Integrate axonpush tracing into a TypeScript LangGraph project.

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
  channelId: process.env.AXONPUSH_CHANNEL_ID,
  agentId: "langgraph-agent",
});

// const result = await graph.invoke(input, { callbacks: [handler] });
```

## Steps

1. Install `@axonpush/sdk` with the project's package manager, e.g. `npm install @axonpush/sdk` (or the `pnpm add`/`bun add`/`yarn add` equivalent)
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find the main file where the LangGraph graph is invoked
4. Add the imports and client initialisation (as module-level code)
5. Add `{ callbacks: [handler] }` to `.invoke()` calls

## Fail-Open

The SDK is fail-open by default (`failOpen: true`). If axonpush is unreachable, tracing callbacks are silently suppressed.
