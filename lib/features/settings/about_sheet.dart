import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../kano/data/kano_repository.dart';
import '../kano/domain/kano_models.dart';
import '../kano/domain/kano_server.dart';
import '../kano/domain/kano_text.dart';
import '../kano/domain/kano_time.dart';
import '../kano/presentation/kano_haptics.dart';
import '../kano/presentation/kano_launcher.dart';
import '../kano/presentation/kano_palette.dart';
import 'settings_strings.dart';

/// 关于：应用信息 + 后端状态 + 数据来源 + 开源许可。
///
/// 鸿蒙 `AboutPage.ets` 那 1200 行里有大段音乐 App 的更新日志与致谢名单，
/// 与本工程无关，没搬。这里只留 kano-navi 客户端真的能对上号的东西，
/// 后端状态是实时打 `/api/health` 拿的，不是写死的字符串。
Future<void> showAboutSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _AboutSheet(),
  );
}

class _AboutSheet extends StatefulWidget {
  const _AboutSheet();

  @override
  State<_AboutSheet> createState() => _AboutSheetState();
}

class _AboutSheetState extends State<_AboutSheet> {
  KanoHealth? _health;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final health = await KanoRepository.instance.health();
    if (!mounted) return;
    setState(() {
      _health = health;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final ok = _health?.ok == true;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(KanoGap.page, 0, KanoGap.page, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.hairline),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/kado_sakura21.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppInfo.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${KanoText.ui('about_version_label')} ${AppInfo.version}'
                        ' (${AppInfo.build})',
                        style: TextStyle(fontSize: 12, color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Block(
              palette: palette,
              children: [
                _InfoRow(
                  palette: palette,
                  label: SettingsStrings.t('about_package'),
                  value: AppInfo.packageId,
                ),
                _InfoRow(
                  palette: palette,
                  label: SettingsStrings.t('about_build'),
                  value: 'Flutter · ${_channel()}',
                ),
                _InfoRow(
                  palette: palette,
                  label: SettingsStrings.t('about_backend'),
                  value: _loading
                      ? KanoText.ui('kano_syncing')
                      : (ok
                          ? '${SettingsStrings.t('about_backend_ok')} · ${_health?.syncStatus ?? ''}'
                          : SettingsStrings.t('about_backend_fail')),
                  valueColor: _loading ? null : (ok ? null : palette.berry),
                  onTap: _loading ? null : _load,
                ),
                _InfoRow(
                  palette: palette,
                  label: KanoText.ui('kano_synced_at').split('%s').first.trim(),
                  value: _health == null || _health!.syncStartedMs == 0
                      ? '—'
                      : KanoTime.relativeTime(_health!.syncStartedMs),
                ),
                _InfoRow(
                  palette: palette,
                  label: SettingsStrings.t('server'),
                  value: KanoServer.base,
                  onTap: () => KanoLauncher.open(context, KanoServer.base),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Block(
              palette: palette,
              children: [
                _LinkRow(
                  palette: palette,
                  label: SettingsStrings.t('about_sources'),
                  subtitle: SettingsStrings.t('about_sources_desc'),
                ),
                _LinkRow(
                  palette: palette,
                  label: SettingsStrings.t('about_site'),
                  subtitle: AppInfo.homeUrl,
                  onTap: () {
                    KanoHaptics.tap();
                    KanoLauncher.open(context, AppInfo.homeUrl);
                  },
                ),
                _LinkRow(
                  palette: palette,
                  label: SettingsStrings.t('about_licenses'),
                  onTap: () {
                    KanoHaptics.tap();
                    showLicensePage(
                      context: context,
                      applicationName: AppInfo.name,
                      applicationVersion: '${AppInfo.version}+${AppInfo.build}',
                      applicationLegalese: 'kano-navi client · Flutter',
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _channel() {
    const isRelease = bool.fromEnvironment('dart.vm.product');
    return isRelease ? 'release' : 'debug';
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.palette, required this.children});

  final KanoPalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.panelBg,
        borderRadius: BorderRadius.circular(KanoRadius.panel),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Divider(height: 1, thickness: 1, color: palette.hairline),
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.palette,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  final KanoPalette palette;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontSize: 13.5, color: palette.textPrimary)),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: valueColor ?? palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.palette,
    required this.label,
    this.subtitle,
    this.onTap,
  });

  final KanoPalette palette;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 13.5, color: palette.textPrimary),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 20, color: palette.textTertiary),
          ],
        ),
      ),
    );
  }
}
