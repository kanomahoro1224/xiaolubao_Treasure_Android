class KafunoLogEntry {
  const KafunoLogEntry({
    required this.message,
    required this.level,
    required this.timestamp,
  });

  final String message;
  final String level;
  final DateTime timestamp;
}

class KafunoLogger {
  KafunoLogger._();

  static final List<KafunoLogEntry> _entries = [];

  static List<KafunoLogEntry> get entries => List.unmodifiable(_entries);

  static void info(String message) => _add('INFO', message);
  static void warn(String message) => _add('WARN', message);
  static void error(String message) => _add('ERROR', message);

  static void _add(String level, String message) {
    _entries.add(KafunoLogEntry(message: message, level: level, timestamp: DateTime.now()));
  }
}
