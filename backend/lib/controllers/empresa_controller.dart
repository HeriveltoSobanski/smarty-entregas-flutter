import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import '../services/image_service.dart';

class EmpresaController {
  final Pool conn;
  final ImageService imageService;
  EmpresaController(this.conn, this.imageService);

  // ----------------------------------------------------------------
  // PATCH /empresas/:id/foto
  // Body: { foto_perfil?: "data:image/jpeg;base64,...", foto_capa?: "data:image/jpeg;base64,..." }
  // ----------------------------------------------------------------
  Future<Response> atualizarFoto(Request request, String id) async {
    try {
      final idEmpresa = int.tryParse(id);
      if (idEmpresa == null) return _json(400, {'error': 'id invalido'});
      final jwtEmpresa = int.tryParse(request.context['idEmpresa']?.toString() ?? '');
      if (jwtEmpresa != idEmpresa) return _json(403, {'error': 'Acesso negado'});

      final body = await request.readAsString();
      final data = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      final fotoPerfilRaw = data['foto_perfil']?.toString();
      final fotoCapaRaw   = data['foto_capa']?.toString();
      final temFotoPerfil = fotoPerfilRaw != null && fotoPerfilRaw.isNotEmpty;
      final temFotoCapa   = fotoCapaRaw   != null && fotoCapaRaw.isNotEmpty;

      if (!temFotoPerfil && !temFotoCapa) {
        return _json(400, {'error': 'foto_perfil ou foto_capa e obrigatorio'});
      }

      if (temFotoPerfil) {
        final erroFoto = imageService.validar(fotoPerfilRaw);
        if (erroFoto != null) return _json(400, {'error': 'foto_perfil: $erroFoto'});
      }
      if (temFotoCapa) {
        final erroCapa = imageService.validar(fotoCapaRaw);
        if (erroCapa != null) return _json(400, {'error': 'foto_capa: $erroCapa'});
      }

      final fotoPerfil = temFotoPerfil ? await imageService.processar(fotoPerfilRaw) : null;
      final fotoCapa   = temFotoCapa   ? await imageService.processar(fotoCapaRaw)   : null;

      final sets = <String>[];
      final params = <String, dynamic>{'id': idEmpresa};

      if (fotoPerfil != null) {
        sets.add('foto_perfil = @foto_perfil');
        params['foto_perfil'] = fotoPerfil;
      }
      if (fotoCapa != null) {
        sets.add('foto_capa = @foto_capa');
        params['foto_capa'] = fotoCapa;
      }
      if (sets.isEmpty) {
        return _json(400, {'error': 'Nenhuma imagem válida recebida'});
      }

      await conn.execute(
        Sql.named('''
          UPDATE empresas
          SET ${sets.join(', ')}
          WHERE id_empresa = @id
        '''),
        parameters: params,
      );

      return _json(200, {'ok': true});
    } catch (e) {
      print('Erro 500: $e'); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // ----------------------------------------------------------------
  // GET /empresas/:id/foto
  // ----------------------------------------------------------------
  Future<Response> getFoto(Request request, String id) async {
    try {
      final idEmpresa = int.tryParse(id);
      if (idEmpresa == null) return _json(400, {'error': 'id invalido'});

      final result = await conn.execute(
        Sql.named('SELECT foto_perfil, foto_capa FROM empresas WHERE id_empresa = @id'),
        parameters: {'id': idEmpresa},
      );

      if (result.isEmpty) return _json(404, {'error': 'Empresa nao encontrada'});

      return _json(200, {
        'foto_perfil': result.first[0]?.toString(),
        'foto_capa': result.first[1]?.toString(),
      });
    } catch (e) {
      print('Erro 500: $e'); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // ----------------------------------------------------------------
  // GET /empresas/:id/endereco
  // ----------------------------------------------------------------
  Future<Response> getEndereco(Request request, String id) async {
    try {
      final idEmpresa = int.tryParse(id);
      if (idEmpresa == null) return _json(400, {'error': 'id invalido'});

      final result = await conn.execute(
        Sql.named(
            'SELECT endereco, latitude, longitude FROM empresas WHERE id_empresa = @id'),
        parameters: {'id': idEmpresa},
      );

      if (result.isEmpty) return _json(404, {'error': 'Empresa nao encontrada'});
      final r = result.first;

      return _json(200, {
        'endereco': r[0]?.toString(),
        'latitude': r[1],
        'longitude': r[2],
      });
    } catch (e) {
      print('Erro 500: $e'); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // ----------------------------------------------------------------
  // PATCH /empresas/:id/endereco
  // Body: { endereco, latitude, longitude }
  // ----------------------------------------------------------------
  Future<Response> atualizarEndereco(Request request, String id) async {
    try {
      final idEmpresa = int.tryParse(id);
      if (idEmpresa == null) return _json(400, {'error': 'id invalido'});
      final jwtEmpresa = int.tryParse(request.context['idEmpresa']?.toString() ?? '');
      if (jwtEmpresa != idEmpresa) return _json(403, {'error': 'Acesso negado'});

      final body = await request.readAsString();
      final data = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      final endereco = data['endereco']?.toString();
      final latitude = data['latitude'] is num ? (data['latitude'] as num).toDouble() : null;
      final longitude = data['longitude'] is num ? (data['longitude'] as num).toDouble() : null;

      if (endereco == null || endereco.isEmpty) {
        return _json(400, {'error': 'endereco e obrigatorio'});
      }

      await conn.execute(
        Sql.named('''
          UPDATE empresas
          SET endereco = @endereco, latitude = @lat, longitude = @lng
          WHERE id_empresa = @id
        '''),
        parameters: {
          'endereco': endereco,
          'lat': latitude,
          'lng': longitude,
          'id': idEmpresa,
        },
      );

      return _json(200, {'ok': true});
    } catch (e) {
      print('Erro 500: $e'); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // ----------------------------------------------------------------
  // GET /empresas/:id/configuracoes
  // Retorna taxa_minima e tempo_preparo
  // ----------------------------------------------------------------
  Future<Response> getConfiguracoes(Request request, String id) async {
    try {
      final idEmpresa = int.tryParse(id);
      if (idEmpresa == null) return _json(400, {'error': 'id invalido'});

      final result = await conn.execute(
        Sql.named(
            'SELECT taxa_minima, tempo_preparo FROM empresas WHERE id_empresa = @id'),
        parameters: {'id': idEmpresa},
      );

      if (result.isEmpty) return _json(404, {'error': 'Empresa nao encontrada'});
      final r = result.first;

      return _json(200, {
        'taxa_minima': r[0] is num ? (r[0] as num).toDouble() : double.tryParse(r[0]?.toString() ?? '7') ?? 7.0,
        'tempo_preparo': r[1] is int ? r[1] as int : int.tryParse(r[1]?.toString() ?? '30') ?? 30,
      });
    } catch (e) {
      print('Erro 500: $e'); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // ----------------------------------------------------------------
  // PATCH /empresas/:id/configuracoes
  // Body: { taxa_minima?, tempo_preparo? }
  // ----------------------------------------------------------------
  Future<Response> atualizarConfiguracoes(Request request, String id) async {
    try {
      final idEmpresa = int.tryParse(id);
      if (idEmpresa == null) return _json(400, {'error': 'id invalido'});
      final jwtEmpresa = int.tryParse(request.context['idEmpresa']?.toString() ?? '');
      if (jwtEmpresa != idEmpresa) return _json(403, {'error': 'Acesso negado'});

      final body = await request.readAsString();
      final data = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      final taxaMinima = data['taxa_minima'] is num
          ? (data['taxa_minima'] as num).toDouble()
          : double.tryParse(data['taxa_minima']?.toString() ?? '');
      final tempoPreparo = data['tempo_preparo'] is int
          ? data['tempo_preparo'] as int
          : int.tryParse(data['tempo_preparo']?.toString() ?? '');

      if (taxaMinima == null && tempoPreparo == null) {
        return _json(400, {'error': 'Informe taxa_minima ou tempo_preparo'});
      }
      if (taxaMinima != null && taxaMinima < 0) {
        return _json(400, {'error': 'taxa_minima nao pode ser negativa'});
      }
      if (tempoPreparo != null && tempoPreparo < 1) {
        return _json(400, {'error': 'tempo_preparo deve ser pelo menos 1 minuto'});
      }

      final sets = <String>[];
      final params = <String, dynamic>{'id': idEmpresa};
      if (taxaMinima != null) {
        sets.add('taxa_minima   = @taxa');
        params['taxa'] = taxaMinima;
      }
      if (tempoPreparo != null) {
        sets.add('tempo_preparo = @tempo');
        params['tempo'] = tempoPreparo;
      }

      await conn.execute(
        Sql.named('UPDATE empresas SET ${sets.join(', ')} WHERE id_empresa = @id'),
        parameters: params,
      );

      return _json(200, {'ok': true});
    } catch (e) {
      print('Erro 500: $e'); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // ----------------------------------------------------------------
  // GET /empresas/:id/pix
  // ----------------------------------------------------------------
  Future<Response> getChavePix(Request request, String id) async {
    try {
      final idEmpresa = int.tryParse(id);
      if (idEmpresa == null) return _json(400, {'error': 'id invalido'});
      final jwtEmpresa = int.tryParse(request.context['idEmpresa']?.toString() ?? '');
      if (jwtEmpresa != idEmpresa) return _json(403, {'error': 'Acesso negado'});

      final result = await conn.execute(
        Sql.named('SELECT chave_pix, cidade FROM empresas WHERE id_empresa = @id'),
        parameters: {'id': idEmpresa},
      );
      if (result.isEmpty) return _json(404, {'error': 'Empresa nao encontrada'});

      return _json(200, {
        'chave_pix': result.first[0]?.toString() ?? '',
        'cidade':    result.first[1]?.toString() ?? '',
      });
    } catch (e) {
      print('Erro 500: $e'); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // ----------------------------------------------------------------
  // PATCH /empresas/:id/pix
  // Body: { chave_pix, cidade? }
  // ----------------------------------------------------------------
  Future<Response> atualizarChavePix(Request request, String id) async {
    try {
      final idEmpresa = int.tryParse(id);
      if (idEmpresa == null) return _json(400, {'error': 'id invalido'});
      final jwtEmpresa = int.tryParse(request.context['idEmpresa']?.toString() ?? '');
      if (jwtEmpresa != idEmpresa) return _json(403, {'error': 'Acesso negado'});

      final data = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final chavePix = data['chave_pix']?.toString().trim() ?? '';
      final cidade   = data['cidade']?.toString().trim() ?? '';

      if (chavePix.isEmpty) return _json(400, {'error': 'chave_pix obrigatoria'});

      await conn.execute(
        Sql.named('UPDATE empresas SET chave_pix = @chave, cidade = @cidade WHERE id_empresa = @id'),
        parameters: {'chave': chavePix, 'cidade': cidade, 'id': idEmpresa},
      );
      return _json(200, {'ok': true});
    } catch (e) {
      print('Erro 500: $e'); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  Response _json(int status, Map<String, dynamic> body) => Response(
        status,
        body: jsonEncode(body),
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
}
