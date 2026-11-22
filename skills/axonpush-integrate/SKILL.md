---
name: axonpush-integrate
description: Set up AxonPush workflow verification in an application. Define one business commitment, generate hooks, test evidence with the deterministic verifier, and configure a development deployment over MCP. Also supports optional business observability and existing Nova integrations.
---

# Integrate AxonPush

Help the user verify one business commitment against supplied evidence. Start
with accepted booking requests and actual appointment records when that fits
the application. Keep the user's workflow and domain; booking is an example.
AxonPush observes execution. The application performs business actions.

For a request specifically about tracing, profiles, business dashboards or an
existing Nova workspace, use [business observability](references/observability.md).
Its draft activation is separate from workflow-definition activation. Preserve
existing telemetry and workspace specifications during workflow setup.

## Discover the application and connection

Inspect the repository's language, dependencies, workflow code, committed state
transitions and reliable publication path. Reuse existing instrumentation and
connections. Do not change model routing or business behavior for this setup.

If MCP is available, discover its permitted tools. Resolve the intended workspace
with `workspaces_list` and an explicit development environment with
`environments_list`. Adopt the pending workspace from dashboard onboarding when
it is the intended application. Use the actual schemas to create an app/workspace
only when needed; never guess IDs or overwrite existing specifications.

Call `workflows_describe` with `workspaceId` and `environment`. Follow its guide,
schemas and compiler version over stale examples in this skill. It is read-only:
it returns questions, exact tool names and a synthetic contract/fixture, not a
configured integration. Read existing definitions and activations first.

When MCP is absent, offer a deliberate connection to the user's server `/mcp`
endpoint or continue with local contract authoring/testing using the docs. A
failed authorization should be reported once; do not loop browser sign-in,
invent successful calls or claim the hosted deployment is configured.

## Ask useful questions

Infer answers from code, then ask at most two unresolved questions at a time:

- What customer commitment and client deployment should we verify first?
- Which authoritative record proves completion, and can customer code read it?
- Which stable request/case ID joins attempts, retries and records?
- What deadline, grace and reconciliation coverage make missing evidence meaningful?
- Which existing language and YAML/Zod/Effect authoring approach fits this codebase?

Clarify cancellations/rescheduling and distinct duplicate records. A transcript
or successful function call alone does not establish a persisted provider record.
Prefer opaque IDs and bounded fields; avoid raw conversations and unnecessary
personal information. Keep provider credentials in the customer's application.

## Implement and test locally

Save the contract in the repository. Use the installed, version-pinned CLI to
validate, generate typed hooks and run fixed-clock fixtures. Consult
https://docs.axonpush.xyz/workflows-quickstart and the matching SDK/provider docs
before choosing commands or imports; source-checkout capabilities may not exist
in a published package yet. YAML, Zod and Effect must use the shared Go verifier.
Do not replace it with an LLM judgement or execute arbitrary schema callbacks.

Implement customer-side evidence checks and reliable fact delivery after the
source transaction commits. Distinguish absent records, mismatches and lookup
failures. Preserve user-owned adapter implementations during regeneration.
Test satisfied, missing-record and unavailable-source fixtures. Use
`workflows_compile` and `workflows_simulate` with an explicit input clock to
compare server semantics without persisting cases.

## Publish, connect and verify

Explain the implementation diff and evidence limitations. Use `workflows_diff`,
`workflows_publish` and then `workflows_activate` for the reviewed development
deployment. Confirm it with `workflows_activation`. Publishing alone does not
activate a definition; existing cases remain pinned. Production changes require
the user's instruction for that deployment.

`workspaces_connect` resolves publish configuration for an explicit environment
and purpose. Delegated agents receive `claim`, a one-time link the signed-in user
opens to save secrets in the application's git-ignored environment file. They
do not receive raw secrets. Do not bypass the claim link, print credentials or
write placeholder secret values over a working file. Reuse existing keys;
rotate only when revocation/replacement is intended by the user.

Register each source with `workflows_registerSource`, using the actual source
ID and `publisher: "key:<publishKey.id>"` from that same connection. Confirm
configuration via `workflows_sources`. Registration does not establish coverage.

Publish a controlled development case through the workflow SDK/HTTP API with the
bound application key. An OAuth MCP caller publishes as `user:<user ID>` and
cannot impersonate that key; `workflows_facts` requires a source bound to its
actual caller. Use stable fact IDs
and explicit source reconciliation checkpoints. A heartbeat alone is insufficient.
Wait for asynchronous processing and inspect `workflows_case`: require a
nonprocessing case with at least one evaluated obligation and an explanation.
A storage receipt, connection or generated hook does not prove verification.

Link the case to the dashboard and related traces/business activity. Explain
expected result, observed evidence, timing and the next investigative step.
Acknowledgement is not satisfaction; waiver/cancellation remain separate, and
late evidence must not erase a recorded breach. Do not retry bookings or execute
other business actions as part of verification setup.

Report changed files, local test results, workspace/environment, activated version
if any, publisher/source binding and each boundary as verified, wired but
unverified, or blocked. Label synthetic cases. Do not commit, deploy or send
outreach unless the user requested it.
