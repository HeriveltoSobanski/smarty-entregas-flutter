import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

class CupomController {
  final Pool conn;

  CupomController(this.conn);

  // POST /cupons/validar
  // Body: { codigo, valor_pedido }
  Future<Response> validar(Request request) async {
    try {
      final bodyStr = await request.readAsString();
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(bodyStr) as Map<String, dynamic>;
      } catch (_) {
        return _json(400, {'error': 'Body JSON inválido'});
      }

      final codigo = body['codigo']?.toString().trim().toUpperCase();
      if (codigo == null || codigo.isEmpty) {
        return _json(400, {'error': 'codigo obrigatório'});
      }

      final valorPedido = _parseDouble(body['valor_pedido']) ?? 0.0;

      final result = await conn.execute(
        Sql.named('''
          SELECT id_cupom, tipo, valor, valor_minimo, usos_maximos, usos_atuais, ativo, valido_ate
          FROM cupons
          WHERE codigo = @codigo
        '''),
        parameters: {'codigo': codigo},
      );

      if (result.isEmpty) {
        return _json(404, {'error': 'Cupom não encontrado'});
      }

      final row = result.first;
      // id_cupom=row[0], tipo=row[1], valor=row[2], valor_minimo=row[3],
      // usos_maximos=row[4], usos_atuais=row[5], ativo=row[6], valido_ate=row[7]
      final idCupomFinal     = row[0] as int? ?? 0;
      final tipoFinal        = row[1]?.toString() ?? 'percentual';
      final valorFinal       = _rowDouble(row[2]) ?? 0.0;
      final valorMinimoFinal = _rowDouble(row[3]) ?? 0.0;
      final usosMaximosFinal = row[4] as int?;
      final usosAtuaisFinal  = row[5] as int? ?? 0;
      final ativoFinal       = row[6] as bool? ?? false;
      final validoAteFinal   = row[7];

      if (!ativoFinal) {
        return _json(422, {'error': 'Cupom inativo'});
      }

      if (validoAteFinal != null) {
        final expira = validoAteFinal is DateTime
            ? validoAteFinal
            : DateTime.tryParse(validoAteFinal.toString());
        if (expira != null && expira.isBefore(DateTime.now())) {
          return _json(422, {'error': 'Cupom expirado'});
        }
      }

      if (usosMaximosFinal != null && usosAtuaisFinal >= usosMaximosFinal) {
        return _json(422, {'error': 'Cupom esgotado'});
      }

      if (valorPedido < valorMinimoFinal) {
        return _json(422, {
          'error':
              'Pedido mínimo de R\$ ${valorMinimoFinal.toStringAsFixed(2)} para usar este cupom',
        });
      }

      final double desconto;
      if (tipoFinal == 'percentual') {
        desconto = valorPedido * (valorFinal / 100);
      } else {
        desconto = valorFinal > valorPedido ? valorPedido : valorFinal;
      }

      return _json(200, {
        'ok': true,
        'id_cupom':  idCupomFinal,
        'codigo':    codigo,
        'tipo':      tipoFinal,
        'valor':     valorFinal,
        'desconto':  double.parse(desconto.toStringAsFixed(2)),
      });
    } catch (e) {
      print('Erro 500: $e'); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // POST /cupons  (admin)
  // Body: { codigo, tipo, valor, valor_minimo?, usos_maximos?, valido_ate? }
  Future<Response> criar(Request request) async {
    try {
      if (request.context['tipoUsuario'] != 'admin') {
        return _json(403, {'error': 'Acesso negado'});
      }

      final bodyStr = await request.readAsString();
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(bodyStr) as Map<String, dynamic>;
      } catch (_) {
        return _json(400, {'error': 'Body JSON inválido'});
      }

      final codigo = body['codigo']?.toString().trim().toUpperCase();
      final tipo   = body['tipo']?.toString() ?? 'percentual';
      final valor  = _parseDouble(body['valor']);

      if (codigo == null || codigo.isEmpty) {
        return _json(400, {'error': 'codigo obrigatório'});
      }
      if (valor == null || valor <= 0) {
        return _json(400, {'error': 'valor deve ser maior que zero'});
      }
      if (!['percentual', 'fixo'].contains(tipo)) {
        return _json(400, {'error': 'tipo deve ser percentual ou fixo'});
      }
      if (tipo == 'percentual' && valor > 100) {
        return _json(400, {'error': 'Desconto percentual não pode ser maior que 100%'});
      }

      final valorMinimo  = _parseDouble(body['valor_minimo']) ?? 0.0;
      final usosMaximos  = _parseInt(body['usos_maximos']);
      final validoAteStr = body['valido_ate']?.toString();
      final validoAte    = validoAteStr != null ? DateTime.tryParse(validoAteStr) : null;

      await conn.execute(
        Sql.named('''
          INSERT INTO cupons (codigo, tipo, valor, valor_minimo, usos_maximos, valido_ate)
          VALUES (@codigo, @tipo, @valor, @valor_minimo, @usos_maximos, @valido_ate)
        '''),
        parameters: {
          'codigo':       codigo,
          'tipo':         tipo,
          'valor':        valor,
          'valor_minimo': valorMinimo,
          'usos_maximos': usosMaximos,
          'valido_ate':   validoAte,
        },
      );

      return _json(201, {'ok': true, 'codigo': codigo});
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('unique') || msg.contains('duplicate')) {
        return _json(409, {'error': 'Código de cupom já existe'});
      }
      print('Erro 500: $msg'); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // GET /cupons  (admin)
  Future<Response> listar(Request request) async {
    try {
      if (request.context['tipoUsuario'] != 'admin') {
        return _json(403, {'error': 'Acesso negado'});
      }

      final result = await conn.execute(
        Sql.named('''
          SELECT id_cupom, codigo, tipo, valor, valor_minimo, usos_maximos, usos_atuais, ativo, valido_ate, criado_em
          FROM cupons
          ORDER BY criado_em DESC
        '''),
        parameters: {},
      );

      final cupons = result.map((row) => {
        'id_cupom':     row[0],
        'codigo':       row[1]?.toString(),
        'tipo':         row[2]?.toString(),
        'valor':        _rowDouble(row[3]),
        'valor_minimo': _rowDouble(row[4]),
        'usos_maximos': row[5],
        'usos_atuais':  row[6],
        'ativo':        row[7],
        'valido_ate':   row[8]?.toString(),
        'criado_em':    row[9]?.toString(),
      }).toList();

      return _json(200, {'cupons': cupons});
    } catch (e) {
      print('Erro 500: $e'); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  // PATCH /cupons/:codigo/ativo  (admin)
  Future<Response> toggleAtivo(Request request, String codigo) async {
    try {
      if (request.context['tipoUsuario'] != 'admin') {
        return _json(403, {'error': 'Acesso negado'});
      }

      await conn.execute(
        Sql.named('''
          UPDATE cupons SET ativo = NOT ativo WHERE codigo = @codigo
        '''),
        parameters: {'codigo': codigo.toUpperCase()},
      );

      return _json(200, {'ok': true});
    } catch (e) {
      print('Erro 500: $e'); return _json(500, {'error': 'Erro interno do servidor'});
    }
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double? _rowDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Response _json(int status, Map<String, dynamic> body) => Response(
        status,
        body: jsonEncode(body),
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
}
