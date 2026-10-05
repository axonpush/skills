---
name: axonpush-integrate
description: Set up axonpush in the current project. Connects the axonpush MCP, reads what the app already sends, builds the workspace spec (data dictionary, entities, views, funnels, alerts) through the shared draft, activates it, then calls workspaces_connect to mint a publish-only key and write the app's env, and adds observe/identify calls plus OTLP, framework or Sentry telemetry. Use when the user asks to "set up axonpush", "add tracing", "integrate axonpush" or "instrument this app".
---

# Integrate axonpush

axonpush is passive, metadata-only observability for agent and business operations. It records what happened (opaque ids, bounded states, outcomes, timings) and shows it in a workspace built for this application. It never sits in the request path: do not reroute model calls, add approval or blocking steps, or change auth, permissions, responses or side effects. The source application stays the authority for identity and decisions.

Nothing is domain-hardcoded. Each installation declares its own spec. Templates (for example Nova, a hiring room, and a support desk) are only starting points.

## 1. Connect the axonpush MCP

Every step below runs through the axonpush MCP. If its tools (`workspaces_describe` and friends) are not available, ask the user to connect it and stop until they have:

```bash
claude mcp add --transport http axonpush https://api.axonpush.xyz/mcp
```

The first tool call opens an OAuth consent page in the browser. Other clients (Cursor, Codex) are listed on the dashboard's Connect page. For self-hosted or local servers, use that server's `/mcp` URL. MCP tool names are the HTTP operation ids with dots replaced by underscores (`workspaces.describe` becomes `workspaces_describe`).

Do not ask the user to copy API keys, app ids or channel ids from the dashboard. `workspaces_connect` (step 5) provides them.

## 2. Pick the workspace

Call `workspaces_list`. The dashboard's onboarding usually creates a pending workspace for the user's application; adopt it. Otherwise call `apps_list` (or `apps_create`) and then `workspaces_create` with `{"appId": "...", "spec": {"name": "..."}}`. A blank spec leaves the workspace pending, with the spec held in the shared draft. `templates_list` returns public and organisation-private templates; offer one only when it genuinely fits the domain.

## 3. Read the evidence and the code

Call `workspaces_describe` first. It returns a plain-language summary of the workspace, the setup steps, the full spec and observation format, the attribute roles and the draft op catalogue with examples. Follow it over anything in this file if they differ. `workspaces_schema` returns the JSON Schema.

Call `workspaces_catalog` to see what the app already sends: event names with counts, refs, attribute keys seen (declared and undeclared) and which entities consume each event. An empty catalogue is normal for a new app.

Then read the codebase. `helpers/detect.sh <dir>` summarises language, package manager, AI frameworks, log libraries, provider clients and Sentry, but it is not a coverage proof. Look for:

- the things worth tracking (agents, conversations, tickets, orders, candidates, jobs) and their stable ids
- committed state transitions and where they happen (handlers, services, workers)
- join and sign-in paths, tool calls, background jobs and waits on a human or another party
- who acts on each side of the business, and which client or agent framework they use
- any attribute that identifies a person (names, emails, avatars)

Actions an external agent takes privately on its own machine are not observable; only what passes through this app is.

## 4. Build the spec in the shared draft

The draft is shared with the dashboard editor, so the user can watch it fill in and edit it too. Never rewrite the spec blindly.

1. `workspaces_draft` reads the draft (created from the active spec on first read) and its `version`.
2. `workspaces_applyDraftOps` sends `{"version": N, "ops": [...]}`. Ops apply in order, all or nothing, and the response carries the new version and validation issues. On 409 the error body holds the current draft: re-read it and reapply. `workspaces_replaceDraft` replaces the whole spec with the same version check.
3. `workspaces_draftChanges` lists, in plain language, what the draft changes against the active spec.

The spec has these parts (`workspaces_describe` has the full reference):

- `attributes`: the data dictionary. Each has a `key`, `type` (`text`, `number`, `duration` in ms, `time`, `enum`, `ref`, `bool`), optional `role`, `personal`, `values`, `scope`, and for outcomes `failure`, `expected` and `pending`. A `ref` can name the `entity` it points at. Undeclared keys are dropped at ingest and counted.
- `entities`: each has a `type`, `fields` (attribute keys it stores), `profile` (keys `identify` may set), `terminal` states and `events` rules. A rule has a `match` (exact name or prefix ending in `*`), literal `set` values, and optionally `only`, `passive`, `erase` and a timeline `label`.
- `views`: `kpi`, `timeseries`, `breakdown`, `funnel`, `latency`, `directory`, `health`, `rate`, `interval` and `graph`.
- `funnels` over an entity's states, and `alerts` that fire when entities stay in a state or match a filter for too long.

Use roles (`state`, `outcome`, `client`, `actor_side`, `duration`, `expected_duration`, `next_actor`, `wait_reason`, `display_name` and the rest) so the generic views, funnels and alerts can read the data. Mark anything that identifies a person `personal: true` and explain each personal attribute to the user before activation; personal values are masked unless the reader is an owner or admin or holds `profiles:read`. Mark the attribute that separates customers or tenants (for example a company ref) `scope: true` if people outside the organisation will need restricted access later; access grants (`workspaces_createAccessGrant`) then limit a member or API key to records carrying granted values.

Keep every value metadata: opaque ids, bounded enums, numbers and timestamps. Never send prompts, model output, hidden reasoning, tool arguments or results, message bodies, documents, credentials, contact details in non-personal attributes, full URLs or raw exception text. The server rejects email addresses in non-personal text and scans every value for credentials, but the allowlist belongs in the source.

## 5. Activate and connect

Ask the user to review the draft and activate it in the dashboard, or call `workspaces_activateDraft` if they approve in the chat. It saves an immutable revision and rebuilds projections in the background; it returns 422 with the issues if validation fails. Poll `workspaces_get` until `activeRevision` matches.

Then call `workspaces_connect` (optionally with `environment`, and `purpose` such as `web` or `worker` to keep separate keys per process). It mints a key scoped only to `events:publish`, bound to this workspace's application and one environment, and returns `env` (`AXONPUSH_API_KEY`, `AXONPUSH_BASE_URL`, `AXONPUSH_WORKSPACE_ID`, `AXONPUSH_ENVIRONMENT`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_HEADERS` and `SENTRY_DSN` when available), plus OTLP settings and SDK snippets. The secret appears only in the response that mints it. Calling again returns the existing key's metadata without the secret; `rotate: true` revokes it and mints a new one.

Write `env` straight into the app's git-ignored env file (`.env.local` or the project's secret convention). `helpers/env.sh KEY=value ...` merges keys idempotently into `.env.local` or `.env`; check the file is ignored. Never commit, print or paste the key.

## 6. Instrument the app

Business state goes through `observe` and profiles through `identify`, using the SDK and the env written above:

```python
import os
from axonpush import AxonPush

axonpush = AxonPush()  # reads AXONPUSH_API_KEY, AXONPUSH_BASE_URL and AXONPUSH_ENVIRONMENT
WORKSPACE = os.environ["AXONPUSH_WORKSPACE_ID"]

axonpush.observe(WORKSPACE, "ticket.solved", refs={"ticket": ticket.id}, attributes={"status": "solved"})
axonpush.identify(WORKSPACE, "customer", customer.id, {"display_name": customer.name})
```

```ts
import { AxonPush } from "@axonpush/sdk";

const axonpush = new AxonPush();
const workspace = process.env.AXONPUSH_WORKSPACE_ID!;

await axonpush.observe(workspace, { event: "ticket.solved", refs: { ticket: ticket.id }, attributes: { status: "solved" } });
await axonpush.identify(workspace, { entity: "customer", id: customer.id, traits: { display_name: customer.name } });
```

`observe` fills `schema_version`, a UUID `source_event_id` and `occurred_at` when absent; pass a stable `source_event_id` when the same transition can be retried, and the original `occurred_at` when sending late. Use `snapshot=True` when seeding current state, so it updates state without counting as activity. `identify` merges traits restricted to the entity's `profile`; `null` deletes a trait (`group` is the same call, for company-like entities). The `custom` and `ts-custom` skills cover this in detail. If the installed SDK has no `observe`, follow the `custom` skill's install note or post to `POST /workspaces/{id}/observations`.

Emit observations after the source transaction commits, never inside it, and never let a failed export change the request. The SDK is fail-open. For high-volume or must-not-lose transitions, send from an outbox or background worker with retries.

Technical telemetry joins the same traces:

- **OpenTelemetry** already in place: the connect env sets `OTEL_EXPORTER_OTLP_ENDPOINT` and `OTEL_EXPORTER_OTLP_HEADERS`, so the stock OTLP exporter needs no code change. See `otel-python`, `otel-ts`, `dotnet-otel`. Attach to the existing `TracerProvider`; do not replace it.
- **Agent frameworks**: the framework skills (`langchain`, `deepagents`, `anthropic`, `crewai`, `openai-agents`, `ts-*`, `dotnet-semantic-kernel`) add model and tool span metadata without changing routing. Do not let two integrations record the same model call.
- **Sentry** already in place: point it at `SENTRY_DSN` (see `sentry`). Do not add Sentry just for axonpush.
- **Logs**: `logging`, `loguru`, `structlog`, `pino`, `winston`, `console` forward structured diagnostics. They do not replace observations.

Pass `trace_id`/`span_id` on observations (the SDK binds the current trace when there is one) so the workspace timeline links to traces.

## 7. Verify and report

Send one test observation from the app, then confirm it in `workspaces_catalog` and, for business state, in `activity_entities` or `activity_timeline`. `observations_receipt` shows storage and projection separately; an accepted request is not proof of projection. Check `activity_health` for freshness and undeclared attributes; the ingest report's `dropped` lists keys the dictionary does not declare.

Report per boundary: `verified`, `wired but unverified`, or `gap`, with the workspace, active revision, environment and any personal attributes the user acknowledged. Do not deploy, commit or publish templates unless the user asked.

## Fallback without MCP

If MCP cannot be connected and the user only wants framework or OTLP tracing, `helpers/login.sh` signs in through the browser and returns an API key and tenant id, and `helpers/api.sh` lists or creates apps and channels and publishes or lists test events. This path does not build a workspace; say so.
