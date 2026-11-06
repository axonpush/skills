---
name: axonpush-compliance
description: Add declared tasks, human decision evidence, policy outcomes and notice delivery to an existing axonpush integration. Use when instrumenting an application's audit evidence; do not use to certify legal compliance or introduce a policy gateway.
---

# Instrument audit evidence

Inspect the installed SDK and its documentation before editing. The evidence
helpers are available in the audit-platform feature release; do not assume an
older published SDK contains them. Use the project's configured API endpoint,
including a customer's licensed self-host endpoint, rather than replacing it
with the hosted service.

1. Find the application's actual task boundaries, policy decisions, notice
   delivery and human approval handlers. Record what happened at those sites;
   do not emit an approval because a model requested one or because a button
   was rendered.
2. Reuse the existing client, channel and stable agent identifier. Do not mint a
   broadly privileged management key for passive instrumentation.
3. Use the matching recorder:
   - TypeScript: `new EvidenceRecorder(client.events, channelId, agentId)`
     from `@axonpush/sdk`; wrap work in
     `await recorder.task(goal, async (taskId) => { ... })`.
   - Python: `EvidenceRecorder(client.events, channel_id, agent_id)` or
     `AsyncEvidenceRecorder` from `axonpush.evidence`; use
     `with recorder.task(goal)` or `async with recorder.task(goal)`.
   - .NET: `new EvidenceRecorder(client.Events, channelId, agentId)` from
     `AxonPush.Evidence`; use `TaskAsync(goal, async (taskId, ct) => ...)`.
4. Record decisions with `decision` / `decision` / `DecisionAsync`; rule outcomes
   with `denied` / `denied` / `DeniedAsync`; notices with
   `noticeShown` / `notice_shown` / `NoticeShownAsync`. In JavaScript and async
   Python, await these calls.
5. Ordinary events published through the SDK events resource inherit task
   identity inside the task scope. Do not assume third-party OTLP exporters or
   separate processes inherit it: propagate opaque task IDs explicitly across
   those boundaries.
6. Verify one synthetic flow against the configured endpoint. Check operation
   names, task/parent IDs and expected failures without exposing customer
   content. Use available trace/decision-trail read capabilities; discover MCP
   operations before calling them. Do not invent verification, obligation or
   request tools that the connected server does not advertise.

Decisions emitted by the SDK are labelled `sdk_reported`; their actor is a
customer assertion, not an authenticated axonpush dashboard approval. Shadow
denials mean "would deny". These helpers do not block application actions.

Keep goals and reasons concise. They are content, governed by capture, redaction
and erasure settings. The structural task ID is metadata; metadata-only capture
does not establish that the goal/reason was retained. Preserve the client's
fail-open setting and the application's original exceptions. Never claim that
instrumentation establishes certification, legal applicability or complete
compliance.

## Read policy and verify retained evidence

Discover `/capabilities/operations` before using the management surface. An ingest
key may read only the policy of the agent to which it is explicitly bound. Use
`GET /audit/agents/{id}/policy` (or the subject-aware POST policy check advertised
by the server) with that same binding. Treat transport/auth failures explicitly;
never silently interpret an unavailable policy as an allow decision. The SDK
records enforcement outcomes, while the application performs the actual block.
Suspension revokes the bound credentials. Resuming requires newly issued keys;
do not resurrect an independently revoked credential.

For audit discovery, distinguish the pre-existing admin-chain verification
operation `audit.verify` from archive verification `audit.evidence.verify`.
Obligations and affected-person requests use the advertised `auditProduct.*`
operations. These require audit/request scopes; never add those scopes to a
passive publisher merely to simplify instrumentation. Watch or review-required
catalogue entries do not establish an effective legal duty or a satisfied control.

Archived content can require restoration before it is readable. A missing key
after subject erasure is an intentional permanent result, while a cold object
needs the explicit restore workflow. Do not recreate erased subjects or copy
private content into reasons, metadata, evidence packs or logs to bypass erasure.
When fulfilling a verified erasure case, distinguish immediate access revocation
from background physical cleanup; keep the case pending until reconciliation
reports ready. Anonymous public request forms are not identity verification.

Downloaded bundles may be checked offline with `axonpush verify-evidence` and
packs with `axonpush verify-pack`. Supply a seal checkpoint or issuer public key
obtained through an independent trusted channel. The matching SDK repository
publishes `spec/evidence/v1` with event and manifest schemas and format details.
Framework lifecycle capture is opt-in with an actual declared goal; consult the
installed integration's API. Never substitute an agent handoff for a completed
run or infer a person's goal from a framework class name.
