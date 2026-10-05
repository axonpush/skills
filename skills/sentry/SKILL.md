---
name: sentry
description: Send an existing Sentry SDK's errors and transactions to axonpush as well, so exceptions land on the same traces as the app's spans and observations. Uses the SENTRY_DSN that workspaces_connect returns. Use only when the project already uses Sentry (Python, TypeScript or .NET).
---

# Sentry diagnostics in axonpush

Use this only when the project already initialises a Sentry SDK. Do not add Sentry just for axonpush. Sentry events are diagnostics; they support the workspace timeline but do not replace `observe` calls for business state.

## The DSN

`workspaces_connect` returns `SENTRY_DSN` in its `env` when the server has Sentry-compatible ingest enabled and the call minted a new key. It has the form `https://<pt_ public ingest token>@<api host>/<number>`. The server routes by the token, which is bound to the workspace's application, a channel and one environment; the number only satisfies Sentry's DSN format. A body environment or project id cannot move events to another binding.

If `sentryDsnUnavailable` explains why there is no DSN (ingest disabled, or the key already existed), either use the OTLP settings from the same response, call `workspaces_connect` again with `rotate: true` (this also replaces the publish key), or create a public ingest token in the dashboard. Never put an `ak_` API key in a DSN.

Write `SENTRY_DSN` to the app's git-ignored env file with the rest of the connect env. Never print or commit it.

## Wire it

Merge the DSN into the existing Sentry initialisation, keeping its filters, sampling and integrations. Do not add a second `init` or replace an existing tracer provider.

Python, existing `sentry-sdk`:

```python
import os
import sentry_sdk

sentry_sdk.init(
    dsn=os.environ["SENTRY_DSN"],
    environment=os.environ.get("AXONPUSH_ENVIRONMENT"),
    send_default_pii=False,
    # keep the project's existing options here
)
```

TypeScript, existing `@sentry/node` (or another Sentry package):

```ts
import * as Sentry from "@sentry/node";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.AXONPUSH_ENVIRONMENT,
  sendDefaultPii: false,
  // keep the project's existing options here
});
```

.NET: set the existing `SentryOptions.Dsn` from `SENTRY_DSN`.

If the project already sends to its own Sentry and should keep doing so, ask the user which destination they want. A Sentry client sends to one DSN.

## Filter at the source

`send_default_pii=False` alone is not enough. Use the SDK's `before_send` / `beforeSend` and breadcrumb hooks so exception messages, request bodies, headers, query strings, user details and attachments never contain prompts, message content, documents, contact details or credentials. Server-side redaction is a second layer, not permission to send content.

## Coverage

The server accepts the envelope and store endpoints (`/api/{projectId}/envelope/` and `/api/{projectId}/store/`). Errors and transactions are mapped; do not promise session replay, profiling or every Sentry feature. Keep W3C `traceparent` propagation across services so Sentry events, OTLP spans and observations join on one trace.

## Verify

Trigger a synthetic error, then find it with `errors_list` or `traces_list` over MCP. Confirm the app behaves the same with the DSN set, unset and pointing at an unreachable host. Report the boundary as verified, wired but unverified, or a gap.
