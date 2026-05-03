---
name: logging
description: Forward Python stdlib `logging` (and Django's `LOGGING` dict-config) records into AxonPush as structured events. Wires an `AxonpushHandler` into the root logger or a named logger so existing `logger.info(...)` / `logger.error(...)` calls publish events without code rewrites. Use when the project uses Python's `logging` module, including Django, Flask, or FastAPI projects with stdlib logging.
---

# AxonPush + Python `logging` integration

Wires `axonpush.integrations.logging.AxonpushHandler` into the user's existing Python logging config. Works for plain stdlib `logging`, Django's `LOGGING` dict-config, Flask's `app.logger`, and FastAPI/Uvicorn loggers.

## Reference (live)

Before applying, fetch the latest README from the SDK repo:
- `https://raw.githubusercontent.com/axonpush/axonpush-python/master/README.md`
- Specifically the "Logging integrations" section.

If the fetch fails, use the static reference below.

## What gets added

- `AxonpushHandler` attached to the appropriate logger (root, or a named one for Django).
- Each log record becomes an event with `eventType: "log"`, `identifier: <logger_name>`, and `payload: { level, message, args, exc_info, extra }`.
- Channel + app + tenant come from `AXONPUSH_*` env vars (already in the project's `.env` from the orchestrator).

## Static reference (Python stdlib)

```python
import logging
from axonpush.integrations.logging import AxonpushHandler

handler = AxonpushHandler()  # reads AXONPUSH_* env vars
logging.getLogger().addHandler(handler)
logging.getLogger().setLevel(logging.INFO)
```

## Static reference (Django)

In `settings.py`, add to the `LOGGING` dict-config:

```python
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "axonpush": {
            "class": "axonpush.integrations.logging.AxonpushHandler",
            "level": "INFO",
        },
        "console": { "class": "logging.StreamHandler", "level": "INFO" },
    },
    "root": { "handlers": ["console", "axonpush"], "level": "INFO" },
}
```

Confirm `axonpush` is in `INSTALLED_APPS` only if the user wants management commands; otherwise importing the handler is enough.

## Verify

After integration, `logger.info("hello from logging")` should appear in the dashboard within a few seconds.
