/// Logger estruturado e nivelado do backend.
///
/// Sink único: hoje escreve linhas estruturadas em stdout (capturado pelo
/// Railway). Centralizar o log aqui permite, no futuro, plugar Sentry ou
/// saída JSON sem tocar em nenhum call site.
///
/// Formato: `[<timestamp UTC ISO>] <NÍVEL> [<tag>] <mensagem>`
class Log {
  static void info(String tag, String message) => _emit('INFO', tag, message);
  static void warn(String tag, String message) => _emit('WARN', tag, message);

  /// Registra um erro. [error] costuma ser o objeto capturado no `catch`.
  /// O [stackTrace] é opcional e impresso logo abaixo quando fornecido.
  static void error(String tag, Object error, [StackTrace? stackTrace]) {
    _emit('ERROR', tag, error.toString());
    if (stackTrace != null) print(stackTrace);
  }

  static void _emit(String level, String tag, String message) {
    final ts = DateTime.now().toUtc().toIso8601String();
    print('[$ts] $level [$tag] $message');
  }
}
