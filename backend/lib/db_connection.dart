import 'package:postgres/postgres.dart';

class DbConnection {
  static final DbConnection _instance = DbConnection._internal();
  factory DbConnection() => _instance;
  DbConnection._internal();

  Connection? _connection;

  Future<void> open() async {
    try {
      final endpoint = Endpoint(
        host: 'localhost',
        port: 5432,
        database: 'trabalho_smartyy',
        username: 'postgres',
        password: 'dyullio14721',
      );

      final settings = ConnectionSettings(
        sslMode: SslMode.disable,
        connectTimeout: const Duration(seconds: 5),
      );

      _connection = await Connection.open(endpoint, settings: settings);
      print('✅ Conexão com o banco de dados estabelecida!');
    } catch (e) {
      print('❌ Erro ao conectar com o banco de dados: $e');
    }
  }

  Connection? get connection => _connection;

  Future<void> close() async {
    if (_connection != null) {
      await _connection!.close();
      print('🔒 Conexão com o banco de dados fechada.');
    }
  }
}
