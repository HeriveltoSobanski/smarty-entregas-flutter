import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _cor = Color(0xFFF5841F);
const String _whatsapp = '5542999459596';
const String _email    = 'dyulliok2@gmail.com';

class SuportePage extends StatelessWidget {
  /// Quando passado, o botão de WhatsApp menciona o pedido automaticamente.
  final int? idPedido;

  const SuportePage({super.key, this.idPedido});

  Future<void> _abrirWhatsApp(BuildContext context) async {
    final texto = idPedido != null
        ? 'Olá! Preciso de ajuda com o pedido #$idPedido.'
        : 'Olá! Preciso de ajuda com o aplicativo Smarty Entregas.';
    final url = Uri.parse(
        'https://wa.me/$_whatsapp?text=${Uri.encodeComponent(texto)}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
        );
      }
    }
  }

  Future<void> _abrirEmail(BuildContext context) async {
    final assunto = idPedido != null
        ? 'Problema com pedido #$idPedido'
        : 'Suporte Smarty Entregas';
    final url = Uri(
      scheme: 'mailto',
      path: _email,
      queryParameters: {'subject': assunto},
    );
    if (!await launchUrl(url)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o e-mail.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _cor,
        foregroundColor: Colors.white,
        title: const Text('Ajuda e Suporte',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8)
              ],
            ),
            child: Column(children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: _cor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent,
                    color: _cor, size: 34),
              ),
              const SizedBox(height: 12),
              const Text('Como podemos ajudar?',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                idPedido != null
                    ? 'Suporte para o pedido #$idPedido'
                    : 'Estamos aqui para resolver seu problema.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Botões de contato
          _titulo('Falar com o suporte'),
          const SizedBox(height: 10),
          _botaoContato(
            icon: Icons.chat,
            label: 'WhatsApp',
            sublabel: 'Resposta rápida — recomendado',
            cor: const Color(0xFF25D366),
            onTap: () => _abrirWhatsApp(context),
          ),
          const SizedBox(height: 10),
          _botaoContato(
            icon: Icons.email_outlined,
            label: 'E-mail',
            sublabel: _email,
            cor: Colors.blueGrey,
            onTap: () => _abrirEmail(context),
          ),
          const SizedBox(height: 28),

          // FAQ
          _titulo('Perguntas frequentes'),
          const SizedBox(height: 10),
          ..._faqs.map((faq) => _ItemFaq(
                pergunta: faq['p']!,
                resposta: faq['r']!,
              )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _titulo(String texto) => Text(
        texto,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 0.5),
      );

  Widget _botaoContato({
    required IconData icon,
    required String   label,
    required String   sublabel,
    required Color    cor,
    required VoidCallback onTap,
  }) =>
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cor.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6)
              ],
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: cor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(sublabel,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.grey.shade400),
            ]),
          ),
        ),
      );
}

// ── Item de FAQ expansível ───────────────────────────────────────
class _ItemFaq extends StatefulWidget {
  final String pergunta;
  final String resposta;
  const _ItemFaq({required this.pergunta, required this.resposta});

  @override
  State<_ItemFaq> createState() => _ItemFaqState();
}

class _ItemFaqState extends State<_ItemFaq> {
  bool _aberto = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _aberto = !_aberto),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(children: [
                const Icon(Icons.help_outline, color: _cor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.pergunta,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Icon(
                  _aberto
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey,
                  size: 20,
                ),
              ]),
            ),
          ),
          if (_aberto)
            Padding(
              padding: const EdgeInsets.fromLTRB(44, 0, 16, 14),
              child: Text(
                widget.resposta,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

const _faqs = [
  {
    'p': 'Meu pedido não chegou. O que faço?',
    'r': 'Primeiro verifique o status na tela de acompanhamento. Se o status indicar "Entregue" mas você não recebeu, entre em contato com o suporte pelo WhatsApp informando o número do pedido.',
  },
  {
    'p': 'Posso cancelar meu pedido?',
    'r': 'É possível cancelar enquanto o pedido ainda está com status "Aguardando". Após o restaurante começar a preparar, o cancelamento depende da confirmação do restaurante. Entre em contato pelo WhatsApp.',
  },
  {
    'p': 'Fui cobrado mas o pedido não foi confirmado.',
    'r': 'Caso o pagamento tenha sido processado mas o pedido não apareça confirmado, entre em contato imediatamente pelo WhatsApp com o comprovante de pagamento. Resolveremos em até 24h.',
  },
  {
    'p': 'Como altero meu endereço de entrega?',
    'r': 'Acesse seu Perfil → Meus Endereços. Você pode adicionar, remover e definir um endereço como principal. O endereço principal é usado automaticamente no próximo pedido.',
  },
  {
    'p': 'O restaurante não está aceitando meu pedido.',
    'r': 'O restaurante pode estar com alto volume de pedidos ou fora do horário de funcionamento. Se o pedido ficar muito tempo em "Aguardando", ele será cancelado automaticamente e você não será cobrado.',
  },
  {
    'p': 'Como funciona o pagamento?',
    'r': 'Aceitamos Pix, dinheiro e cartão na entrega. O pagamento é feito diretamente ao entregador no momento da entrega. Pedidos com Pix devem ser confirmados antes do preparo.',
  },
];
