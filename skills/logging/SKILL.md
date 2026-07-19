---
name: logging
description: Forward Python stdlib `logging` (and Django's `LOGGING` dict-config) records into AxonPush as structured events. Wires an `AxonPushLoggingHandler` into the root logger or a named logger so existing `logger.info(...)` / `logger.error(...)` calls publish events without code rewrites. Use when the project uses Python's `logging` module, including Django, Flask, or FastAPI projects with stdlib logging.
---

# AxonPush + Python `logging` integration

Wires `axonpush.integrations.logging_handler.AxonPushLoggingHandler` into the user's existing Python logging config. Works for plain stdlib `logging`, Django's `LOGGING` dict-config, Flask's `app.logger`, and FastAPI/Uvicorn loggers.

## Reference (live)

Before applying, fetch the latest README from the SDK repo:
- `https://raw.githubusercontent.com/axonpush/python-sdk/master/README.md`
- Specifically the "Logging integrations" section.

If the fetch fails, use the static reference below.

## What gets added

- `AxonPushLoggingHandler` attached to the appropriate logger (root, or a named one for Django). It reads `AXONPUSH_*` credentials from the environment and auto-excludes AxonPush's own loggers, so it can't feed back on itself.
- Each log record becomes an event with `eventType: "app.log"`, `identifier: <logger_name>`, and `payload: { level, message, args, exc_info, extra }`.
- Channel + app + tenant come from `AXONPUSH_*` env vars (already in the project's `.env` from the orchestrator).

## Static reference (Python stdlib)

```python
import logging
import os

from axonpush.integrations.logging_handler import AxonPushLoggingHandler

handler = AxonPushLoggingHandler(channel_id=os.environ["AXONPUSH_CHANNEL_ID"])
logging.getLogger().addHandler(handler)
logging.getLogger().setLevel(logging.INFO)
```

## Static reference (Django)

In `settings.py` (`import os` at the top), add to the `LOGGING` dict-config. Dict-config passes extra keys as constructor kwargs, so `channel_id` is required here:

```python
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "axonpush": {
            "class": "axonpush.integrations.logging_handler.AxonPushLoggingHandler",
            "channel_id": os.environ["AXONPUSH_CHANNEL_ID"],
            "level": "INFO",
        },
        "console": { "class": "logging.StreamHandler", "level": "INFO" },
    },
    "root": { "handlers": ["console", "axonpush"], "level": "INFO" },
}
```

Importing the handler is enough — `axonpush` does not need to be in `INSTALLED_APPS`.

## Verify

After integration, `logger.info("hello from logging")` should appear in the dashboard within a few seconds.
