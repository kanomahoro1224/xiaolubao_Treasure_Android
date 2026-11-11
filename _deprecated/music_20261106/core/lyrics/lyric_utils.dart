class LyricLine {
  const LyricLine({
    required this.timeMs,
    required this.text,
    this.translation,
    this.romaji,
  });

  final int timeMs;
  final String text;
  final String? translation;
  final String? romaji;
}

class LyricUtils {
  const LyricUtils._();

  static final _lineExp = RegExp(r'^\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,3}))?\](.*)$');

  static List<LyricLine> parseLrc(String source) {
    final lines = <LyricLine>[];
    for (final raw in source.split('\n')) {
      final match = _lineExp.firstMatch(raw.trim());
      if (match == null) continue;
      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
      final fraction = match.group(3) ?? '0';
      final millis = int.tryParse(fraction.padRight(3, '0').substring(0, 3)) ?? 0;
      lines.add(
        LyricLine(
          timeMs: minutes * 60000 + seconds * 1000 + millis,
          text: (match.group(4) ?? '').trim(),
        ),
      );
    }
    lines.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return lines;
  }

  static int activeIndex(List<LyricLine> lines, int positionMs) {
    if (lines.isEmpty) return -1;
    var index = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].timeMs <= positionMs) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }
}
