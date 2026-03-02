---
# joey_mcp_client_flutter-1mmf
title: Pass platform-aware theme to MCP WebView
status: completed
type: bug
priority: normal
created_at: 2026-03-02T00:25:33Z
updated_at: 2026-03-02T00:26:34Z
---

On iOS, WKWebView follows the system appearance for prefers-color-scheme media queries, not the app's forced dark mode. When the OS is in light mode, MCP app CSS media queries use light-mode values, but the host injects dark-mode CSS colors, creating a mismatch (e.g. white event log backgrounds on dark body).

## Fix
Detect the platform brightness via MediaQuery.platformBrightnessOf(context) and pass the appropriate color palette to the WebView CSS variables. When the OS prefers light mode, use a light color palette so the host-injected styles are consistent with the MCP app's media-query-based styles. Also update the color-scheme CSS property and the theme field in the ui/initialize JSON-RPC response to match.

## Checklist
- [ ] Detect platform brightness in _buildHtml()
- [ ] Define a light color palette for when OS is in light mode
- [ ] Set color-scheme CSS property based on platform brightness
- [ ] Update theme in ui/initialize response based on platform brightness