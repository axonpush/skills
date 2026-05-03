---
name: ts-google-adk
description: Integrate AxonPush tracing into a Google ADK project
---

# AxonPush + Google ADK Integration

Integrate AxonPush tracing into a project using the Google AI Development Kit.

## What gets added

- `axonPushADKCallbacks` with agent, model, and tool lifecycle callbacks
- Events: `agent.start`, `agent.end`, `llm.start`, `llm.end`, `tool.*.start`, `tool.*.end`

## Reference Code

```typescript
import { AxonPush } from "@axonpush/sdk";
import { axonPushADKCallbacks } from "@axonpush/sdk/integrations/google-adk";

const axonpush = new AxonPush({
  apiKey: process.env.AXONPUSH_API_KEY!,
  tenantId: process.env.AXONPUSH_TENANT_ID!,
  baseUrl: process.env.AXONPUSH_BASE_URL,
});

const callbacks = axonPushADKCallbacks({
  client: axonpush,
  channelId: Number(process.env.AXONPUSH_CHANNEL_ID),
  agentId: "google-adk",
});

// Register callbacks on your ADK agent:
// callbacks.beforeAgent(agent);
// callbacks.afterAgent(agent, output);
// callbacks.beforeModel(model, params);
// callbacks.afterModel(model, response);
// callbacks.beforeTool(tool, input);
// callbacks.afterTool(tool, output);
```

## Steps

1. Install `@axonpush/sdk` using the project's package manager
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find the main file where the ADK agent is configured
4. Add imports and create the callbacks
5. Register the callbacks at the appropriate lifecycle points

## Fail-Open

The SDK is fail-open by default (`failOpen: true`). If AxonPush is unreachable, callbacks are silently suppressed.
