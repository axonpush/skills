---
name: ts-anthropic
description: Wire axonpush tracing into a TypeScript/Node project that calls the Anthropic SDK (`@anthropic-ai/sdk`, `messages.create`). Use when the user wants to observe Claude conversations, tool use, and tool results from a TypeScript service.
---

## Reference (live)

Before applying this integration, fetch the latest README from the `axonpush/sdks` monorepo to capture any recent API changes:

- Python skills: `https://raw.githubusercontent.com/axonpush/sdks/master/packages/python/README.md`
- TypeScript skills: `https://raw.githubusercontent.com/axonpush/sdks/master/packages/typescript/README.md`

Use the section relevant to this framework. If the fetch fails (offline, rate-limited), use the static reference code below as a fallback.

# axonpush + Anthropic/Claude (TypeScript) Integration

Integrate axonpush tracing into a TypeScript project using the Anthropic SDK.

## What gets added

- `AxonPushAnthropicTracer` that wraps `messages.create()` to trace conversations, tool use, and responses
- Events: `conversation.turn`, `tool.*.start`, `agent.response`, `tool.result`

## Reference Code

```typescript
import { AxonPush } from "@axonpush/sdk";
import { AxonPushAnthropicTracer } from "@axonpush/sdk/integrations/anthropic";

const axonpush = new AxonPush({
  apiKey: process.env.AXONPUSH_API_KEY!,
  tenantId: process.env.AXONPUSH_TENANT_ID!,
  baseUrl: process.env.AXONPUSH_BASE_URL,
});

const tracer = new AxonPushAnthropicTracer({
  client: axonpush,
  channelId: process.env.AXONPUSH_CHANNEL_ID,
  agentId: "claude-agent",
});

// Instead of: const response = await anthropic.messages.create(params)
// Use:        const response = await tracer.createMessage(anthropic, params)

// For tool results:
// tracer.sendToolResult(toolUseId, result)
```

## Steps

1. Install `@axonpush/sdk` with the project's package manager, e.g. `npm install @axonpush/sdk` (or the `pnpm add`/`bun add`/`yarn add` equivalent)
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find files that call `client.messages.create()` (the Anthropic API)
4. Add imports and create the tracer
5. Replace `anthropic.messages.create(params)` with `tracer.createMessage(anthropic, params)`
6. For tool results, add `tracer.sendToolResult(toolUseId, result)` calls

## Fail-Open

The SDK is fail-open by default (`failOpen: true`). If axonpush is unreachable, tracing calls are silently suppressed.
