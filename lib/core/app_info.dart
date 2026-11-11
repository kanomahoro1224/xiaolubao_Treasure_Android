/// 应用自身的静态信息。
///
/// 版本号与 `pubspec.yaml` 的 `version:` 保持一致（Flutter 侧没有 package_info_plus，
/// 多引一个插件只为了读一行字符串不划算）。改版本时两处一起改。
class AppInfo {
  const AppInfo._();

  static const name = '小鹿包们的宝物';
  static const packageId = 'kano.xiaolubao.com';
  static const version = '0.1.0';
  static const build = 1;

  /// 主页 / 数据来源
  static const homeUrl = 'https://xiaolubao.com';
  static const fallbackUrl = 'https://kano.yexca.net';

  /// 开源许可页读取的包名（只用于 `showLicensePage` 的标题）
  static const licenseLabel = '小鹿包们的宝物 · 开源许可';
}
