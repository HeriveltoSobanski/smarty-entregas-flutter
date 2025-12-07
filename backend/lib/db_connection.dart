// lib/db_connection.dart
import 'package:postgres/postgres.dart';

class DbConnection {
  late final Connection connection;

  Future<void> open() async {
    try {
      connection = await Connection.open(
        Endpoint(
          host: 'localhost',
          port: 5432,
          database: 'smartyentregas',
          username: 'postgres',
          password: '12345678',
        ),
        settings: const ConnectionSettings(
          sslMode: SslMode.disable,
        ),
      );

      print("🟢 Conexão com o banco de dados estabelecida!");
    } catch (e, st) {
      print("❌ Erro ao conectar ao banco: $e");
      print(st);
      rethrow; // se der pau, deixa subir pro main
    }
  }
}
