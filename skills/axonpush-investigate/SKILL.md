---
name: axonpush-investigate
description: Investigate a failing or slow run, or a stuck business entity, from your editor using the axonpush MCP. Fetch issue, trace and workspace evidence, find the responsible step, relate it to this repository, and propose a fix. Use when the user pastes an axonpush issue/trace link or says "debug this failure", "why did this run fail", "investigate this incident", or clicks "Debug with coding agent" in the dashboard.
---

# Investigate a run from the code

You have three things at once: this project's **source code** (so you know the
domain and where the code lives), the **axonpush MCP** (so you can pull the runtime
evidence for what actually happened), and the ability to **read git** (so you can
relate a failing step to a commit/release). Use all three. Fetch evidence through
the MCP; never fabricate telemetry, and separate what a trace proves from your
hypothesis.

Requires the axonpush MCP to be connected (the same one `axonpush-integrate` uses).
If it is not, tell the user to connect it (`claude mcp add --transport http axonpush
https://api.axonpush.xyz/mcp`, or the dashboard's Connect page) and stop.

## Step 0: establish context

Call `user_me` to confirm the workspace, and note the app/environment your key is
scoped to (an investigation key is confined to its app/environment server-side, so
reads only return that scope). If the user gave a trace id or issue fingerprint,
use it; otherwise ask which run to investigate, or start from the most recent
failures (step 1).

## Step 1: fetch the evidence

Use the smallest set of read tools that answers the question:

- **An issue** (recurring error): `errors_list` and `errors_get` to get the issue:
  title, culprit, error type, first/last seen, affected traces, and a sample
  trace id. Prefer the issue view when the failure recurs.
- **A trace** (one run): `traces_get` with the trace id to get the ordered spans:
  the top-level request, each model call, each tool call, hand-offs, and errors.
  `traces_list` (with `q`/filters such as `status:error`, `duration:>Ns`, `sort`)
  to find the run when you only have a description.
- **A stuck or failed entity** (a ticket, agent, candidate, order): `workspaces_list`,
  then `activity_entities` to find it, `activity_timeline` with `ref=type:id` for its
  chronological evidence, `activity_incidents` for alerts that fired and
  `activity_health` for source freshness. Timeline entries link to traces.
- **The failing step**: in the trace, find the error span (or the slow span by
  `durationMs`). Read its operation, service, model/tool, and error type/message.

Do not pull whole payloads you do not need. Pull the specific spans that explain
the failure.

## Step 2: relate it to this repository

Map the failing step back to the code: match the service/operation/tool name and
stack frames to files in this repo, and to the current branch and release. If the
handoff gave a release/repository mapping, use it; if it said the mapping is not
configured, say so, and note that the deployed code that produced the trace may
differ from the local checkout (check the release/commit before assuming).

## Step 3: widen only if it helps

- **Is it recurring or one-off?** Use the issue's affected-trace count, or
  `traces_list` filtered to the same service/operation/error, to see how often it
  happens.
- **Cohort compare** (why this slice is slow/failing): `analytics_diff` (BubbleUp)
  with the failing slice as the selection and normal traffic as the baseline, to
  surface the attribute (model, tool, customer, region and so on) that is over-represented
  in the failures. `analytics_breakdown` / `analytics_latency` for cost/latency
  distribution.

## Step 4: explain, then propose

Report in this order:

1. **What the trace proves**: the failing step, the error, and the evidence
   (span ids, counts), with links back to the run in axonpush.
2. **Hypothesis**: your best explanation, clearly labelled as a hypothesis, not
   fact.
3. **Fix**: a focused patch and a regression test that would have caught it.
4. **Verify after deploy**: once the fix ships, compare subsequent runs (same
   filter) to confirm the failure rate dropped. Do NOT claim a proposed patch has
   already fixed production; only the later runs prove that.

## Guardrails

- Investigation is read-only. Change workspace alerts or the spec only when the user
  asks, through the shared draft (see `axonpush-tailor-dashboard`). axonpush observes;
  it does not control the application's actions.
- Keep evidence links and ids in your report so a teammate can reproduce the
  investigation. Never paste secrets or full customer content into the report.
