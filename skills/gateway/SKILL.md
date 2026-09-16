---
name: gateway
description: Route a project's OpenAI or Anthropic traffic through the axonpush gateway with zero instrumentation. Change one base_url and add an x-axonpush-api-key header; every call, including tool calls and agent handoffs, is captured as a queryable span. Use when the user wants observability plus control (moderation, cost caps, audit trail) without adding an SDK, callback handler, or framework wrapper.
---

# axonpush gateway (zero instrumentation)

Point the project's OpenAI or Anthropic client at the axonpush gateway. No SDK, callback handler, or framework wrapper. You change the `base_url` and add one header. Every call, including tool calls and agent handoffs, is captured as a queryable span, and moderation rules and cost caps run inline before a call, response, or tool call is allowed through.

Prefer this path when the user wants observability and control fast and does not want to touch agent code beyond client construction. The framework sub-skills (langchain, crewai, anthropic, etc.) remain the right choice when the user wants richer in-process events or already publishes custom events; the two paths can coexist.

## What you change

Two things, at the point where the LLM client is constructed:

1. Set the client `base_url` to the axonpush gateway:
   - OpenAI-compatible traffic: `https://api.axonpush.xyz/gw/openai`
   - Anthropic traffic: `https://api.axonpush.xyz/gw/anthropic`
   - Self-host: swap the host for the tenant's base URL, keeping the `/gw/openai` or `/gw/anthropic` suffix.
2. Add the header `x-axonpush-api-key: <AXONPUSH_API_KEY>` to every request. The upstream provider key (`OPENAI_API_KEY` / `ANTHROPIC_API_KEY`) is still sent as usual; the gateway forwards it upstream.

The gateway is a transparent reverse proxy. Request and response bodies keep the provider's native shape, so existing code, streaming, and tool-calling keep working unchanged.

## Static reference

**Python, OpenAI SDK:**

```python
import os
from openai import OpenAI

client = OpenAI(
    base_url="https://api.axonpush.xyz/gw/openai",
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
  baseURL: "https://api.axonpush.xyz/gw/openai",
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

## What you get once traffic flows through the gateway

- Spans for every call, queryable in the dashboard. Tool calls appear as their own spans with the tool name, arguments, and outcome. Agent handoffs are captured too.
- Analytics broken down by agent and by tool, with agent, tool, and semantic-kind event filters.
- Inline moderation and enforcement. Rules can block, redact, or flag on the request, the response, or a specific tool call, for example block a tool named `transfer_funds`, or block a call whose `amount` argument is over a threshold. Enforcement happens before the tool call or handoff executes.
- Cost caps. Hard per-key or per-app spend ceilings that block pre-spend, so a runaway agent stops before it burns the budget.
- An immutable, queryable audit trail of what each agent did and what axonpush allowed, redacted, or blocked, shaped for compliance reviews (DORA, EU AI Act, SR 11-7).

Moderation rules and cost caps are configured in the dashboard, not in the project code. This skill only wires the traffic through the gateway; point the user at their app's Moderation and Cost settings to author rules.

## Verify

Make one call through the gateway from the project, then confirm it shows up:

- In the dashboard, open the app and look for the new span. Tool-using calls should show the tool-call spans nested under the request.
- The provider response the code receives is unchanged, so existing assertions and output handling keep passing.

If calls succeed upstream but nothing appears in axonpush, the most common cause is a missing or wrong `x-axonpush-api-key` header, or a `base_url` that dropped the `/gw/openai` or `/gw/anthropic` suffix.
