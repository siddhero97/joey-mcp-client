import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

/// Result of pinging an MCP server
enum McpPingStatus {
  /// Ping is in progress
  checking,

  /// Server responded successfully
  reachable,

  /// Server did not respond or returned an error
  unreachable,
}

/// Result of a ping attempt with optional error details
class McpPingResult {
  final McpPingStatus status;
  final String? errorMessage;
  final int? httpStatusCode;

  const McpPingResult({
    required this.status,
    this.errorMessage,
    this.httpStatusCode,
  });

  const McpPingResult.checking()
      : status = McpPingStatus.checking,
        errorMessage = null,
        httpStatusCode = null;

  const McpPingResult.reachable()
      : status = McpPingStatus.reachable,
        errorMessage = null,
        httpStatusCode = null;

  const McpPingResult.unreachable({this.errorMessage, this.httpStatusCode})
      : status = McpPingStatus.unreachable;
}

/// Service for pinging MCP servers to check connectivity.
///
/// Uses a raw HTTP POST with the JSON-RPC ping method,
/// similar to how McpOAuthService.checkAuthRequired works.
class McpPingService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Ping an MCP server by URL.
  ///
  /// Sends a JSON-RPC ping request and checks if the server responds.
  /// A 401 response is considered "reachable" since the server is alive
  /// but requires authentication.
  /// Returns a [McpPingResult] with the status.
  static Future<McpPingResult> ping(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        return const McpPingResult.unreachable(
          errorMessage: 'Invalid URL',
        );
      }

      final response = await _dio.post(
        url,
        data: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'ping',
          'id': 1,
        }),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json, text/event-stream',
            if (headers != null) ...headers,
          },
          validateStatus: (status) => true,
        ),
      );

      final statusCode = response.statusCode ?? 0;

      // 2xx: Server responded successfully
      if (statusCode >= 200 && statusCode < 300) {
        return const McpPingResult.reachable();
      }

      // 401: Server is alive but requires auth — still consider reachable
      if (statusCode == 401) {
        return const McpPingResult.reachable();
      }

      // Other status codes are considered unreachable
      return McpPingResult.unreachable(
        errorMessage: 'HTTP $statusCode',
        httpStatusCode: statusCode,
      );
    } on DioException catch (e) {
      // 401 via exception: server is alive but requires auth
      if (e.response?.statusCode == 401) {
        return const McpPingResult.reachable();
      }

      String message;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          message = 'Connection timed out';
          break;
        case DioExceptionType.receiveTimeout:
          message = 'Response timed out';
          break;
        case DioExceptionType.connectionError:
          message = 'Could not connect';
          break;
        default:
          message = e.message ?? 'Connection failed';
      }
      return McpPingResult.unreachable(
        errorMessage: message,
        httpStatusCode: e.response?.statusCode,
      );
    } catch (e) {
      return McpPingResult.unreachable(
        errorMessage: e.toString(),
      );
    }
  }
}
