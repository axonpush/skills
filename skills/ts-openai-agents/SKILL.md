---
name: ts-openai-agents
description: Wire AxonPush tracing into a TypeScript project that uses the OpenAI Agents SDK (`Runner.run`). Use when the user wants agent run, tool, and handoff events.
---

## Reference (live)

Before applying this integration, fetch the latest README from the SDK repo to capture any recent API changes:

- Python skills: `https://raw.githubusercontent.com/axonpush/axonpush-python/master/README.md`
- TypeScript skills: `https://raw.githubusercontent.com/axonpush/axonpush-ts/master/README.md`

Use the section relevant to this framework. If the fetch fails (offline, rate-limited), use the static reference code below as a fallback.

# AxonPush + OpenAI Agents SDK (TypeScript) Integration

Integrate AxonPush tracing into a TypeScript project using the OpenAI Agents SDK.

## What gets added

- `AxonPushRunHooks` that traces agent runs, tool calls, and handoffs
- Events: `agent.run.start`, `agent.run.end`, `tool.*.start`, `tool.*.end`, `agent.handoff`

## Reference Code

```typescript
import { AxonPush } from "@axonpush/sdk";
import { AxonPushRunHooks } from "@axonpush/sdk/integrations/openai-agents";

const axonpush = new AxonPush({
  apiKey: process.env.AXONPUSH_API_KEY!,
  tenantId: process.env.AXONPUSH_TENANT_ID!,
  baseUrl: process.env.AXONPUSH_BASE_URL,
});

const hooks = new AxonPushRunHooks({
  client: axonpush,
  channelId: Number(process.env.AXONPUSH_CHANNEL_ID),
});

// const result = await Runner.run(agent, input, { hooks });
```

## Steps

1. Install `@axonpush/sdk` using the project's package manager
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find the main file where Runner.run() is called
4. Add the imports and AxonPush client initialization
5. Pass `hooks` to `Runner.run()`

## Fail-Open

The SDK is fail-open by default (`failOpen: true`). If AxonPush is unreachable, tracing hooks are silently suppressed.
