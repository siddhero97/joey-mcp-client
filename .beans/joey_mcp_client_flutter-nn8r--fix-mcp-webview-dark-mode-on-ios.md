---
# joey_mcp_client_flutter-nn8r
title: Fix MCP WebView dark mode on iOS
status: completed
type: bug
priority: normal
created_at: 2026-03-02T00:20:24Z
updated_at: 2026-03-02T00:23:08Z
---

The MCP App WebView on iOS doesn't properly trigger prefers-color-scheme: dark media queries, causing elements with var(--color-bg-subtle) backgrounds (like the event log section header) to render with light-mode colors (near-white #f9fafb) instead of dark-mode colors (#1f2937).

Root cause: The host injects a CSS style with `color-scheme: dark` on `:root` and sets the body background/text colors. However, WKWebView on iOS determines prefers-color-scheme based on either: (1) the system appearance, or (2) the forceDarkStrategy setting. It does NOT automatically honor the CSS color-scheme property to activate prefers-color-scheme media queries in the same way desktop browsers do.

The MCP app's CSS uses `@media (prefers-color-scheme: dark)` to switch variables like --color-bg-subtle, --color-border, etc. When the WebView doesn't report dark mode via prefers-color-scheme, these variables stay at their light-mode values, causing white/light backgrounds in sections like the event log.

## Fix
Inject additional CSS that overrides the app's media-query-dependent variables to their dark-mode values, since the host is always in dark mode. This is more reliable than trying to force WKWebView's prefers-color-scheme behavior.