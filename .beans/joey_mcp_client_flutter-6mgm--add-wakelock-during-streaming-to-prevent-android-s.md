---
# joey_mcp_client_flutter-6mgm
title: Add wakelock during streaming to prevent Android sleep interruption
status: completed
type: feature
priority: normal
created_at: 2026-02-23T00:17:39Z
updated_at: 2026-02-23T00:19:36Z
---

When the Android screen turns off during an active SSE stream from OpenRouter, the OS kills the network connection and the stream is lost. Fix: use wakelock_plus to keep the device awake while actively streaming in the agentic loop. Acquire wakelock on StreamingStarted, release on loop completion (success/error/cancel).