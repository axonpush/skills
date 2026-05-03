---
name: pino
description: Forward `pino` log records into AxonPush as structured events. Adds an `axonpush-pino` transport so existing `logger.info(...)` calls publish events. Use when the Node/TypeScript project uses pino (detected by `pino` in package.json).
---

# AxonPush + pino integration

## Reference (live)

`https://raw.githubusercontent.com/axonpush/axonpush-ts/master/README.md` — "pino" section.

## What gets added

- A pino transport from `@axonpush/sdk/integrations/pino` attached to the existing pino instance.
- Each log record becomes an event with `eventType: "log"`, `identifier: <bindings.name | "log">`, `payload: { level, msg, ...rest }`.

## Static reference

```ts
import pino from "pino";
import { axonpushTransport } from "@axonpush/sdk/integrations/pino";

const logger = pino({
  level: "info",
  transport: axonpushTransport(),  // reads AXONPUSH_* env vars
});
```

## Verify

`logger.info({ event: "test" }, "hello from pino")` should appear in the dashboard within a few seconds.
