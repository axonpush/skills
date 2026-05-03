---
name: ts-mastra
description: Integrate AxonPush tracing into a Mastra project
---

# AxonPush + Mastra Integration

Integrate AxonPush tracing into a project using Mastra.

## What gets added

- `AxonPushMastraHooks` with tool and workflow lifecycle methods
- Events: `tool.*.start`, `tool.*.end`, `workflow.start`, `workflow.end`, `workflow.error`

## Reference Code

```typescript
import { AxonPush } from "@axonpush/sdk";
import { AxonPushMastraHooks } from "@axonpush/sdk/integrations/mastra";

const axonpush = new AxonPush({
  apiKey: process.env.AXONPUSH_API_KEY!,
  tenantId: process.env.AXONPUSH_TENANT_ID!,
  baseUrl: process.env.AXONPUSH_BASE_URL,
});

const hooks = new AxonPushMastraHooks({
  client: axonpush,
  channelId: Number(process.env.AXONPUSH_CHANNEL_ID),
  agentId: "mastra",
});

// In your workflow or agent:
// hooks.onWorkflowStart("my-workflow", input);
// hooks.beforeToolUse("tool-name", input);
// hooks.afterToolUse("tool-name", output);
// hooks.onWorkflowEnd("my-workflow", output);
// hooks.onWorkflowError("my-workflow", error);
```

## Steps

1. Install `@axonpush/sdk` using the project's package manager
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find the main workflow or agent entry point
4. Add imports and create the hooks instance
5. Call the appropriate hook methods at workflow/tool lifecycle points

## Fail-Open

The SDK is fail-open by default (`failOpen: true`). If AxonPush is unreachable, hook calls are silently suppressed.
