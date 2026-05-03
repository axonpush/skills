---
name: structlog
description: Forward `structlog` log records into AxonPush as structured events. Adds an `AxonpushProcessor` to the structlog processor chain. Use when the Python project uses structlog (detected by `structlog` in pyproject.toml or requirements.txt).
---

# AxonPush + structlog integration

## Reference (live)

`https://raw.githubusercontent.com/axonpush/axonpush-python/master/README.md` — "structlog" section.

## What gets added

- `axonpush.integrations.structlog.AxonpushProcessor` appended to the structlog processor chain.
- Each `log.info(...)` / `log.error(...)` becomes an event with `eventType: "log"`, the bound context preserved as `payload`.

## Static reference

```python
import structlog
from axonpush.integrations.structlog import AxonpushProcessor

structlog.configure(
    processors=[
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        AxonpushProcessor(),  # reads AXONPUSH_* env vars
        structlog.processors.JSONRenderer(),
    ],
)
```

## Verify

`structlog.get_logger().info("hello from structlog", user="alice")` should appear in the dashboard within a few seconds with `user: "alice"` in the payload.
