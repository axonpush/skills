---
name: ts-openai-agents
description: Wire axonpush tracing into a TypeScript project that uses the OpenAI Agents SDK (`Runner.run`). Use when the user wants agent run, tool, and handoff events.
---

## Reference (live)

Before applying this integration, fetch the latest README from the `axonpush/sdks` monorepo to capture any recent API changes:

- Python skills: `https://raw.githubusercontent.com/axonpush/sdks/master/packages/python/README.md`
- TypeScript skills: `https://raw.githubusercontent.com/axonpush/sdks/master/packages/typescript/README.md`

Use the section relevant to this framework. If the fetch fails (offline, rate-limited), use the static reference code below as a fallback.

# axonpush + OpenAI Agents SDK (TypeScript) Integration

Integrate axonpush tracing into a TypeScript project using the OpenAI Agents SDK.

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
  channelId: process.env.AXONPUSH_CHANNEL_ID,
});

// const result = await Runner.run(agent, input, { hooks });
```

## Steps

1. Install `@axonpush/sdk` with the project's package manager, e.g. `npm install @axonpush/sdk` (or the `pnpm add`/`bun add`/`yarn add` equivalent)
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find the main file where Runner.run() is called
4. Add the imports and axonpush client initialisation
5. Pass `hooks` to `Runner.run()`

## Fail-Open

The SDK is fail-open by default (`failOpen: true`). If axonpush is unreachable, tracing hooks are silently suppressed.
