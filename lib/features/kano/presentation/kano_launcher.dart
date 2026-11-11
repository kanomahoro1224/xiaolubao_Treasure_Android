import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/kano_text.dart';

/// 打开外部链接。鸿蒙侧走 `startAbility(viewData)`，Flutter 侧用 `url_launcher`。
class KanoLauncher {
  KanoLauncher._();

  static Future<void> open(BuildContext context, String rawUrl) async {
    if (rawUrl.isEmpty) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    if (uri.scheme != 'https' && uri.scheme != 'http') return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) _toast(context, KanoText.ui('feed_no_url_handler'));
    } catch (_) {
      if (context.mounted) _toast(context, KanoText.ui('feed_no_url_handler'));
    }
  }

  static void _toast(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }
}
