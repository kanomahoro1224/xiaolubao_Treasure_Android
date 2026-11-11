import '../kano/domain/kano_text.dart';

/// 设置页里 Flutter 侧新增的那几条文案（鸿蒙资源表里没有对应项）。
///
/// 鸿蒙的设置页有推送、智感握姿、个性化；Flutter 侧没有这些能力，
/// 换成了「服务器 / 缓存 / 日历订阅」这些确实能用的项。
/// 只有这里列出的 key 走本表，其余仍从 `kanoStrings` 里取，四个语言逐条对齐。
class SettingsStrings {
  const SettingsStrings._();

  static String t(String key) {
    final row = _rows[key];
    if (row == null) return KanoText.ui(key);
    final index = KanoText.langIndex;
    final picked = index >= 0 && index < row.length ? row[index] : '';
    return picked.isEmpty ? row[0] : picked;
  }

  static String fmt(String key, String arg) => t(key).replaceFirst('%s', arg);
}

/// 每行按 简中 / 繁中 / 日 / 英 排列（与 `kanoStrings` 同一口径）。
const _rows = <String, List<String>>{
  'section_data': ['数据与网络', '資料與網路', 'データとネットワーク', 'Data & Network'],
  'server': ['服务器', '伺服器', 'サーバー', 'Server'],
  'server_auto': ['自动', '自動', '自動', 'Auto'],
  'server_primary': ['主站', '主站', 'メイン', 'Primary'],
  'server_fallback': ['备用站', '備用站', '予備', 'Fallback'],
  'server_custom': ['自定义', '自訂', 'カスタム', 'Custom'],
  'server_desc': [
    '主站连不上时自动切备用站；填了自定义地址就只用它',
    '主站連不上時自動切備用站；填了自訂位址就只用它',
    'メインに接続できないときは予備へ自動で切り替えます。カスタムを入れるとそれだけを使います',
    "Falls back automatically when the primary is unreachable; a custom URL is used exclusively",
  ],
  'server_custom_hint': [
    '例如 https://kano.example.com',
    '例如 https://kano.example.com',
    '例：https://kano.example.com',
    'e.g. https://kano.example.com',
  ],
  'server_active': ['当前 %s', '目前 %s', '現在 %s', 'Now %s'],
  'cache': ['缓存', '快取', 'キャッシュ', 'Cache'],
  'cache_count': ['%s 项', '%s 項', '%s 件', '%s items'],
  'cache_empty': ['没有缓存', '沒有快取', 'キャッシュなし', 'Empty'],
  'cache_clear': ['清空缓存', '清除快取', 'キャッシュを消去', 'Clear cache'],
  'cache_clear_desc': [
    '清空后下次打开会重新联网拉一次；离线时会暂时没有内容',
    '清除後下次開啟會重新連網抓一次；離線時會暫時沒有內容',
    '消去すると次回はネットワークから取り直します。オフライン時は一時的に何も表示されません',
    'Next launch refetches from the network; offline you will see nothing until then',
  ],
  'cache_cleared': ['缓存已清空', '快取已清除', 'キャッシュを消去しました', 'Cache cleared'],
  'calendar_sub': ['日历订阅', '日曆訂閱', 'カレンダー購読', 'Calendar subscription'],
  'calendar_sub_desc': [
    '把日程订阅到系统日历，活动变更自动跟着更新',
    '把日程訂閱到系統日曆，活動變更自動跟著更新',
    'システムカレンダーに登録すると、予定の変更も自動で反映されます',
    'Subscribe in your system calendar so schedule changes follow automatically',
  ],
  'action_open': ['打开', '開啟', '開く', 'Open'],
  'action_copy': ['复制', '複製', 'コピー', 'Copy'],
  'action_copied': ['已复制', '已複製', 'コピーしました', 'Copied'],
  'action_cancel': ['取消', '取消', 'キャンセル', 'Cancel'],
  'action_ok': ['确定', '確定', 'OK', 'OK'],
  'about_licenses': ['开源许可', '開源授權', 'オープンソースライセンス', 'Open-source licenses'],
  'about_backend': ['后端状态', '後端狀態', 'バックエンド状態', 'Backend status'],
  'about_backend_ok': ['正常', '正常', '正常', 'Operational'],
  'about_backend_fail': ['连不上', '連不上', '接続できません', 'Unreachable'],
  'about_sources': ['数据来源', '資料來源', 'データ提供', 'Data sources'],
  'about_sources_desc': [
    'X · bilibili · YouTube，由 kano-navi 汇总',
    'X · bilibili · YouTube，由 kano-navi 彙整',
    'X · bilibili · YouTube（kano-navi が集約）',
    'X · bilibili · YouTube, aggregated by kano-navi',
  ],
  'about_site': ['项目主页', '專案主頁', 'プロジェクトサイト', 'Project site'],
  'about_package': ['包名', '套件名稱', 'パッケージ名', 'Package'],
  'about_build': ['构建', '建置', 'ビルド', 'Build'],
};
