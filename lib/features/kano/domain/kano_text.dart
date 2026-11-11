import 'dart:io' show Platform;

import 'kano_strings.dart';

/// 数据层要露到界面上的短文案（状态 / 类型 / 星期 / 月份）。
///
/// 与鸿蒙 `KanoText` 同一口径：`KanoEvent`、`KanoVideo` 这些是纯数据对象，
/// 构造时没有 UI 上下文，而它们要跟着「数据」走 —— 同一份 dashboard 在日语界面
/// 就该显示「予定」而不是「待开始」。所以这里按当前 App 语言直接选表。
///
/// 每行按 简中 / 繁中 / 日 / 英 排列。
class KanoText {
  KanoText._();

  /// 0 简中 / 1 繁中 / 2 日 / 3 英
  static int _langIndex = -1;

  static int get langIndex {
    if (_langIndex >= 0) return _langIndex;
    var preferred = '';
    try {
      preferred = Platform.localeName.toLowerCase().replaceAll('_', '-');
    } catch (_) {
      preferred = '';
    }
    if (preferred.startsWith('ja')) {
      _langIndex = 2;
    } else if (preferred.startsWith('en')) {
      _langIndex = 3;
    } else if (preferred.startsWith('zh-hant') ||
        preferred.startsWith('zh-tw') ||
        preferred.startsWith('zh-hk') ||
        preferred.startsWith('zh-mo')) {
      _langIndex = 1;
    } else if (preferred.startsWith('zh')) {
      _langIndex = 0;
    } else {
      _langIndex = 3;
    }
    return _langIndex;
  }

  /// 测试或设置页改语言时用；传 -1 恢复自动判定。
  static void overrideLangIndex(int index) {
    _langIndex = index >= 0 && index <= 3 ? index : -1;
  }

  static String _pick(List<String> row) {
    final index = langIndex;
    if (index > 0 && index < row.length && row[index].isNotEmpty) return row[index];
    return row[0];
  }

  static String ui(String key) {
    // 优先查从鸿蒙资源表生成的全量四语表（2568 条），再退回数据层的短表。
    final full = kanoStrings[key];
    if (full != null && full.isNotEmpty) return _pick(full);
    final row = kanoUi[key];
    return row == null ? key : _pick(row);
  }

  static String uiFmt(String key, String arg) => ui(key).replaceFirst('%s', arg);

  /// 周一起算的星期短名（日历表头），0 = 周一
  static String weekShort(int index) {
    final row = weekShortRows[langIndex];
    return row[((index % 7) + 7) % 7];
  }

  /// 周一起算的星期全名（日程日期行）
  static String weekFull(int index) {
    final row = weekFullRows[langIndex];
    return row[((index % 7) + 7) % 7];
  }

  /// 日历头部的大月份：1-12
  static String monthTitle(int month) {
    final index = (month - 1).clamp(0, 11);
    return langIndex == 3 ? monthTitlesEn[index] : monthTitlesZh[index];
  }

  /// 服务端静态种子文案（历程 / 资料入口）按语言替换；表里没有就返回原文。
  static String localizeSeed(String text) {
    if (text.isEmpty) return text;
    final row = kanoSeedCopy[text];
    if (row == null) return text;
    return _pick(row);
  }

  /// 当前 App 语言对应的 BCP-47 标签（取译文时用）。
  static String get preferredLang => switch (langIndex) {
        2 => 'ja',
        3 => 'en',
        1 => 'zh-Hant',
        _ => 'zh-CN',
      };
}

/// 数据层短文案表。key 与鸿蒙 `KANO_UI` 完全一致，便于逐条核对。
const kanoUi = <String, List<String>>{
  'time_tbd': ['时间待定', '時間未定', '時間未定', 'Time TBD'],
  'approximate': ['约 %s', '約 %s', '約%s', '~%s'],
  'local_time': ['本地 %s', '本地 %s', '現地 %s', 'Local %s'],
  'status_cancelled': ['已取消', '已取消', '中止', 'Cancelled'],
  'status_live': ['直播中', '直播中', '配信中', 'On air'],
  'status_ended': ['已结束', '已結束', '終了', 'Ended'],
  'status_released': ['已发布', '已發佈', '公開済み', 'Released'],
  'status_scheduled': ['即将', '即將', '予定', 'Upcoming'],
  'provenance_confirmed': ['人工确认', '人工確認', '手動確認', 'Confirmed'],
  'provenance_auto': ['自动识别', '自動識別', '自動抽出', 'Auto-detected'],
  'cancel_review': [
    'LLM 判断疑似取消',
    'LLM 判斷疑似取消',
    'LLM が中止の可能性を判断',
    'LLM flagged possible cancellation'
  ],
  'cancel_manual': [
    '人工标记为取消',
    '人工標記為取消',
    '手動で中止に設定',
    'Marked cancelled by an operator'
  ],
  'kind_song': ['歌回', '歌回', '歌枠', 'Song'],
  'kind_game': ['游戏播', '遊戲播', 'ゲーム配信', 'Gameplay'],
  'kind_talk': ['杂谈', '雜談', '雑談', 'Talk'],
  'kind_video': ['投稿', '投稿', '動画', 'Upload'],
  'kind_live': ['直播', '直播', '配信', 'Stream'],
  'kind_short': ['短片', '短片', 'ショート', 'Short'],
  'hero_kicker': [
    'Virtual Artist · ミリプロ SONA',
    'Virtual Artist · ミリプロ SONA',
    'Virtual Artist · ミリプロ SONA',
    'Virtual Artist · Milpro SONA'
  ],
  'hero_catchphrase': [
    'みんなの毎日を、まほろばに。',
    'みんなの毎日を、まほろばに。',
    'みんなの毎日を、まほろばに。',
    'みんなの毎日を、まほろばに。'
  ],
  'filter_all': ['全部', '全部', 'すべて', 'All'],
  'filter_kano': ['鹿乃', '鹿乃', '鹿乃まほろ', 'Kano'],
  'filter_kanotic': ['鹿乃桜帆', '鹿乃桜帆', '鹿乃tic', 'Kanotic'],
  'tab_video': ['视频', '影片', '動画', 'Videos'],
  'tab_dynamic': ['动态', '動態', 'ダイナミック', 'Posts'],
  'tab_live': ['直播', '直播', '配信', 'Live'],
  'tab_shorts': ['Shorts', 'Shorts', 'Shorts', 'Shorts'],
};

/// 服务端静态种子文案表（历程 / 资料入口），key 即服务端原文。
const kanoSeedCopy = <String, List<String>>{
  '鹿乃まほろ': ['鹿乃まほろ', '鹿乃まほろ', '鹿乃まほろ', 'Kano Mahoro'],
  '8 月加入ミリプロSONA，以新形象开始配信。': [
    '8 月加入ミリプロSONA，以新形象开始配信。',
    '8 月加入ミリプロSONA，以新形象開始配信。',
    '8 月にミリプロSONA へ加入し、新しい姿で配信を開始。',
    'Joined Milpro SONA in August and began streaming with a new look.'
  ],
  '与ろん组成音乐组合。': [
    '与ろん组成音乐组合。',
    '與ろん組成音樂組合。',
    'ろんと音楽ユニットを結成。',
    'Formed a music unit with Ron.'
  ],
  '以粉发双马尾的まほろ形象开始配信。': [
    '以粉发双马尾的まほろ形象开始配信。',
    '以粉髮雙馬尾的まほろ形象開始配信。',
    'ピンク髪ツインテールのまほろとして配信を開始。',
    'Began streaming as Mahoro, with pink twin tails.'
  ],
  '花寄女子寮': ['花寄女子寮', '花寄女子寮', '花寄女子寮', 'Hanayori Joshiryo'],
  '以花寄女子寮成员身份开始 VTuber 活动。': [
    '以花寄女子寮成员身份开始 VTuber 活动。',
    '以花寄女子寮成員身分開始 VTuber 活動。',
    '花寄女子寮のメンバーとして VTuber 活動を開始。',
    'Started VTuber activities as a member of Hanayori Joshiryo.'
  ],
  'Major debut': ['主流出道', '主流出道', 'メジャーデビュー', 'Major debut'],
  '以《Stella-rium》正式出道。': [
    '以《Stella-rium》正式出道。',
    '以《Stella-rium》正式出道。',
    '「Stella-rium」でメジャーデビュー。',
    'Debuted with “Stella-rium”.'
  ],
  'First album': ['首张专辑', '首張專輯', '初のソロアルバム', 'First album'],
  'Released the first solo album, “Bambino”, on January 16.': [
    '1 月 16 日发行首张个人专辑《ばんび～の》。',
    '1 月 16 日發行首張個人專輯《ばんび～の》。',
    '1 月 16 日に初のソロアルバム「ばんび～の」をリリース。',
    'Released the first solo album, “Bambino”, on January 16.'
  ],
  '第一首投稿': ['第一首投稿', '第一首投稿', 'はじめての投稿', 'First upload'],
  '从 NicoNico 的歌唱投稿开始。': [
    '从 NicoNico 的歌唱投稿开始。',
    '從 NicoNico 的歌唱投稿開始。',
    'ニコニコ動画への歌ってみた投稿から。',
    'Started with song covers on NicoNico.'
  ],
  '@kano_2525 · 近况首发': [
    '@kano_2525 · 近况首发',
    '@kano_2525 · 近況首發',
    '@kano_2525 · 最新情報はまずここ',
    '@kano_2525 · News first'
  ],
  '@_Kanotic · 个人向': [
    '@_Kanotic · 个人向',
    '@_Kanotic · 個人向',
    '@_Kanotic · プライベート',
    '@_Kanotic · Personal'
  ],
  '鹿乃まほろ · 配信与歌': [
    '鹿乃まほろ · 配信与歌',
    '鹿乃まほろ · 配信與歌',
    '鹿乃まほろ · 配信と歌',
    'Kano Mahoro · Streams and songs'
  ],
  '鹿乃 / MKLNtic · 旧频道': [
    '鹿乃 / MKLNtic · 旧频道',
    '鹿乃 / MKLNtic · 舊頻道',
    '鹿乃 / MKLNtic · 以前のチャンネル',
    'Kano / MKLNtic · Earlier channel'
  ],
  '鹿乃ちゃん · 中文圈': [
    '鹿乃ちゃん · 中文圈',
    '鹿乃ちゃん · 中文圈',
    '鹿乃ちゃん · 中国語圏向け',
    'Kano-chan · Chinese-speaking fans'
  ],
  '直播存档与通知': ['直播存档与通知', '直播存檔與通知', '配信アーカイブとお知らせ', 'Stream archives and notices'],
  'ミリプロ / SONA': ['ミリプロ / SONA', 'ミリプロ / SONA', 'ミリプロ / SONA', 'Milpro / SONA'],
  '事务所个人页 · 资料与公告': [
    '事务所个人页 · 资料与公告',
    '事務所個人頁 · 資料與公告',
    '事務所のタレントページ · プロフィールとお知らせ',
    'Agency talent page · Profile and news'
  ],
  '早期投稿存档': ['早期投稿存档', '早期投稿存檔', '初期の投稿アーカイブ', 'Early upload archive'],
  'official site': ['官方网站', '官方網站', '公式サイト', 'Official site'],
  'ミリプロ shop': ['ミリプロ shop', 'ミリプロ shop', 'ミリプロ shop', 'Milpro shop'],
  '事务所官方商店': ['事务所官方商店', '事務所官方商店', '事務所公式ショップ', 'Official agency shop'],
};

/// 周一起算（日历表头用短名）
const weekShortRows = <List<String>>[
  ['一', '二', '三', '四', '五', '六', '日'],
  ['一', '二', '三', '四', '五', '六', '日'],
  ['月', '火', '水', '木', '金', '土', '日'],
  ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
];

/// 周一起算（「即将开始」的日期行用全名）
const weekFullRows = <List<String>>[
  ['周一', '周二', '周三', '周四', '周五', '周六', '周日'],
  ['週一', '週二', '週三', '週四', '週五', '週六', '週日'],
  ['月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日'],
  ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
];

const monthTitlesZh = <String>[
  '1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'
];

const monthTitlesEn = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
