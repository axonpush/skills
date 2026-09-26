---
name: gateway
description: Route a project's OpenAI or Anthropic traffic through the axonpush gateway with zero instrumentation. Change one base_url and add an x-axonpush-api-key header; every call, including tool calls and agent handoffs, is captured as a queryable span. Use when the user wants observability plus control (moderation, spend policies, audit trail) without adding an SDK, callback handler, or framework wrapper.
---

# axonpush gateway (zero instrumentation)

Point the project's OpenAI or Anthropic client at the axonpush gateway. No SDK, callback handler, or framework wrapper. You change the `base_url` and add one header. Every call, including tool calls and agent handoffs, is captured as a queryable span, and moderation rules and spend policies run inline before a call, response, or tool call is allowed through.

Prefer this path when the user wants observability and control fast and does not want to touch agent code beyond client construction. The framework sub-skills (langchain, crewai, anthropic, etc.) remain the right choice when the user wants richer in-process events or already publishes custom events; the two paths can coexist.

## What you change

Two things, at the point where the LLM client is constructed:

1. Set the client `base_url` to the axonpush gateway:
   - OpenAI-compatible traffic: `https://api.axonpush.xyz/gw/openai/v1`
   - Anthropic traffic: `https://api.axonpush.xyz/gw/anthropic`
   - Self-host: swap the host for the tenant's base URL, keeping the `/gw/openai/v1` or `/gw/anthropic` suffix.

   The `/v1` on the OpenAI base URL is not optional. The gateway strips the `/gw/openai` prefix and forwards the rest verbatim upstream, so the OpenAI SDK (which appends `/chat/completions`) must carry `/v1` in its base URL or the upstream call 404s. The Anthropic SDK appends `/v1/messages` itself, so its base URL stays `/gw/anthropic` with no `/v1`.
2. Add the header `x-axonpush-api-key: <AXONPUSH_API_KEY>` to every request. The upstream provider key (`OPENAI_API_KEY` / `ANTHROPIC_API_KEY`) is still sent as usual; the gateway forwards it upstream.

The gateway is a transparent reverse proxy. Request and response bodies keep the provider's native shape, so existing code, streaming, and tool-calling keep working unchanged.

## Choosing the upstream provider

The path segment selects the **wire shape**: `/gw/openai` speaks the OpenAI request/response shape, `/gw/anthropic` speaks the Anthropic shape. By default the gateway forwards to the provider that matches the path.

To send that wire shape to a different upstream provider, add the `x-axonpush-target` header:

| `x-axonpush-target` | Upstream |
| --- | --- |
| `openai` | OpenAI |
| `anthropic` | Anthropic |
| `openrouter` | OpenRouter |
| `vercel` | Vercel AI Gateway |
| `groq` | Groq |
| `together` | Together |

The header is optional; omit it to use the path's default. The upstream provider's key rides in the standard `Authorization: Bearer <provider_key>` header, which the gateway forwards verbatim. The `x-axonpush-api-key` header is stripped before forwarding upstream.

Two optional headers refine attribution: `x-axonpush-app: <name>` names the workspace app, and the request body's `user` field becomes the end-user id.

## Static reference

**Python, OpenAI SDK:**

```python
import os
from openai import OpenAI

client = OpenAI(
    base_url="https://api.axonpush.xyz/gw/openai/v1",
    default_headers={"x-axonpush-api-key": os.environ["AXONPUSH_API_KEY"]},
    # api_key still reads OPENAI_API_KEY; the gateway forwards it upstream.
)
```

**Python, Anthropic SDK:**

```python
import os
from anthropic import Anthropic

client = Anthropic(
    base_url="https://api.axonpush.xyz/gw/anthropic",
    default_headers={"x-axonpush-api-key": os.environ["AXONPUSH_API_KEY"]},
    # api_key still reads ANTHROPIC_API_KEY; the gateway forwards it upstream.
)
```

**TypeScript, OpenAI SDK:**

```ts
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "https://api.axonpush.xyz/gw/openai/v1",
  defaultHeaders: { "x-axonpush-api-key": process.env.AXONPUSH_API_KEY! },
  // apiKey still reads OPENAI_API_KEY; the gateway forwards it upstream.
});
```

**TypeScript, Anthropic SDK:**

```ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic({
  baseURL: "https://api.axonpush.xyz/gw/anthropic",
  defaultHeaders: { "x-axonpush-api-key": process.env.AXONPUSH_API_KEY! },
  // apiKey still reads ANTHROPIC_API_KEY; the gateway forwards it upstream.
});
```

Because most agent frameworks accept a custom client or a `base_url` / `baseURL` option, the same swap works under LangChain, CrewAI, OpenAI Agents, Vercel AI, and similar. Set the base URL and header on the underlying provider client the framework uses, and leave the rest of the agent code alone.

## Which call sites this covers, and which it does not

Apply the swap at every place a provider client is constructed, not just the first one. In a real codebase that usually means several: a shared `lib/llm` factory, a background worker, an eval script, each microservice. Grep for client construction (`OpenAI(`, `new OpenAI`, `Anthropic(`, `new Anthropic`, `base_url=`, `baseURL:`) and treat each hit as a separate call site.

The gateway speaks the OpenAI and Anthropic wire shapes only. That covers a large surface, because these clients also front many other providers:

- **Azure OpenAI**: the `AzureOpenAI` client hardcodes the Azure URL shape; point it at `/gw/openai/v1` only if you can override its base URL, otherwise use the OTel pillar for that call site.
- **OpenAI-compatible providers** (OpenRouter, Groq, Together, Vercel AI Gateway, Mistral, Fireworks): keep using the OpenAI SDK against `/gw/openai/v1` and set `x-axonpush-target` to route upstream.
- **Amazon Bedrock, Vertex, and other non-HTTP-base-URL SDKs**: these do not expose a swappable `base_url`. Do not force the gateway on them. Instrument those call sites through the OTel pillar or a framework sub-skill instead.

## Correlation with OTel and Sentry

Gateway spans join the same trace as OTLP spans and Sentry events when they share a trace id. If the calling code runs the axonpush SDK's trace context (`get_or_create_trace()` / `getOrCreateTrace()`) or propagates a W3C `traceparent` across services, the gateway call, your HTTP/DB spans, and any Sentry exception from the same request line up as one waterfall in Observe. No extra wiring is needed on the gateway itself; it records whatever trace context the incoming request carries.

## What you get once traffic flows through the gateway

- Spans for every call, queryable in the dashboard. Tool calls appear as their own spans with the tool name, arguments, and outcome. Agent handoffs are captured too.
- Analytics broken down by agent and by tool, with agent, tool, and semantic-kind event filters.
- Inline moderation and enforcement. Rules can block, redact, or flag on the request, the response, or a specific tool call, for example block a tool named `transfer_funds`, or block a call whose `amount` argument is over a threshold. Enforcement happens before the tool call or handoff executes.
- Spend policies. Cost governance shaped as scope x window x threshold ladder. A policy targets a scope (app, env, model, provider, api-key, user, or tag), a window (daily, weekly, monthly, or cumulative), and a USD limit, then climbs a ladder of rungs where each rung is a threshold percent mapped to an action (notify, block, or fallback to a cheaper model). Blocks can be soft or hard, so a runaway agent is throttled or stopped before it burns the limit.
- An immutable, queryable audit trail of what each agent did and what axonpush allowed, redacted, or blocked, shaped for compliance reviews (DORA, EU AI Act, SR 11-7).

Moderation rules and spend policies are authored in the dashboard, not in the project code. This skill only wires the traffic through the gateway; point the user at their app's Moderation and Spend Policies settings to author them.

## Verify

Make one call through the gateway from the project, then confirm it shows up:

- In the dashboard, open the app and look for the new span. Tool-using calls should show the tool-call spans nested under the request.
- The provider response the code receives is unchanged, so existing assertions and output handling keep passing.

If calls succeed upstream but nothing appears in axonpush, the most common cause is a missing or wrong `x-axonpush-api-key` header, or a `base_url` that dropped the `/gw/openai` or `/gw/anthropic` suffix.
