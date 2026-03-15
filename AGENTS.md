**IMPORTANT**: before you do anything else, run the `beans prime` command and heed its output.
**IMPORTANT**: Read files in their entirety, do not read portions of files unless the contents are longer than 2000 lines.

## Project Overview

**joey-mcp-client-flutter** is a cross-platform Flutter chat app that connects to AI models via OpenRouter and remote MCP servers over Streamable HTTP. Supports multiple MCP servers per conversation, tool calling, sampling, elicitation, OAuth, and image/audio attachments.

### Tech Stack
- **Flutter** (iOS, Android, macOS, Windows, Linux) — Dart SDK ^3.10.7
- **State**: Provider — **DB**: sqflite (schema v15) — **HTTP**: Dio
- **LLM**: OpenRouter (PKCE OAuth, SSE streaming) — **MCP**: `mcp_dart` (Streamable HTTP)

## Architecture

### Data Flow
```
User input → ChatScreen._sendMessage()
  → ChatService.runAgenticLoop()
    → OpenRouterService.chatCompletionStream()  (SSE streaming)
    → _executeToolCalls() → McpClientService.callTool()  (loops until done)
  ← ChatEvent stream → ChatEventHandlerMixin → setState() + ConversationProvider (SQLite)
```

### ChatScreen Composition
`ChatScreen` uses two mixins and three delegate classes:
- **ChatEventHandlerMixin** (`screens/chat_event_handler.dart`) — maps `ChatEvent`s to UI state
- **ConversationActionsMixin** (`screens/conversation_actions.dart`) — share, rename, model switch, title gen, JSON export
- **McpServerManager** (`services/mcp_server_manager.dart`) — MCP server lifecycle + session resumption
- **McpOAuthManager** (`services/mcp_oauth_manager.dart`) — OAuth flows for MCP servers
- **ImageAttachmentHandler** (`utils/image_attachment_handler.dart`) — image picking + clipboard paste

Rendering is delegated to `MessageList` (widget) and `MessageInput` (widget).

### Key Services
- **ChatService** (`services/chat_service.dart`) — agentic loop, tool execution, cancellation, emits `ChatEvent`s
- **SamplingProcessor** (`services/sampling_processor.dart`) — handles MCP sampling requests (server-initiated LLM calls), shares `executeToolCalls` callback with ChatService
- **McpClientService** (`services/mcp_client_service.dart`) — wraps `mcp_dart`: connect, call tools, session resumption, OAuth token injection, sampling/elicitation callbacks
- **OpenRouterService** (`services/openrouter_service.dart`) — OAuth PKCE, chat completion, streaming, model listing
- **DatabaseService** (`services/database_service.dart`) — SQLite tables: `conversations`, `messages`, `mcp_servers`, `conversation_mcp_servers`, `mcp_sessions`
- **ConversationImportExportService** (`services/conversation_import_export_service.dart`) — JSON backup export/import for conversations and messages

### Message Roles (`models/message.dart`)
`MessageRole` enum: `user`, `assistant`, `system`, `tool`, `elicitation` (local-only), `mcpNotification` (sent as context), `modelChange` (local-only). `toApiMessage()` returns null for local-only roles.

## Development

### Commands
- `flutter analyze` — must pass with zero new errors before committing
- `flutter test` — unit tests (`test/`)
- `flutter test integration_test/` — integration tests

### Conventions
- Provider for state (not Riverpod), Dio for HTTP, sqflite for storage
- Models use `toMap()`/`fromMap()` + `copyWith()` for immutability
- Services are per-conversation, not singletons (except OpenRouterService/DatabaseService)
- Widgets receive data and callbacks via constructor — no direct service access

### Gotchas
- `ChatService` queues MCP notifications during streaming, flushes after each LLM response
- `MessageList` uses a **non-reversed** `ListView` — messages are in chronological order (index 0 = oldest). Auto-scroll to bottom is managed by `_MessageListState` which tracks whether the user is at the bottom and scrolls on content updates.
- Streaming chunks use special prefixes: `TOOL_CALLS:` for tool calls, `REASONING:` for thinking content
- MCP session IDs are persisted per conversation+server and used for session resumption
- OpenRouter API key is stored in SharedPreferences (PKCE OAuth flow)
- **DB migrations affect import/export**: The JSON export format uses `toMap()`/`fromMap()` from the models, which mirror the DB schema. When adding new columns via a migration: (1) keep new model fields nullable so `fromMap()` tolerates older exports missing the key, (2) if a new field is required, bump the export envelope version in `ConversationImportExportService` and handle the old version gracefully, (3) update the schema version number in this file
