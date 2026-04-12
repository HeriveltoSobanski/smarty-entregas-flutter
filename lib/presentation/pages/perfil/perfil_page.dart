import 'package:flutter/material.dart';
import '../../../data/session_store.dart';
import '../cliente_enderecos/cliente_enderecos_page.dart';

const Color _laranja = Color(0xFFF5841F);

class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    final nome  = SessionStore.nome  ?? 'Usuário';
    final email = SessionStore.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _laranja,
        elevation: 0,
        title: const Text('Meu Perfil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: _laranja,
                child: Text(
                  nome.isNotEmpty ? nome[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 14),
              Text(nome, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(email, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            ]),
          ),
          const SizedBox(height: 32),
          _item(Icons.person_outline, 'Nome', nome),
          _item(Icons.email_outlined, 'E-mail', email),
          _item(Icons.badge_outlined, 'Tipo de conta', 'Cliente'),
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0.5,
            child: ListTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClienteEnderecosPage()),
              ),
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _laranja.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_outlined,
                    color: _laranja, size: 20),
              ),
              title: const Text('Meus endereços',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              subtitle: const Text('Gerenciar endereços de entrega',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Sair da conta'),
                    content: const Text('Tem certeza que deseja sair?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar')),
                      ElevatedButton(
                        onPressed: () async {
                          await SessionStore.logout();
                          if (!context.mounted) return;
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Sair', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Sair da conta',
                  style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(IconData icone, String titulo, String valor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0.5,
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _laranja.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, color: _laranja, size: 20),
        ),
        title: Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(valor,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
      ),
    );
  }
}
