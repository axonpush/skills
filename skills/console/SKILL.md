---
name: console
description: Forward Node/TypeScript `console.*` calls (log/info/warn/error/debug) into AxonPush as structured events. Adds an `attachConsole()` patch that wraps the global console without breaking existing logs. Use when the project has no dedicated logger and relies on `console.*` (detected as the fallback when no other log library is in package.json).
---

# AxonPush + console integration

## Reference (live)

`https://raw.githubusercontent.com/axonpush/axonpush-ts/master/README.md` — "console" section.

## What gets added

- `attachConsole()` from `@axonpush/sdk/integrations/console` patches `console.log/info/warn/error/debug`.
- Original console output is preserved; AxonPush gets a copy as an event with `eventType: "log"`, `identifier: console`, `payload: { level, args }`.

## Static reference

```ts
import { attachConsole } from "@axonpush/sdk/integrations/console";

attachConsole();  // reads AXONPUSH_* env vars; idempotent (re-calls are no-ops)
```

Place this at the top of the entry file (e.g. `src/index.ts`, `src/main.ts`) so it runs before any `console.*` call.

## Verify

`console.log("hello from console")` should appear in the dashboard within a few seconds.
