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
