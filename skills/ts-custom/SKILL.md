---
name: ts-custom
description: Send business observations and profile traits from a TypeScript/Node project to an axonpush workspace with `observe()` and `identify()`. Use for committed state transitions, joins, waits and outcomes that no framework integration captures, or when no supported framework applies.
---

## Reference (live)

Before applying this integration, fetch the latest SDK README to capture recent API changes:

- `https://raw.githubusercontent.com/axonpush/sdks/master/packages/typescript/README.md`

If the fetch fails, use the reference code below.

# TypeScript observations

`observe()` sends a metadata-only observation to a workspace. The workspace spec decides what it means: each entity whose type appears in `refs` and has a rule matching the event stores its declared fields from `attributes`, then applies the rule's `set` literals. `identify()` attaches profile traits (names, plans) to an entity.

The event names, ref types and attribute keys must exist in the workspace spec. Undeclared attribute keys are dropped and listed in the report's `dropped`. Build or extend the spec first with `axonpush-integrate` or `axonpush-tailor-dashboard`.

## Reference code

```typescript
import { AxonPush } from "@axonpush/sdk";

const axonpush = new AxonPush(); // reads AXONPUSH_API_KEY, AXONPUSH_BASE_URL and AXONPUSH_ENVIRONMENT
const workspace = process.env.AXONPUSH_WORKSPACE_ID!;

await axonpush.observe(workspace, {
  event: "ticket.solved",
  refs: { ticket: ticket.id, agent: agent.id },
  attributes: { status: "solved", handle_ms: handleMs },
  sourceEventId: `ticket:${ticket.id}:rev:${ticket.revision}`,
});

await axonpush.identify(workspace, {
  entity: "customer",
  id: customer.id,
  traits: { display_name: customer.name, plan: null },
});
```

`observe` also takes `occurredAt`, `traceId`, `spanId`, `environment`, `snapshot` and `source` (`{ ref, revision }`), and accepts an array, sent in batches of 100. `identify` merges traits restricted to the entity's `profile` keys, and `null` deletes a trait. `group` is the same call, for company-like entities.

## Steps

1. Install `@axonpush/sdk` with the project's package manager (`npm install @axonpush/sdk`, or the `pnpm`, `bun` or `yarn` equivalent). If the installed version has no `observe` method, build the package from `axonpush/sdks` (`packages/typescript`, `dev` branch) or post to `POST /workspaces/{workspaceId}/observations` with the `x-axonpush-api-key` header.
2. Make sure `AXONPUSH_API_KEY`, `AXONPUSH_BASE_URL`, `AXONPUSH_WORKSPACE_ID` and `AXONPUSH_ENVIRONMENT` are in the app's git-ignored env file. `workspaces_connect` returns them; do not ask the user to copy keys.
3. Create the client once at module level.
4. Call `observe` where each declared transition is committed, after the transaction commits, and `identify` where profile data changes.
5. Send one test observation and confirm it in `workspaces_catalog` or `activity_timeline`.

## Rules

- Metadata only: opaque ids, bounded enum values, numbers, durations and timestamps. Never send prompts, model output, message bodies, tool arguments or results, documents, credentials, full URLs or raw exception text. Personal values belong only in attributes declared `personal: true`.
- Reuse a stable `sourceEventId` when the same fact may be retried, and pass the original `occurredAt` when sending late, so duplicates and late deliveries do not distort state.
- Use `snapshot: true` when seeding current state from existing records. Snapshots update state without counting as activity or funnel progress.
- Never call axonpush inside a business transaction, and never let a failed export change the response. For must-not-lose transitions, send from an outbox or background worker with retries.

## Fail-open

The SDK is fail-open by default (`failOpen: true`). If axonpush is unreachable, `observe` and `identify` resolve to `null` instead of throwing, so the application keeps working.
