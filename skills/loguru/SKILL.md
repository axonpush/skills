---
name: loguru
description: Forward `loguru` log records into AxonPush as structured events. Adds an `axonpush_sink` to the loguru logger so existing `logger.info(...)` calls publish events. Use when the Python project uses loguru (detected by `loguru` in pyproject.toml or requirements.txt).
---

# AxonPush + loguru integration

## Reference (live)

`https://raw.githubusercontent.com/axonpush/axonpush-python/master/README.md` — "loguru" section.

## What gets added

- `axonpush.integrations.loguru.axonpush_sink` registered as a loguru sink.
- Each `logger.info(...)`, `logger.error(...)`, etc. becomes an event with `eventType: "log"` and `payload: { level, message, extra, exception }`.

## Static reference

```python
from loguru import logger
from axonpush.integrations.loguru import axonpush_sink

logger.add(axonpush_sink, level="INFO")  # reads AXONPUSH_* env vars
```

## Verify

`logger.info("hello from loguru")` should appear in the dashboard within a few seconds.
