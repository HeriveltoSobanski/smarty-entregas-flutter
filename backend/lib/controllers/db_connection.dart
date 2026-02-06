import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart';

class DbConnection {
  final DotEnv env;
  late Connection connection;

  DbConnection(this.env);

  Future<void> open() async {
    final host = env['DB_HOST'] ?? '127.0.0.1';
    final port = int.tryParse(env['DB_PORT'] ?? '5432') ?? 5432;
    final database = env['DB_NAME'] ?? 'postgres';
    final username = env['DB_USER'] ?? 'postgres';
    final password = env['DB_PASS'];

    if (password == null) {
      throw Exception("Variavel DB_PASS nao encontrada no .env");
    }

    connection = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      ),
      settings: ConnectionSettings(
        sslMode: SslMode.disable, // Forca o desligamento do SSL para teste local
      ),
    );
  }
}