---
# joey_mcp_client_flutter-zx6q
title: Fix CSP blocking external scripts in McpAppWebView loadData context
status: in-progress
type: bug
created_at: 2026-02-23T03:48:58Z
updated_at: 2026-02-23T03:48:58Z
---

HTML is loaded via loadData() with baseUrl about:blank, so CSP 'self' resolves to about:blank — blocking all external script/style/font/connect URLs. Sheet music and other MCP App views that load CDN scripts render blank. Fix: update default CSP to allow https: sources, since MCP server metadata can restrict further via cspMeta.