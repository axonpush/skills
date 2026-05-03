---
name: winston
description: Forward `winston` log records into AxonPush as structured events. Adds an `AxonpushTransport` to the winston logger so existing `logger.info(...)` calls publish events. Use when the Node/TypeScript project uses winston (detected by `winston` in package.json).
---

# AxonPush + winston integration

## Reference (live)

`https://raw.githubusercontent.com/axonpush/axonpush-ts/master/README.md` — "winston" section.

## What gets added

- `AxonpushTransport` from `@axonpush/sdk/integrations/winston` added to the winston logger's transports array.
- Each log record becomes an event with `eventType: "log"`, `identifier: <logger.name>`, `payload: { level, message, ...meta }`.

## Static reference

```ts
import winston from "winston";
import { AxonpushTransport } from "@axonpush/sdk/integrations/winston";

const logger = winston.createLogger({
  level: "info",
  transports: [
    new winston.transports.Console(),
    new AxonpushTransport(),  // reads AXONPUSH_* env vars
  ],
});
```

## Verify

`logger.info("hello from winston", { user: "alice" })` should appear in the dashboard within a few seconds.
