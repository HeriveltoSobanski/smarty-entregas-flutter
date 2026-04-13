import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

class EmailService {
  final String _user;
  final String _appPassword;

  EmailService(this._user, this._appPassword);

  Future<void> sendRecoveryCode(String toEmail, String code) async {
    final smtpServer = gmail(_user, _appPassword);

    final message = Message()
      ..from = Address(_user, 'Smarty Entregas')
      ..recipients.add(toEmail)
      ..subject = 'Código de recuperação de senha — Smarty Entregas'
      ..html = '''
        <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto">
          <h2 style="color:#F5841F">Smarty Entregas</h2>
          <p>Recebemos uma solicitação de redefinição de senha para a sua conta.</p>
          <p style="font-size:32px;font-weight:bold;letter-spacing:8px;color:#1A1A1A;text-align:center">
            $code
          </p>
          <p style="color:#757575;font-size:13px">
            Este código expira em <strong>15 minutos</strong>.<br>
            Se você não solicitou a redefinição, ignore este e-mail.
          </p>
        </div>
      ''';

    await send(message, smtpServer);
  }
}
