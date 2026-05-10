import 'package:flutter_test/flutter_test.dart';
import 'package:smarty_entregas/models/produto.dart';

void main() {
  group('Adicional.fromJson', () {
    test('campos completos', () {
      final json = {
        'id_adicional': 1,
        'grupo': 'Bebidas',
        'maximo_grupo': 2,
        'obrigatorio': true,
        'nome': 'Coca-Cola',
        'descricao': '350ml',
        'preco': 5.5,
        'ativo': true,
      };
      final a = Adicional.fromJson(json);
      expect(a.id, 1);
      expect(a.grupo, 'Bebidas');
      expect(a.maximoGrupo, 2);
      expect(a.obrigatorio, true);
      expect(a.nome, 'Coca-Cola');
      expect(a.preco, 5.5);
      expect(a.ativo, true);
    });

    test('campos ausentes usa defaults', () {
      final a = Adicional.fromJson({});
      expect(a.id, 0);
      expect(a.grupo, 'Adicionais');
      expect(a.maximoGrupo, 1);
      expect(a.obrigatorio, false);
      expect(a.nome, '');
      expect(a.preco, 0.0);
      expect(a.ativo, true);
    });

    test('preco como int converte para double', () {
      final a = Adicional.fromJson({'preco': 10});
      expect(a.preco, 10.0);
      expect(a.preco, isA<double>());
    });
  });

  group('Produto.fromJson', () {
    test('campos completos', () {
      final json = {
        'id_produto': 42,
        'id_empresa': 7,
        'id_categoria': 3,
        'nome': 'X-Burguer',
        'descricao': 'Delicioso',
        'preco': 29.90,
        'imagem': 'https://example.com/img.jpg',
        'ativo': true,
      };
      final p = Produto.fromJson(json);
      expect(p.id, 42);
      expect(p.idEmpresa, 7);
      expect(p.idCategoria, 3);
      expect(p.nome, 'X-Burguer');
      expect(p.preco, 29.90);
      expect(p.imagem, 'https://example.com/img.jpg');
      expect(p.ativo, true);
    });

    test('campos ausentes usa defaults', () {
      final p = Produto.fromJson({});
      expect(p.id, 0);
      expect(p.idEmpresa, 0);
      expect(p.nome, '');
      expect(p.preco, 0.0);
      expect(p.imagem, isNull);
      expect(p.ativo, true);
    });

    test('imagem null quando ausente', () {
      final p = Produto.fromJson({'id_produto': 1, 'nome': 'Teste'});
      expect(p.imagem, isNull);
    });
  });

  group('Produto.toJson', () {
    test('round-trip fromJson -> toJson', () {
      final json = {
        'id_produto': 5,
        'id_empresa': 2,
        'id_categoria': 1,
        'nome': 'Pizza',
        'descricao': 'Grande',
        'preco': 45.0,
        'ativo': true,
      };
      final p = Produto.fromJson(json);
      final out = p.toJson();
      expect(out['id_produto'], 5);
      expect(out['nome'], 'Pizza');
      expect(out['preco'], 45.0);
      expect(out.containsKey('imagem'), false);
    });

    test('toJson inclui imagem quando presente', () {
      final json = {
        'id_produto': 1,
        'id_empresa': 1,
        'id_categoria': 1,
        'nome': 'Lanche',
        'descricao': '',
        'preco': 10.0,
        'imagem': 'foto.jpg',
        'ativo': false,
      };
      final out = Produto.fromJson(json).toJson();
      expect(out['imagem'], 'foto.jpg');
      expect(out['ativo'], false);
    });
  });
}
