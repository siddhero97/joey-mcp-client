---
# joey_mcp_client_flutter-vjz2
title: Fix CursorWindow overflow caused by large uiData column
status: completed
type: bug
priority: normal
created_at: 2026-03-01T23:57:11Z
updated_at: 2026-03-02T00:01:30Z
---

The uiData column (containing HTML for MCP App WebViews) can be very large and is currently included in the lightweight getMessagesForConversation() query. This triggers CursorWindow overflow on Android (Row too big to fit into CursorWindow). Fix: treat uiData like imageData/audioData - exclude from lightweight query, add hasUiData boolean flag for UI checks, lazy-load full uiData content when needed for WebView rendering.