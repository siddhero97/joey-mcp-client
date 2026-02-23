import 'package:flutter/foundation.dart';
import 'package:mcp_dart/mcp_dart.dart' show TextResourceContents;
import '../models/mcp_app_ui.dart';
import 'mcp_client_service.dart';

/// Service for managing MCP App UI resources.
/// Handles caching, prefetching, and CSP metadata extraction.
class McpAppUiService {
  /// In-memory cache keyed by resource URI
  final Map<String, McpAppUiResource> _cache = {};

  /// Get a cached UI resource by URI
  McpAppUiResource? getResource(String uri) => _cache[uri];

  /// Invalidate all cached resources
  void invalidateAll() {
    _cache.clear();
  }

  /// Invalidate a specific cached resource
  void invalidate(String uri) {
    _cache.remove(uri);
  }

  /// Prefetch UI resources for all tools that have UI resource URIs.
  /// Call this after listing tools from a server.
  Future<void> prefetchUiResources(
    List<McpTool> tools,
    McpClientService client,
  ) async {
    for (final tool in tools) {
      final uri = tool.uiResourceUri;
      if (uri == null) continue;
      if (_cache.containsKey(uri)) continue; // Already cached

      try {
        final result = await client.readResource(uri);
        if (result.contents.isNotEmpty) {
          final content = result.contents.first;
          String? html;

          // Extract HTML from resource content
          if (content is TextResourceContents) {
            html = content.text;
          }

          if (html != null) {
            // Extract _meta from the result if available
            final resultMeta = result.meta;
            final uiMeta = resultMeta?['ui'] as Map<String, dynamic>?;
            final cspMeta = uiMeta?['csp'] as Map<String, dynamic>?;
            final prefersBorder = uiMeta?['prefersBorder'] as bool? ?? true;

            _cache[uri] = McpAppUiResource(
              resourceUri: uri,
              html: html,
              cspMeta: cspMeta,
              uiMeta: uiMeta,
              prefersBorder: prefersBorder,
            );
            debugPrint('MCP UI: Cached resource for $uri');
          }
        }
      } catch (e) {
        debugPrint('MCP UI: Failed to prefetch resource $uri: $e');
      }
    }
  }

  /// Build a Content-Security-Policy string from CSP metadata.
  /// The CSP metadata comes from _meta.ui.csp on the resource content.
  ///
  /// Because the HTML is loaded via `loadData()` with `baseUrl: about:blank`,
  /// `'self'` resolves to `about:blank` and is effectively useless for
  /// allowing any real resources. We therefore allow `https:` by default
  /// for script, style, font, image, and connect sources. The MCP server
  /// can further extend these via the cspMeta fields.
  String buildCsp(Map<String, dynamic>? cspMeta) {
    // Base CSP — permissive enough for loadData() (about:blank origin)
    // but still blocks dangerous patterns like object-src and form-action.
    final directives = <String, List<String>>{
      'default-src': ["'self'", 'https:', 'data:'],
      'script-src': ["'self'", "'unsafe-inline'", "'unsafe-eval'", 'https:', 'data:', 'blob:'],
      'style-src': ["'self'", "'unsafe-inline'", 'https:', 'data:'],
      'img-src': ["'self'", 'data:', 'blob:', 'https:'],
      'font-src': ["'self'", 'data:', 'https:'],
      'connect-src': ["'self'", 'https:', 'data:', 'blob:'],
      'media-src': ["'self'", 'data:', 'blob:', 'https:'],
      'frame-src': ["'none'"],
      'base-uri': ["'self'"],
      'form-action': ["'self'"],
    };

    if (cspMeta != null) {
      // Add allowed connect domains
      final connectDomains = cspMeta['connectDomains'] as List?;
      if (connectDomains != null) {
        directives['connect-src']!.addAll(connectDomains.cast<String>());
      }

      // Add allowed resource domains (for images, scripts, styles)
      final resourceDomains = cspMeta['resourceDomains'] as List?;
      if (resourceDomains != null) {
        final domains = resourceDomains.cast<String>();
        directives['img-src']!.addAll(domains);
        directives['script-src']!.addAll(domains);
        directives['style-src']!.addAll(domains);
        directives['font-src']!.addAll(domains);
      }

      // Add allowed frame domains
      final frameDomains = cspMeta['frameDomains'] as List?;
      if (frameDomains != null) {
        directives['frame-src'] = frameDomains.cast<String>();
      }

      // Add allowed base URI domains
      final baseUriDomains = cspMeta['baseUriDomains'] as List?;
      if (baseUriDomains != null) {
        directives['base-uri'] = baseUriDomains.cast<String>();
      }
    }

    return directives.entries
        .map((e) => '${e.key} ${e.value.join(' ')}')
        .join('; ');
  }
}
