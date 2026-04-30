---
# joey_mcp_client_flutter-gihb
title: Fix scroll position lock during streaming
status: completed
type: bug
priority: normal
created_at: 2026-03-15T11:27:20Z
updated_at: 2026-03-15T11:29:08Z
---

When OpenRouter responses stream in, text shifts upward if user has scrolled up. Need to lock scroll position when user is not at the bottom.