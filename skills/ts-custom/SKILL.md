---
name: ts-custom
description: Wire direct AxonPush event publishing into a TypeScript/Node project that does not use a supported framework. Use when no specific framework integration applies and the user wants to emit custom events with `axonpush.events.publish()`.
---

## Reference (live)

Before applying this integration, fetch the latest README from the SDK repo to capture any recent API changes:

- Python skills: `https://raw.githubusercontent.com/axonpush/axonpush-python/master/README.md`
- TypeScript skills: `https://raw.githubusercontent.com/axonpush/axonpush-ts/master/README.md`

Use the section relevant to this framework. If the fetch fails (offline, rate-limited), use the static reference code below as a fallback.

# AxonPush Custom Framework Integration (TypeScript)

Integrate AxonPush event publishing directly for custom or unsupported TypeScript frameworks.

## What gets added

- `AxonPush` client for publishing custom events
- Use `client.events.publish()` to send events from anywhere in your code

## Reference Code

```typescript
import { AxonPush } from "@axonpush/sdk";

const axonpush = new AxonPush({
  apiKey: process.env.AXONPUSH_API_KEY!,
  tenantId: process.env.AXONPUSH_TENANT_ID!,
  baseUrl: process.env.AXONPUSH_BASE_URL,
});

// Publish events from your code:
// await axonpush.events.publish({
//   identifier: "my.event",
//   payload: { key: "value" },
//   channelId: Number(process.env.AXONPUSH_CHANNEL_ID),
//   agentId: "my-agent",
//   eventType: "custom",
// });
```

## Steps

1. Install `@axonpush/sdk` using the project's package manager
2. Add AXONPUSH_API_KEY, AXONPUSH_TENANT_ID, AXONPUSH_BASE_URL, AXONPUSH_CHANNEL_ID to .env
3. Find the main entry point of the project
4. Add imports and create the client as a module-level singleton
5. Add example publish calls at key points (e.g., start, end, error handling)

## Fail-Open

The SDK is fail-open by default (`failOpen: true`). If AxonPush is unreachable, publish calls are silently suppressed.
