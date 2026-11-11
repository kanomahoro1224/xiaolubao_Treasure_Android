import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../home/home_edit_mode.dart';
import '../kano/data/kano_cache.dart';
import '../kano/data/kano_repository.dart';
import '../kano/domain/kano_server.dart';
import '../kano/domain/kano_text.dart';
import '../kano/presentation/kano_haptics.dart';
import '../kano/presentation/kano_palette.dart';
import 'credits_page.dart';
import 'settings_controller.dart';
import 'settings_strings.dart';

/// 设置。
///
/// 分组对齐鸿蒙设置页截图：外观（语言下拉、新版玻璃、个性化）、通知、其它。
/// 语言仍含「跟随系统」，只是收进右侧下拉，不再铺一排胶囊。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with AutomaticKeepAliveClientMixin {
  /// 底栏切页用 PageView 承载，离开视口时保住滚动位置与缓存统计
  @override
  bool get wantKeepAlive => true;

  int _cacheCount = 0;
  int _cacheChars = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshCacheStats();
  }

  Future<void> _refreshCacheStats() async {
    final (count, chars) = await KanoCache.stats();
    if (!mounted) return;
    setState(() {
      _cacheCount = count;
      _cacheChars = chars;
    });
  }

  void _set(VoidCallback change) {
    KanoHaptics.select();
    change();
  }

  Future<void> _pickServer() async {
    KanoHaptics.tap();
    final settings = SettingsController.instance;
    final current = settings.customBase;
    final choice = await showModalBottomSheet<_ServerChoice>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final palette = KanoPalette.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Option(
                title: SettingsStrings.t('server_auto'),
                subtitle: '${KanoServer.defaultBase} → ${KanoServer.fallbackBase}',
                selected: current.isEmpty,
                palette: palette,
                onTap: () => Navigator.of(sheetContext).pop(const _ServerChoice.auto()),
              ),
              _Option(
                title: SettingsStrings.t('server_primary'),
                subtitle: KanoServer.defaultBase,
                selected: false,
                palette: palette,
                onTap: () => Navigator.of(sheetContext)
                    .pop(const _ServerChoice.fixed(KanoServer.defaultBase)),
              ),
              _Option(
                title: SettingsStrings.t('server_fallback'),
                subtitle: KanoServer.fallbackBase,
                selected: false,
                palette: palette,
                onTap: () => Navigator.of(sheetContext)
                    .pop(const _ServerChoice.fixed(KanoServer.fallbackBase)),
              ),
              _Option(
                title: SettingsStrings.t('server_custom'),
                subtitle: current.isEmpty ? SettingsStrings.t('server_custom_hint') : current,
                selected: current.isNotEmpty,
                palette: palette,
                onTap: () => Navigator.of(sheetContext).pop(const _ServerChoice.custom()),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (choice == null || !mounted) return;
    if (choice.auto) {
      await settings.setCustomBase('');
      await settings.clearCache();
      await _refreshCacheStats();
      return;
    }
    if (!choice.custom) {
      await settings.setCustomBase(choice.base);
      await settings.clearCache();
      await _refreshCacheStats();
      return;
    }
    final input = await _askCustomBase(current);
    if (input == null || !mounted) return;
    await settings.setCustomBase(input);
    await settings.clearCache();
    await _refreshCacheStats();
  }

  Future<String?> _askCustomBase(String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(SettingsStrings.t('server_custom')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(hintText: SettingsStrings.t('server_custom_hint')),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(SettingsStrings.t('action_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(SettingsStrings.t('action_ok')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _clearCache() async {
    KanoHaptics.warn();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(SettingsStrings.t('cache_clear')),
        content: Text(SettingsStrings.t('cache_clear_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(SettingsStrings.t('action_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(SettingsStrings.t('action_ok')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await SettingsController.instance.clearCache();
    await _refreshCacheStats();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(SettingsStrings.t('cache_cleared'));
  }

  Future<void> _subscribeCalendar() async {
    KanoHaptics.tap();
    final url = KanoRepository.instance.calendarIcsUrl;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final palette = KanoPalette.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(KanoGap.page, 0, KanoGap.page, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SettingsStrings.t('calendar_sub'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  SettingsStrings.t('calendar_sub_desc'),
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: palette.textSecondary),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: palette.chipBg,
                    borderRadius: BorderRadius.circular(KanoRadius.row),
                    border: Border.all(color: palette.hairline),
                  ),
                  child: SelectableText(
                    url,
                    style: TextStyle(fontSize: 12, color: palette.textPrimary),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: url));
                          if (!sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop();
                        },
                        child: Text(SettingsStrings.t('action_copy')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toast(String message) {
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final palette = KanoPalette.of(context);
    final settings = SettingsController.instance;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        // SlidingSegment 的开关文案：下标 0 = 关，1 = 开。
        final onOff = [KanoText.ui('setting_off'), KanoText.ui('setting_on')];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                KanoText.ui('tab_settings'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: palette.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _Section(
              title: KanoText.ui('settings_category_appearance'),
              palette: palette,
              children: [
                _DropRow(
                  title: KanoText.ui('settings_language'),
                  palette: palette,
                  value: [
                    KanoText.ui('lang_follow_system'),
                    KanoText.ui('lang_zh'),
                    KanoText.ui('lang_zh_hant'),
                    KanoText.ui('lang_ja'),
                    KanoText.ui('lang_en'),
                  ][settings.langMode.clamp(0, 4).toInt()],
                  options: [
                    KanoText.ui('lang_follow_system'),
                    KanoText.ui('lang_zh'),
                    KanoText.ui('lang_zh_hant'),
                    KanoText.ui('lang_ja'),
                    KanoText.ui('lang_en'),
                  ],
                  selected: settings.langMode,
                  onSelected: (index) => _set(() => settings.setLangMode(index)),
                ),
                _NavRow(
                  title: KanoText.ui('settings_category_personalize'),
                  subtitle: KanoText.ui('settings_category_personalize_desc'),
                  palette: palette,
                  onTap: () {
                    KanoHaptics.tap();
                    // 与鸿蒙 `openPersonalization()` 一致：置编辑态，
                    // 外壳收到后切回主页并把整页缩到 0.82。
                    HomeEditMode.instance.enter();
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),
            _Section(
              title: KanoText.ui('settings_category_notify'),
              palette: palette,
              children: [
                _DropRow(
                  title: KanoText.ui('setting_push_enabled'),
                  subtitle: KanoText.ui('setting_push_enabled_desc'),
                  palette: palette,
                  value: settings.pushEnabled ? onOff[1] : onOff[0],
                  options: onOff,
                  selected: settings.pushEnabled ? 1 : 0,
                  onSelected: (index) {
                    _onPushEnabled(index == 1);
                  },
                ),
                _DropRow(
                  title: KanoText.ui('setting_push_live'),
                  subtitle: KanoText.ui('setting_push_live_desc'),
                  palette: palette,
                  value: settings.pushLive ? onOff[1] : onOff[0],
                  options: onOff,
                  selected: settings.pushLive ? 1 : 0,
                  disabled: !settings.pushEnabled,
                  onSelected: (index) => _set(() => settings.setPushLive(index == 1)),
                ),
                _DropRow(
                  title: KanoText.ui('setting_push_video'),
                  subtitle: KanoText.ui('setting_push_video_desc'),
                  palette: palette,
                  value: settings.pushVideo ? onOff[1] : onOff[0],
                  options: onOff,
                  selected: settings.pushVideo ? 1 : 0,
                  disabled: !settings.pushEnabled,
                  onSelected: (index) => _set(() => settings.setPushVideo(index == 1)),
                ),
                _DropRow(
                  title: KanoText.ui('setting_push_post'),
                  subtitle: KanoText.ui('setting_push_post_desc'),
                  palette: palette,
                  value: settings.pushPost ? onOff[1] : onOff[0],
                  options: onOff,
                  selected: settings.pushPost ? 1 : 0,
                  disabled: !settings.pushEnabled,
                  onSelected: (index) => _set(() => settings.setPushPost(index == 1)),
                ),
                _DropRow(
                  title: KanoText.ui('setting_push_language'),
                  subtitle: KanoText.ui('setting_push_language_desc'),
                  palette: palette,
                  value: _pushLanguageLabel(settings.pushLanguage),
                  options: [
                    KanoText.ui('setting_push_language_follow'),
                    KanoText.ui('lang_zh'),
                    KanoText.ui('lang_zh_hant'),
                    KanoText.ui('lang_ja'),
                    KanoText.ui('lang_en'),
                  ],
                  selected: settings.pushLanguage.clamp(0, 4).toInt(),
                  disabled: !settings.pushEnabled,
                  onSelected: (index) => _set(() => settings.setPushLanguage(index)),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _Section(
              title: KanoText.ui('setting_section_others'),
              palette: palette,
              children: [
                _NavRow(
                  title: KanoText.ui('home_about'),
                  palette: palette,
                  onTap: () {
                    KanoHaptics.tap();
                    // 整页推入，不用底部抽屉（鸿蒙是 Navigation 里的独立页）
                    Navigator.of(context).push(CreditsPage.route());
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _onPushEnabled(bool value) async {
    final ok = await SettingsController.instance.setPushEnabled(value);
    if (!ok && mounted) {
      _toast(KanoText.ui('setting_push_permission_denied'));
    } else if (ok) {
      KanoHaptics.select();
    }
  }

  String _pushLanguageLabel(int index) {
    const keys = [
      'setting_push_language_follow',
      'lang_zh',
      'lang_zh_hant',
      'lang_ja',
      'lang_en',
    ];
    final i = index.clamp(0, keys.length - 1).toInt();
    return KanoText.ui(keys[i]);
  }

  static String _size(int chars) {
    // 快照是 JSON 文本，按 UTF-8 粗算（中文 3 字节最坏情况取 2 更接近实际 JSON）
    final bytes = chars * 2;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

// ---------------------------------------------------------------------------
// 行与分组
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.palette,
    required this.children,
  });

  final String title;
  final KanoPalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: palette.textSecondary,
            ),
          ),
        ),
        KanoSurface(
          padding: EdgeInsets.zero,
          radius: KanoRadius.panel,
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
        ),
      ],
    );
  }
}

/// 标题 + 说明 + 右侧 Select。对齐鸿蒙 `SlidingSegment`：高 36、圆角 18、14 号粗体。
/// 开关项的 options 必须是 [关, 开]，下标 0/1。
class _DropRow extends StatelessWidget {
  const _DropRow({
    required this.title,
    required this.palette,
    required this.value,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.subtitle,
    this.disabled = false,
  });

  final String title;
  final String? subtitle;
  final String value;
  final KanoPalette palette;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelected;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final menu = PopupMenuButton<int>(
      enabled: !disabled,
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (var i = 0; i < options.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Text(
              options[i],
              style: TextStyle(
                fontSize: 14,
                fontWeight: i == selected ? FontWeight.bold : FontWeight.w500,
                color: i == selected ? palette.berry : palette.textPrimary,
              ),
            ),
          ),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: palette.isLight ? const Color(0x0D000000) : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: palette.isLight ? Colors.black : Colors.white,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 20,
              color: palette.isLight ? Colors.black : Colors.white,
            ),
          ],
        ),
      ),
    );
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _Label(title: title, subtitle: subtitle, palette: palette)),
            const SizedBox(width: 8),
            menu,
          ],
        ),
      ),
    );
  }
}

/// 标题 + 说明 + 右侧值 + 箭头（可点行）
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.title,
    required this.palette,
    this.subtitle,
    this.value,
    this.onTap,
    this.chevron = true,
    this.trailingIcon,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final KanoPalette palette;
  final VoidCallback? onTap;
  final bool chevron;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _Label(title: title, subtitle: subtitle, palette: palette)),
            if (value != null && value!.isNotEmpty) ...[
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
                ),
              ),
            ],
            if (trailingIcon != null) ...[
              const SizedBox(width: 6),
              Icon(trailingIcon, size: 18, color: palette.textTertiary),
            ] else if (chevron) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 20, color: palette.textTertiary),
            ],
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.title, required this.palette, this.subtitle});

  final String title;
  final String? subtitle;
  final KanoPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            height: 1.25,
            color: palette.textPrimary,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, height: 1.3, color: palette.textTertiary),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 服务器选择
// ---------------------------------------------------------------------------

class _ServerChoice {
  const _ServerChoice.auto() : auto = true, custom = false, base = '';
  const _ServerChoice.fixed(this.base) : auto = false, custom = false;
  const _ServerChoice.custom() : auto = false, custom = true, base = '';

  final bool auto;
  final bool custom;
  final String base;
}

class _Option extends StatelessWidget {
  const _Option({
    required this.title,
    required this.selected,
    required this.palette,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final KanoPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(title, style: TextStyle(fontSize: 15, color: palette.textPrimary)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
            ),
      trailing: selected
          ? Icon(Icons.check_rounded, size: 20, color: palette.berry)
          : const SizedBox(width: 20),
    );
  }
}
