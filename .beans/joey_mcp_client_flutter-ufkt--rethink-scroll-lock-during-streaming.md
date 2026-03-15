---
# joey_mcp_client_flutter-ufkt
title: Rethink scroll lock during streaming
status: completed
type: bug
priority: normal
created_at: 2026-03-15T11:37:46Z
updated_at: 2026-03-15T11:40:03Z
---

Previous offset-compensation approach was glitchy. Switching to non-reversed ListView with auto-scroll-to-bottom behavior, which naturally preserves scroll position when user scrolls up.