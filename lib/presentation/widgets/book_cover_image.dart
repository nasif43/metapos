import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Reusable presentation widget for displaying Odoo 19 book cover images
/// from base64 strings with automatic decoding, fallback placeholders,
/// and edge-case resilience.
class BookCoverImage extends StatelessWidget {
  final String? imageBase64;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? fallback;

  /// In-memory cache of decoded byte arrays. Prevents re-decoding base64 strings
  /// and recreation of memory buffers on widget rebuilds, completely eliminating image jitter/flicker.
  static final Map<String, Uint8List> _decodedCache = {};

  const BookCoverImage({
    super.key,
    required this.imageBase64,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveFallback = fallback ??
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: borderRadius,
          ),
          child: Center(
            child: Icon(
              Icons.menu_book_rounded,
              size: (width != null && width! < 60) ? 24 : 44,
              color: AppColors.textMuted.withValues(alpha: 0.4),
            ),
          ),
        );

    if (imageBase64 == null) {
      return effectiveFallback;
    }

    var rawString = imageBase64!.trim();
    if (rawString.isEmpty) {
      return effectiveFallback;
    }

    // 1. Strip Data URI scheme header if present (e.g. "data:image/png;base64,...")
    if (rawString.startsWith('data:') && rawString.contains(',')) {
      rawString = rawString.substring(rawString.indexOf(',') + 1).trim();
    } else if (rawString.contains(',')) {
      rawString = rawString.split(',').last.trim();
    }

    // 2. Remove all internal whitespace/newlines (e.g. RFC 2045 MIME wraps)
    rawString = rawString.replaceAll(RegExp(r'\s+'), '');

    Uint8List? bytes = _decodedCache[rawString];
    if (bytes == null) {
      try {
        bytes = base64Decode(rawString);
        _decodedCache[rawString] = bytes;
      } catch (_) {
        // Handles corrupt padding, invalid characters, or truncated strings
        return effectiveFallback;
      }
    }

    if (bytes.isEmpty) {
      return effectiveFallback;
    }

    Widget imageWidget = Image.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true, // Prevents blank flickering frame during widget rebuilds
      errorBuilder: (context, error, stackTrace) => effectiveFallback,
    );

    if (borderRadius != null && borderRadius != BorderRadius.zero) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
