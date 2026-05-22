import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart';

class DbConnection {
  final DotEnv env;
  late Pool connection;

  DbConnection(this.env);

  Future<void> open() async {
    final host     = env['DB_HOST'] ?? '127.0.0.1';
    final port     = int.tryParse(env['DB_PORT'] ?? '5432') ?? 5432;
    final database = env['DB_NAME'] ?? 'postgres';
    final username = env['DB_USER'] ?? 'postgres';
    final password = env['DB_PASS'];

    if (password == null) {
      throw Exception("Variavel DB_PASS nao encontrada no .env");
    }

    final sslMode = env['DB_SSL'] == 'disable' ? SslMode.disable : SslMode.require;

    connection = Pool.withEndpoints(
      [
        Endpoint(
          host: host,
          port: port,
          database: database,
          username: username,
          password: password,
        ),
      ],
      settings: PoolSettings(
        maxConnectionCount: 10,
        sslMode: sslMode,
      ),
    );

    // Abre uma conexão de teste para validar credenciais na startup
    await connection.execute(Sql.named('SELECT 1'), parameters: {});
  }
}