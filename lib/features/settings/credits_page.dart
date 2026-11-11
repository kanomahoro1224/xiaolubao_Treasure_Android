import 'package:flutter/material.dart';

import '../kano/domain/kano_text.dart';
import '../kano/presentation/kano_haptics.dart';
import '../kano/presentation/kano_image.dart';
import '../kano/presentation/kano_launcher.dart';
import '../kano/presentation/kano_palette.dart';

/// 贡献者页，对应鸿蒙 `AboutPage.ets` 的 `CreditsPane`。
///
/// 为什么是页面而不是底部抽屉：鸿蒙那边宽屏直接把 `CreditsPane` 摆在右半边，
/// 手机才用 `CreditsSheetBuilder`。这里统一成整页推入 —— 一个只读名单，
/// 没有需要保留的上下文，弹层反而挡视线、还要多一次下滑关闭。
class CreditsPage extends StatelessWidget {
  const CreditsPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
        builder: (_) => const CreditsPage(),
      );

  /// 与鸿蒙 `creditAvatar()` 同一批地址
  static const _avatars = <String, String>{
    'yexca':
        'https://i1.hdslb.com/bfs/face/39ac8111d76e93b0a3295699751d71fc3ae6cdb1.jpg',
    '鹿可可': 'https://q1.qlogo.cn/g?b=qq&nk=3497593286&s=640',
    '往時THEPast': 'https://q1.qlogo.cn/g?b=qq&nk=2652114501&s=640',
    '雁部令夏': 'https://q1.qlogo.cn/g?b=qq&nk=1430880258&s=640',
    '懒懒小星鱼': 'https://q1.qlogo.cn/g?b=qq&nk=994231850&s=640',
    '飞蛾不是飞轮𐂂': 'https://q1.qlogo.cn/g?b=qq&nk=1914708177&s=640',
    '花守雨铃': 'https://q1.qlogo.cn/g?b=qq&nk=2421068998&s=640',
  };

  /// 与鸿蒙 `getCreditItemUrl()` 同一批地址
  static const _urls = <String, String>{
    'yexca': 'https://space.bilibili.com/318225502',
    '鹿可可': 'https://space.bilibili.com/426276698',
    '往時THEPast': 'https://space.bilibili.com/73376259',
    '花守雨铃': 'https://space.bilibili.com/238157726',
    'Kano 双重验证器(Harmony)':
        'https://appgallery.huawei.com/app/detail?id=kano.Authenticator.xiaolubao&channelId=SHARE&source=appshare',
    'Kano 双重验证器简介视频': 'https://www.bilibili.com/video/BV1s3TK6yE6u',
    'Kano 弹幕通知(Windows)':
        'https://apps.microsoft.com/detail/9pl8ckd2ffp3?hl=zh-CN&gl=CN',
    'Kano 弹幕通知简介视频': 'https://www.bilibili.com/video/BV12B7r6uEBY/',
  };

  @override
  Widget build(BuildContext context) {
    final palette = KanoPalette.of(context);
    final isLight = palette.isLight;

    return Scaffold(
      backgroundColor: isLight ? const Color(0xFFF1F3F5) : const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(palette: palette),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  MediaQuery.sizeOf(context).width < 600
                      ? MediaQuery.sizeOf(context).width * 0.08
                      : 40,
                  0,
                  MediaQuery.sizeOf(context).width < 600
                      ? MediaQuery.sizeOf(context).width * 0.08
                      : 40,
                  24,
                ),
                children: [
                  const SizedBox(height: 110),
                  Text(
                    KanoText.ui('about_credits_title'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Credits',
                    style: TextStyle(fontSize: 12, color: palette.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  _CreditSection(
                    title: KanoText.ui('about_credits_main_devs'),
                    palette: palette,
                    entries: const [
                      _CreditEntry(name: 'yexca'),
                      _CreditEntry(name: '鹿可可'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _CreditSection(
                    title: KanoText.ui('about_credits_assets'),
                    palette: palette,
                    entries: const [
                      _CreditEntry(
                        name: '花守雨铃',
                        labelKey: 'about_credits_wallpaper_artist_label',
                      ),
                      _CreditEntry(
                        name: '往時THEPast',
                        labelKey: 'about_credits_icon_artist_label',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _CreditSection(
                    title: KanoText.ui('about_credits_push_service'),
                    palette: palette,
                    entries: const [_CreditEntry(name: '雁部令夏')],
                  ),
                  const SizedBox(height: 16),
                  _CreditSection(
                    title: KanoText.ui('about_credits_early_testers'),
                    palette: palette,
                    entries: const [
                      _CreditEntry(name: '懒懒小星鱼'),
                      _CreditEntry(name: '飞蛾不是飞轮𐂂'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _CreditSection(
                    title: KanoText.ui('about_credits_other_projects'),
                    palette: palette,
                    entries: const [
                      _CreditEntry(name: 'Kano 双重验证器(Harmony)'),
                      _CreditEntry(name: 'Kano 双重验证器简介视频'),
                      _CreditEntry(name: 'Kano 弹幕通知(Windows)'),
                      _CreditEntry(name: 'Kano 弹幕通知简介视频'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 标题栏：左上返回 + 「关于 / About」，对应鸿蒙 `AdaptiveTopBarTitle`
class _TopBar extends StatelessWidget {
  const _TopBar({required this.palette});

  final KanoPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              KanoHaptics.tap();
              Navigator.of(context).maybePop();
            },
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.chevron_left_rounded,
                size: 26,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                KanoText.ui('home_about'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                'About',
                style: TextStyle(fontSize: 11, color: palette.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreditEntry {
  const _CreditEntry({required this.name, this.labelKey});

  final String name;

  /// 素材那两行带前置说明（「默认壁纸画师：」「图标画师：」）
  final String? labelKey;
}

class _CreditSection extends StatelessWidget {
  const _CreditSection({
    required this.title,
    required this.palette,
    required this.entries,
  });

  final String title;
  final KanoPalette palette;
  final List<_CreditEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: palette.berry,
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in entries) ...[
          _CreditRow(entry: entry, palette: palette),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.entry, required this.palette});

  final _CreditEntry entry;
  final KanoPalette palette;

  static const _linkColor = Color(0xFF007DFF);

  @override
  Widget build(BuildContext context) {
    final avatar = CreditsPage._avatars[entry.name];
    final url = CreditsPage._urls[entry.name] ?? '';

    final name = Text(
      entry.name,
      style: const TextStyle(
        fontSize: 14,
        height: 1.43,
        color: _linkColor,
        decoration: TextDecoration.underline,
        decorationColor: _linkColor,
      ),
    );

    final row = Row(
      children: [
        if (entry.labelKey != null)
          Flexible(
            child: Text(
              KanoText.ui(entry.labelKey!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.43,
                color: palette.textSecondary,
              ),
            ),
          ),
        if (avatar != null) ...[
          const SizedBox(width: 4),
          KanoAvatar(url: avatar, name: entry.name, size: 24),
          const SizedBox(width: 6),
        ] else if (entry.labelKey != null)
          const SizedBox(width: 4),
        // 只有带链接的条目才画下划线，纯文案（微博、测试者之外的说明）保持素色
        url.isEmpty
            ? Text(
                entry.name,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.43,
                  color: palette.textSecondary,
                ),
              )
            : name,
      ],
    );

    if (url.isEmpty) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        KanoHaptics.tap();
        KanoLauncher.open(context, url);
      },
      child: row,
    );
  }
}
