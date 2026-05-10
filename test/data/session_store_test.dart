import 'package:flutter_test/flutter_test.dart';
import 'package:smarty_entregas/data/session_store.dart';

void main() {
  setUp(() => SessionStore.clear());
  tearDown(() => SessionStore.clear());

  group('SessionStore.set', () {
    test('preenche todos os campos', () {
      SessionStore.set(
        idUsuario: 42,
        email: 'user@test.com',
        nome: 'João',
        tipoUsuario: 'cliente',
        telefone: '41999999999',
        idEmpresa: null,
        token: 'token-abc',
      );
      expect(SessionStore.idUsuario,   42);
      expect(SessionStore.email,       'user@test.com');
      expect(SessionStore.nome,        'João');
      expect(SessionStore.tipoUsuario, 'cliente');
      expect(SessionStore.telefone,    '41999999999');
      expect(SessionStore.idEmpresa,   isNull);
      expect(SessionStore.token,       'token-abc');
    });

    test('define idEmpresa quando fornecido', () {
      SessionStore.set(
        idUsuario: 1, email: 'e@e.com', nome: 'X',
        tipoUsuario: 'empresa', idEmpresa: 7, token: 'tok',
      );
      expect(SessionStore.idEmpresa, 7);
    });
  });

  group('SessionStore.clear', () {
    test('zera todos os campos', () {
      SessionStore.set(
        idUsuario: 1, email: 'e@e.com', nome: 'X',
        tipoUsuario: 'cliente', token: 'tok',
      );
      SessionStore.clear();
      expect(SessionStore.idUsuario,   isNull);
      expect(SessionStore.email,       isNull);
      expect(SessionStore.nome,        isNull);
      expect(SessionStore.tipoUsuario, isNull);
      expect(SessionStore.token,       isNull);
      expect(SessionStore.idEmpresa,   isNull);
    });
  });

  group('SessionStore getters de tipo', () {
    test('isCliente retorna true para cliente', () {
      SessionStore.set(idUsuario: 1, email: '', nome: '', tipoUsuario: 'cliente', token: 't');
      expect(SessionStore.isCliente, true);
      expect(SessionStore.isEmpresa, false);
      expect(SessionStore.isMotoboy, false);
    });

    test('isEmpresa retorna true para empresa', () {
      SessionStore.set(idUsuario: 1, email: '', nome: '', tipoUsuario: 'empresa', token: 't');
      expect(SessionStore.isEmpresa, true);
      expect(SessionStore.isCliente, false);
      expect(SessionStore.isMotoboy, false);
    });

    test('isMotoboy retorna true para motoboy', () {
      SessionStore.set(idUsuario: 1, email: '', nome: '', tipoUsuario: 'motoboy', token: 't');
      expect(SessionStore.isMotoboy, true);
      expect(SessionStore.isCliente, false);
      expect(SessionStore.isEmpresa, false);
    });
  });

  group('SessionStore.isLoggedIn', () {
    test('false quando token null', () {
      expect(SessionStore.isLoggedIn, false);
    });

    test('true quando token definido', () {
      SessionStore.set(idUsuario: 1, email: '', nome: '', tipoUsuario: 'cliente', token: 'tok');
      expect(SessionStore.isLoggedIn, true);
    });

    test('false apos clear', () {
      SessionStore.set(idUsuario: 1, email: '', nome: '', tipoUsuario: 'cliente', token: 'tok');
      SessionStore.clear();
      expect(SessionStore.isLoggedIn, false);
    });
  });
}
