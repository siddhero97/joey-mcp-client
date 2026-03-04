---
# joey_mcp_client_flutter-p21s
title: Local custom tool integrations / hard-coded local MCPs
status: draft
type: feature
created_at: 2026-03-04T12:38:05Z
updated_at: 2026-03-04T12:38:05Z
---

Add built-in local MCP tool integrations that don't require a remote server. These are hard-coded tools that leverage native device capabilities directly.

## Tools

- **Calendar**: Read/write calendar events via [device_calendar](https://pub.dev/packages/device_calendar)
- **SMS**: Send SMS messages via [flutter_sms](https://pub.dev/packages/flutter_sms)
- **Contacts**: Read/search contacts via [flutter_contacts](https://pub.dev/packages/flutter_contacts)
- **Location**: Get current device location (hard-coded tool)
- **Time**: Get current date/time (hard-coded tool)
- **Phone call**: Start a phone call by launching a `tel:` URL — should render as a tappable link that opens the dialer, similar to how URL elicitation works
- **Email**: Send email via [flutter_email_sender](https://pub.dev/packages/flutter_email_sender)
- **Reminders** (iOS only): Create/read reminders via [reminders](https://pub.dev/packages/reminders)

## Checklist

- [ ] Design local tool provider architecture (register tools, handle calls without MCP server)
- [ ] Implement calendar tool (device_calendar)
- [ ] Implement SMS tool (flutter_sms)
- [ ] Implement contacts tool (flutter_contacts)
- [ ] Implement location tool
- [ ] Implement time tool
- [ ] Implement phone call tool (tel: URL, rendered as tappable link)
- [ ] Implement email tool (flutter_email_sender)
- [ ] Implement reminders tool (iOS only, reminders package)
- [ ] Add UI for enabling/disabling local tools per conversation
- [ ] Handle permissions gracefully for each tool