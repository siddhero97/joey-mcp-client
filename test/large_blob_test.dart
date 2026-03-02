import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:joey_mcp_client_flutter/models/conversation.dart';
import 'package:joey_mcp_client_flutter/models/message.dart';
import 'package:joey_mcp_client_flutter/providers/conversation_provider.dart';
import 'package:joey_mcp_client_flutter/services/conversation_import_export_service.dart';
import 'package:joey_mcp_client_flutter/services/database_service.dart';

/// Generate a random string of the given length.
String _generateLargeString(int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rng = Random(42); // Fixed seed for reproducibility
  return String.fromCharCodes(
    Iterable.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
  );
}

/// Helper to clear all data from the shared in-memory database between tests.
Future<void> _clearDatabase() async {
  final db = await DatabaseService.instance.database;
  await db.delete('messages');
  await db.delete('conversations');
}

void main() {
  // Use an in-memory SQLite database for testing.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await _clearDatabase();
  });

  group('Large blob data handling', () {
    // ~3MB string — exceeds Android's ~2MB CursorWindow limit
    final largeData = _generateLargeString(3 * 1024 * 1024);

    test('lightweight query excludes uiData and sets hasUiData flag', () async {
      final db = DatabaseService.instance;
      final conversationId = 'conv-large-ui';

      // Insert a conversation
      await db.insertConversation(Conversation(
        id: conversationId,
        title: 'Large UI Test',
        model: 'test-model',
        createdAt: DateTime.utc(2025, 1, 1),
        updatedAt: DateTime.utc(2025, 1, 1),
      ));

      // Insert a message with large uiData
      final uiDataJson = jsonEncode({
        'resourceUri': 'ui://test/tool',
        'html': largeData,
        'serverId': 'server-1',
      });
      await db.insertMessage(Message(
        id: 'msg-ui',
        conversationId: conversationId,
        role: MessageRole.tool,
        content: 'tool result',
        timestamp: DateTime.utc(2025, 1, 1, 10, 0),
        toolCallId: 'tc-1',
        toolName: 'test_tool',
        uiData: uiDataJson,
      ));

      // Also insert a message without uiData
      await db.insertMessage(Message(
        id: 'msg-no-ui',
        conversationId: conversationId,
        role: MessageRole.user,
        content: 'hello',
        timestamp: DateTime.utc(2025, 1, 1, 9, 0),
      ));

      // Lightweight query should not include the actual uiData blob
      final messages = await db.getMessagesForConversation(conversationId);
      expect(messages.length, equals(2));

      // Message without uiData
      final noUiMsg = messages.firstWhere((m) => m.id == 'msg-no-ui');
      expect(noUiMsg.hasUiData, isFalse);
      expect(noUiMsg.uiData, isNull);

      // Message with uiData — hasUiData should be true, but uiData blob not loaded
      final uiMsg = messages.firstWhere((m) => m.id == 'msg-ui');
      expect(uiMsg.hasUiData, isTrue);
      expect(uiMsg.uiData, isNull);
    });

    test('getMessageUiData retrieves large uiData correctly', () async {
      final db = DatabaseService.instance;
      final conversationId = 'conv-ui-load';

      await db.insertConversation(Conversation(
        id: conversationId,
        title: 'UI Load Test',
        model: 'test-model',
        createdAt: DateTime.utc(2025, 1, 1),
        updatedAt: DateTime.utc(2025, 1, 1),
      ));

      final uiDataJson = jsonEncode({
        'resourceUri': 'ui://test/tool',
        'html': largeData,
        'serverId': 'server-1',
      });
      await db.insertMessage(Message(
        id: 'msg-1',
        conversationId: conversationId,
        role: MessageRole.tool,
        content: 'result',
        timestamp: DateTime.utc(2025, 1, 1, 10, 0),
        toolCallId: 'tc-1',
        toolName: 'test_tool',
        uiData: uiDataJson,
      ));

      // Retrieve uiData individually
      final retrievedUiData = await db.getMessageUiData('msg-1');
      expect(retrievedUiData, isNotNull);
      expect(retrievedUiData, equals(uiDataJson));
    });

    test('getMessageBlobData retrieves large imageData correctly', () async {
      final db = DatabaseService.instance;
      final conversationId = 'conv-img-load';

      await db.insertConversation(Conversation(
        id: conversationId,
        title: 'Image Load Test',
        model: 'test-model',
        createdAt: DateTime.utc(2025, 1, 1),
        updatedAt: DateTime.utc(2025, 1, 1),
      ));

      final largeImageData = jsonEncode([
        {'data': largeData, 'mimeType': 'image/png'},
      ]);
      await db.insertMessage(Message(
        id: 'msg-img',
        conversationId: conversationId,
        role: MessageRole.user,
        content: 'check this image',
        timestamp: DateTime.utc(2025, 1, 1, 10, 0),
        imageData: largeImageData,
      ));

      final blobData = await db.getMessageBlobData('msg-img');
      expect(blobData['imageData'], isNotNull);
      expect(blobData['imageData'], equals(largeImageData));
    });

    test('getMessageBlobData retrieves large audioData correctly', () async {
      final db = DatabaseService.instance;
      final conversationId = 'conv-audio-load';

      await db.insertConversation(Conversation(
        id: conversationId,
        title: 'Audio Load Test',
        model: 'test-model',
        createdAt: DateTime.utc(2025, 1, 1),
        updatedAt: DateTime.utc(2025, 1, 1),
      ));

      final largeAudioData = jsonEncode([
        {'data': largeData, 'mimeType': 'audio/wav'},
      ]);
      await db.insertMessage(Message(
        id: 'msg-audio',
        conversationId: conversationId,
        role: MessageRole.user,
        content: 'listen to this',
        timestamp: DateTime.utc(2025, 1, 1, 10, 0),
        audioData: largeAudioData,
      ));

      final blobData = await db.getMessageBlobData('msg-audio');
      expect(blobData['audioData'], isNotNull);
      expect(blobData['audioData'], equals(largeAudioData));
    });

    test('getMessageBlobData handles message with all three large blobs', () async {
      final db = DatabaseService.instance;
      final conversationId = 'conv-all-blobs';

      await db.insertConversation(Conversation(
        id: conversationId,
        title: 'All Blobs Test',
        model: 'test-model',
        createdAt: DateTime.utc(2025, 1, 1),
        updatedAt: DateTime.utc(2025, 1, 1),
      ));

      final largeImageData = jsonEncode([
        {'data': _generateLargeString(2 * 1024 * 1024), 'mimeType': 'image/png'},
      ]);
      final largeAudioData = jsonEncode([
        {'data': _generateLargeString(2 * 1024 * 1024), 'mimeType': 'audio/wav'},
      ]);
      final largeUiData = jsonEncode({
        'resourceUri': 'ui://test/tool',
        'html': _generateLargeString(2 * 1024 * 1024),
        'serverId': 'server-1',
      });

      await db.insertMessage(Message(
        id: 'msg-all',
        conversationId: conversationId,
        role: MessageRole.tool,
        content: 'result',
        timestamp: DateTime.utc(2025, 1, 1, 10, 0),
        toolCallId: 'tc-1',
        toolName: 'test_tool',
        imageData: largeImageData,
        audioData: largeAudioData,
        uiData: largeUiData,
      ));

      final blobData = await db.getMessageBlobData('msg-all');
      expect(blobData['imageData'], equals(largeImageData));
      expect(blobData['audioData'], equals(largeAudioData));
      expect(blobData['uiData'], equals(largeUiData));
    });

    test('getFullMessagesForConversation retrieves all large blobs', () async {
      final db = DatabaseService.instance;
      final conversationId = 'conv-full-load';

      await db.insertConversation(Conversation(
        id: conversationId,
        title: 'Full Load Test',
        model: 'test-model',
        createdAt: DateTime.utc(2025, 1, 1),
        updatedAt: DateTime.utc(2025, 1, 1),
      ));

      final largeImageData = jsonEncode([
        {'data': largeData, 'mimeType': 'image/png'},
      ]);
      final largeUiData = jsonEncode({
        'resourceUri': 'ui://test/tool',
        'html': largeData,
        'serverId': 'server-1',
      });

      await db.insertMessage(Message(
        id: 'msg-user',
        conversationId: conversationId,
        role: MessageRole.user,
        content: 'check this',
        timestamp: DateTime.utc(2025, 1, 1, 10, 0),
        imageData: largeImageData,
      ));
      await db.insertMessage(Message(
        id: 'msg-tool',
        conversationId: conversationId,
        role: MessageRole.tool,
        content: 'result',
        timestamp: DateTime.utc(2025, 1, 1, 10, 1),
        toolCallId: 'tc-1',
        toolName: 'test_tool',
        uiData: largeUiData,
      ));

      final fullMessages = await db.getFullMessagesForConversation(conversationId);
      expect(fullMessages.length, equals(2));

      final userMsg = fullMessages.firstWhere((m) => m.id == 'msg-user');
      expect(userMsg.imageData, equals(largeImageData));

      final toolMsg = fullMessages.firstWhere((m) => m.id == 'msg-tool');
      expect(toolMsg.uiData, equals(largeUiData));
    });

    test('provider loadUiDataForConversation lazy-loads uiData', () async {
      final provider = ConversationProvider();
      await provider.initialize();

      final conv = await provider.createConversation(
        title: 'Lazy Load Test',
        model: 'test-model',
      );

      final uiDataJson = jsonEncode({
        'resourceUri': 'ui://test/tool',
        'html': largeData,
        'serverId': 'server-1',
      });
      await provider.addMessage(Message(
        id: 'msg-lazy',
        conversationId: conv.id,
        role: MessageRole.tool,
        content: 'result',
        timestamp: DateTime.utc(2025, 1, 1, 10, 0),
        toolCallId: 'tc-1',
        toolName: 'test_tool',
        uiData: uiDataJson,
      ));

      // Re-initialize to simulate app restart (loads lightweight data only)
      final freshProvider = ConversationProvider();
      // Reset the initialized flag by creating a new provider instance
      // Note: shares the same DB singleton
      await _clearDatabase();

      // Re-insert data fresh
      await DatabaseService.instance.insertConversation(Conversation(
        id: conv.id,
        title: 'Lazy Load Test',
        model: 'test-model',
        createdAt: DateTime.utc(2025, 1, 1),
        updatedAt: DateTime.utc(2025, 1, 1),
      ));
      await DatabaseService.instance.insertMessage(Message(
        id: 'msg-lazy-2',
        conversationId: conv.id,
        role: MessageRole.tool,
        content: 'result',
        timestamp: DateTime.utc(2025, 1, 1, 10, 0),
        toolCallId: 'tc-1',
        toolName: 'test_tool',
        uiData: uiDataJson,
      ));

      await freshProvider.initialize();

      // After init, hasUiData should be true but uiData should be null
      var messages = freshProvider.getMessages(conv.id);
      expect(messages.length, equals(1));
      expect(messages[0].hasUiData, isTrue);
      expect(messages[0].uiData, isNull);

      // Load uiData lazily
      await freshProvider.loadUiDataForConversation(conv.id);

      // Now uiData should be populated
      messages = freshProvider.getMessages(conv.id);
      expect(messages[0].uiData, isNotNull);
      expect(messages[0].uiData, equals(uiDataJson));
    });

    test('export round-trip preserves large blob data', () async {
      final provider = ConversationProvider();
      await provider.initialize();

      final conv = await provider.createConversation(
        title: 'Large Export Test',
        model: 'test-model',
      );

      final largeImageData = jsonEncode([
        {'data': _generateLargeString(3 * 1024 * 1024), 'mimeType': 'image/png'},
      ]);
      final largeAudioData = jsonEncode([
        {'data': _generateLargeString(3 * 1024 * 1024), 'mimeType': 'audio/wav'},
      ]);
      final largeUiData = jsonEncode({
        'resourceUri': 'ui://test/tool',
        'html': _generateLargeString(3 * 1024 * 1024),
        'serverId': 'server-1',
      });

      await provider.addMessage(Message(
        id: 'msg-img',
        conversationId: conv.id,
        role: MessageRole.user,
        content: 'image message',
        timestamp: DateTime.utc(2025, 1, 1, 10, 0),
        imageData: largeImageData,
      ));
      await provider.addMessage(Message(
        id: 'msg-audio',
        conversationId: conv.id,
        role: MessageRole.user,
        content: 'audio message',
        timestamp: DateTime.utc(2025, 1, 1, 10, 1),
        audioData: largeAudioData,
      ));
      await provider.addMessage(Message(
        id: 'msg-ui',
        conversationId: conv.id,
        role: MessageRole.tool,
        content: 'tool result',
        timestamp: DateTime.utc(2025, 1, 1, 10, 2),
        toolCallId: 'tc-1',
        toolName: 'test_tool',
        uiData: largeUiData,
      ));

      // Load all blobs (as the export path does)
      await provider.loadAllBlobsForConversation(conv.id);

      // Export
      final jsonString = await ConversationImportExportService.exportAllConversations(provider);

      // Clear and re-import
      await _clearDatabase();
      final destProvider = ConversationProvider();
      await destProvider.initialize();

      final result = await ConversationImportExportService.importConversations(
        jsonString,
        destProvider,
      );
      expect(result.imported, equals(1));

      // Load blobs for imported conversation
      final importedConv = destProvider.conversations[0];
      await destProvider.loadAllBlobsForConversation(importedConv.id);
      final messages = destProvider.getMessages(importedConv.id);

      expect(messages.length, equals(3));

      // Verify large imageData preserved
      final imgMsg = messages.firstWhere((m) => m.content == 'image message');
      expect(imgMsg.imageData, equals(largeImageData));

      // Verify large audioData preserved
      final audioMsg = messages.firstWhere((m) => m.content == 'audio message');
      expect(audioMsg.audioData, equals(largeAudioData));

      // Verify large uiData preserved
      final uiMsg = messages.firstWhere((m) => m.content == 'tool result');
      expect(uiMsg.uiData, equals(largeUiData));
    });
  });

  group('hasUiData flag', () {
    test('hasUiData is true when uiData is set in constructor', () {
      final msg = Message(
        id: 'msg-1',
        conversationId: 'conv-1',
        role: MessageRole.tool,
        content: 'result',
        timestamp: DateTime.utc(2025, 1, 1),
        uiData: '{"html":"<h1>hi</h1>"}',
      );
      expect(msg.hasUiData, isTrue);
      expect(msg.uiData, isNotNull);
    });

    test('hasUiData is false when uiData is null', () {
      final msg = Message(
        id: 'msg-1',
        conversationId: 'conv-1',
        role: MessageRole.user,
        content: 'hello',
        timestamp: DateTime.utc(2025, 1, 1),
      );
      expect(msg.hasUiData, isFalse);
      expect(msg.uiData, isNull);
    });

    test('hasUiData can be set explicitly without uiData blob', () {
      final msg = Message(
        id: 'msg-1',
        conversationId: 'conv-1',
        role: MessageRole.tool,
        content: 'result',
        timestamp: DateTime.utc(2025, 1, 1),
        hasUiData: true,
      );
      expect(msg.hasUiData, isTrue);
      expect(msg.uiData, isNull);
    });

    test('fromMap sets hasUiData from DB flag when uiData column is absent', () {
      final map = {
        'id': 'msg-1',
        'conversationId': 'conv-1',
        'role': 'tool',
        'content': 'result',
        'timestamp': '2025-01-01T00:00:00.000Z',
        'hasUiData': 1,
      };
      final msg = Message.fromMap(map);
      expect(msg.hasUiData, isTrue);
      expect(msg.uiData, isNull);
    });

    test('fromMap sets hasUiData to false when DB flag is 0', () {
      final map = {
        'id': 'msg-1',
        'conversationId': 'conv-1',
        'role': 'user',
        'content': 'hello',
        'timestamp': '2025-01-01T00:00:00.000Z',
        'hasUiData': 0,
      };
      final msg = Message.fromMap(map);
      expect(msg.hasUiData, isFalse);
      expect(msg.uiData, isNull);
    });

    test('copyWith preserves hasUiData when adding uiData', () {
      final msg = Message(
        id: 'msg-1',
        conversationId: 'conv-1',
        role: MessageRole.tool,
        content: 'result',
        timestamp: DateTime.utc(2025, 1, 1),
        hasUiData: true,
      );
      expect(msg.uiData, isNull);

      final updated = msg.copyWith(uiData: '{"html":"loaded"}');
      expect(updated.hasUiData, isTrue);
      expect(updated.uiData, equals('{"html":"loaded"}'));
    });
  });
}
