---
name: sentry
description: Point an existing Sentry SDK at axonpush by changing the DSN, so exceptions, issues, transactions and logs land on the same trace as gateway and OTLP telemetry. Use when the project already runs a Sentry SDK (Python sentry-sdk, @sentry/node or @sentry/browser, or the .NET Sentry SDK) and the user wants those errors and spans in axonpush with no code rewrite.
---

# axonpush Sentry DSN ingest

If a Sentry client is already in the project, axonpush can be the endpoint it posts to. The DSN is the only thing that changes. Exceptions become `agent.error` events, transactions become `app.span` events, and Sentry logs become `app.log` events, all on the same timeline as gateway spans and OTLP spans.

Prefer this path when the project already has Sentry wired. Do not add Sentry to a project that has none just to get errors into axonpush. For a project without Sentry, errors already flow through the gateway pillar (failed provider calls) and the framework sub-skills (`agent.error` on exceptions), and OTLP carries span status.

## Before you start: is ingest enabled?

Sentry ingest is behind the `SENTRY_INGEST_ENABLED` server flag. It is **on by default on axonpush cloud** (`api.axonpush.xyz`) and in the default self-host and CDK config. On a deployment where it has been turned off, the envelope routes return `404`/`403`. If envelopes vanish and the DSN looks right, check the deployment's capabilities document (`GET /capabilities` → `featureFlags.sentryIngest`) first.

## DSN format

```
SENTRY_DSN=https://<key>@api.axonpush.xyz/<channelId>
```

- **`<key>`** is an axonpush API key (`ak_…`) or public ingest token (`pt_…`). Use a `pt_…` token in browser and mobile clients, because an `ak_…` key shipped to a client is a key everyone can read.
- **`<channelId>`** is the axonpush channel the events land in. It occupies the slot Sentry calls the project id, and it is an opaque string, not a number.
- Self-host: swap the host for the tenant's base URL, keeping the `@host/<channelId>` shape.

The channel-scoped `pt_…` token is also immune to the environment trap described below, so it is the safer default for anything that runs outside your servers.

## Wiring it up

The Python and TypeScript SDKs each ship a helper that builds the DSN and forwards every other option through to `sentry_sdk.init` / `Sentry.init` untouched, so nothing about the existing Sentry configuration has to change. Both fall back to `AXONPUSH_API_KEY`, `AXONPUSH_CHANNEL_ID` and `AXONPUSH_HOST` when an argument is omitted.

**Python** (`axonpush` from PyPI, or the helper wrapping the project's existing `sentry-sdk`):

```python
from axonpush.integrations.sentry import install_sentry

install_sentry(
    api_key=os.environ["AXONPUSH_API_KEY"],
    channel_id=os.environ["AXONPUSH_CHANNEL_ID"],
    environment="prod",          # match an axonpush environment slug, see below
    traces_sample_rate=0.2,
)
```

**Python without the axonpush package** (only the DSN changes):

```python
import sentry_sdk

sentry_sdk.init(
    dsn=os.environ["SENTRY_DSN"],  # https://ak_...@api.axonpush.xyz/<channelId>
    environment="prod",
    traces_sample_rate=0.2,
)
```

**TypeScript** (`@axonpush/sdk` from npm, wrapping the project's `@sentry/node` or `@sentry/browser`):

```ts
import * as Sentry from "@sentry/node";
import { installSentry } from "@axonpush/sdk/integrations/sentry";

installSentry(Sentry, {
  apiKey: process.env.AXONPUSH_API_KEY,
  channelId: process.env.AXONPUSH_CHANNEL_ID,
  environment: "prod",
  tracesSampleRate: 0.2,
});
```

**.NET** has no axonpush helper. Point `SentryOptions.Dsn` at the DSN above directly.

## Routes that work

The shipped Go server mounts the two endpoints modern and legacy Sentry SDKs actually use: `POST /api/{channelId}/envelope/` (the modern protocol: events, transactions, sessions, check-ins, attachments) and `POST /api/{channelId}/store/` (the legacy single-event endpoint). Both take the trailing slash the SDKs send. Envelopes over 6 MB are rejected with `413`. The standard SDK setup uses the envelope route, so no configuration change is needed. (The docs also describe `security` and `minidump` routes; those are not mounted in the current Go build, so browser CSP-report and native-minidump posting is not available yet. Do not promise it.)

The key is read from `X-Sentry-Auth`, then `Authorization: DSN <dsn>`, then `?sentry_key=` (CDN browser builds), first match wins.

## What maps, and what does not

| Sentry item | axonpush event | Notes |
|---|---|---|
| `event` with exceptions | `agent.error` | Grouped into issues. |
| `event` without exceptions | `app.log` | `level` maps to OTel severity, so it sorts against Pino/Winston/stdlib logs. |
| `transaction` | `app.span` | One event for the transaction plus one per child span. |
| `check_in` / `session` | `custom` | Tagged in `metadata.sentryItemType`. |
| `attachment` | `app.log` | Base64, capped at 1 MiB then truncated. |

(`csp-report` and `minidump` have mapping logic but arrive only over the `security` / `minidump` routes, which are not mounted in the current build.)

**Be honest about the gaps.** These item types are accepted with a `200` (so the SDK does not retry) but dropped as `not-mapped`: `client_report`, `statsd`, `profile`, `profile_chunk`, `replay_event`, `replay_recording`. That means **Sentry session replay and profiling are not ingested by axonpush today**. Sentry *user feedback* arrives as a normal event through the envelope route and is captured. Browser CSP reports use the separate `security` route, which is not mounted in the current build, so those are not captured either. Do not tell the user replay, profiling, or CSP reports will show up. If they rely on replay, they keep it pointed at Sentry and use axonpush for everything else, both DSNs can run side by side.

## The environment trap

The `environment` field on a Sentry event is treated as an environment **override**, exactly like the `X-Axonpush-Environment` header. An `ak_…` key pinned to `prod` (without `allowEnvironmentOverride`) that receives a *different* slug returns `400 env_override_forbidden`, and Sentry SDKs send `environment` by default. In a Node process `installSentry` will fill it from `NODE_ENV`, so a key pinned to `prod` where `NODE_ENV=production` fails on every request, because `production` is not the slug `prod`.

Three fixes, in order of preference:

1. Set the Sentry client's `environment` to the exact axonpush slug (`prod`, `dev`, `staging`).
2. Leave `environment` unset and let the key decide.
3. Use a `pt_…` public token, which pins one environment and ignores the event's `environment` outright.

An unknown slug returns `400 unknown_environment` with the known slugs in the body.

## Correlation with gateway and OTel

`contexts.trace.trace_id` and `contexts.trace.span_id` are lifted onto the event, so a Sentry exception and a gateway or OTLP span from the same request join into one trace. For that to work, the request must carry a shared trace context: keep Sentry's tracing on (`traces_sample_rate` > 0) and, where the code crosses a process boundary, propagate the W3C `traceparent` so every pillar stamps the same trace id. Then one failed run shows the provider call, the surrounding spans, and the exception together in Observe.

## Verify

Trigger one real exception (or `sentry_sdk.capture_message("axonpush test")` / `Sentry.captureException(new Error("axonpush test"))`) and confirm it lands:

- In the dashboard, open the app's Observe / issues view and look for the new `agent.error`.
- A `200` with `{ "id": "…" }` from the ingest means it was accepted. A `403` "sentry ingest is not enabled" means the server flag is off; a `400 env_override_forbidden` means the environment trap above; a `401` means the DSN key is wrong.

If the SDK reports success but nothing appears, the cause is almost always the environment override or a DSN whose `<channelId>` slot is empty or wrong.
