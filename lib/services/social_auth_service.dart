import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class SocialAuthService {
  static const _googleClientId =
      '1088560191949-p50cghn8dfefgfj0umakokvo87ioi7cj.apps.googleusercontent.com';

  // google_sign_in_web exige `clientId` e proíbe `serverClientId`;
  // no mobile é o inverso (o client web é usado só para validar no backend).
  static final _google = GoogleSignIn(
    clientId: kIsWeb ? _googleClientId : null,
    serverClientId: kIsWeb ? null : _googleClientId,
    scopes: ['email', 'profile'],
  );

  /// Abre o fluxo de autenticação do Google e retorna o ID token.
  /// Retorna null se o usuário cancelar.
  static Future<String?> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.idToken;
  }

  /// Abre o fluxo de autenticação do Facebook e retorna o access token.
  /// Retorna null se o usuário cancelar ou ocorrer erro.
  static Future<String?> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login(
      permissions: ['email', 'public_profile'],
    );
    if (result.status == LoginStatus.success) {
      return result.accessToken?.tokenString;
    }
    return null;
  }

  static Future<void> signOut() async {
    await _google.signOut();
    await FacebookAuth.instance.logOut();
  }
}
