import 'package:flutter_test/flutter_test.dart';
import 'package:smarty_entregas/core/validators/cpf_validator.dart';

void main() {
  group('cpfValido — CPFs válidos', () {
    test('CPF real valido sem mascara', () {
      expect(cpfValido('52998224725'), true);
    });

    test('CPF real valido com mascara', () {
      expect(cpfValido('529.982.247-25'), true);
    });

    test('outro CPF valido', () {
      expect(cpfValido('111.444.777-35'), true);
    });
  });

  group('cpfValido — CPFs inválidos', () {
    test('todos digitos iguais — 00000000000', () {
      expect(cpfValido('000.000.000-00'), false);
    });

    test('todos digitos iguais — 11111111111', () {
      expect(cpfValido('111.111.111-11'), false);
    });

    test('todos digitos iguais — 99999999999', () {
      expect(cpfValido('999.999.999-99'), false);
    });

    test('digito verificador errado', () {
      expect(cpfValido('529.982.247-26'), false);
    });

    test('menos de 11 digitos', () {
      expect(cpfValido('123.456.789'), false);
    });

    test('mais de 11 digitos', () {
      expect(cpfValido('123.456.789-000'), false);
    });

    test('string vazia', () {
      expect(cpfValido(''), false);
    });

    test('apenas letras', () {
      expect(cpfValido('abcdefghijk'), false);
    });

    test('digitos verificadores trocados', () {
      expect(cpfValido('529.982.247-52'), false);
    });
  });
}
