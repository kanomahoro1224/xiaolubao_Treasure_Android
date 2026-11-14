import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../kano/domain/kano_text.dart';
import '../kano/presentation/kano_palette.dart';
import 'app_update.dart';

/// 冷启动发现新版本时的提醒。
///
/// 三选一是刻意的：侧载分发没有应用商店兜底，只给「更新 / 关闭」两个选项时，
/// 用户要么被迫去手动装一次包，要么只能每次都点掉弹窗。分成
/// 「忽略此版本（记住版本号，更高的还会提示）」「下次再说（下次启动再问）」
/// 「前往下载（打开服务端下发的地址）」才不至于烦人。
Future<AppUpdateAction?> showAppUpdateDialog(BuildContext context, AppRelease release) {
  final palette = KanoPalette.of(context);
  final notes = release.notes.trim();

  return showDialog<AppUpdateAction>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
        decoration: BoxDecoration(
          color: palette.panelBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              KanoText.ui('update_title'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'v${AppInfo.version} → v${release.versionName.isEmpty ? release.versionCode.toString() : release.versionName}',
              style: TextStyle(fontSize: 13, color: palette.textSecondary),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: palette.chipBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  notes,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            _FilledAction(
              palette: palette,
              label: KanoText.ui('update_go'),
              onTap: () => Navigator.of(dialogContext).pop(AppUpdateAction.download),
            ),
            const SizedBox(height: 8),
            _OutlinedAction(
              palette: palette,
              label: KanoText.ui('update_later'),
              onTap: () => Navigator.of(dialogContext).pop(AppUpdateAction.later),
            ),
            const SizedBox(height: 2),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(AppUpdateAction.ignore),
                style: TextButton.styleFrom(
                  foregroundColor: palette.textTertiary,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  KanoText.ui('update_ignore'),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 执行用户在弹窗里的选择。返回值交给调用方决定要不要在本进程内再弹。
Future<void> applyAppUpdateAction(AppUpdateAction? action, AppRelease release) async {
  switch (action) {
    case AppUpdateAction.ignore:
      await AppUpdate.ignore(release.versionCode);
    case AppUpdateAction.download:
      // 统一跳分发站：内部已把网盘 / GitHub 之类的地址收敛掉，见 AppRelease.downloadUri
      final uri = release.downloadUri;
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // 没有浏览器 / 被系统拦截：什么都不做，下次启动还会再提示
      }
    case AppUpdateAction.later:
    case null:
      return;
  }
}

class _FilledAction extends StatelessWidget {
  const _FilledAction({required this.palette, required this.label, required this.onTap});

  final KanoPalette palette;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.berryBrand,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: palette.onAccent,
          ),
        ),
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({required this.palette, required this.label, required this.onTap});

  final KanoPalette palette;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.hairline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: palette.textPrimary,
          ),
        ),
      ),
    );
  }
}
