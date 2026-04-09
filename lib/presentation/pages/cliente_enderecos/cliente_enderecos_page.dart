import 'package:flutter/material.dart';

import '../../../data/session_store.dart';
import '../../../services/api_service.dart';
import '../selecionar_endereco/selecionar_endereco_page.dart';

const Color _cor = Color(0xFFF5841F);

// =============================================================
// ClienteEnderecosPage — gerencia endereços salvos do cliente
// Pode ser usada de dois modos:
//   - modoSelecao: false → gerenciar (adicionar/remover/principal)
//   - modoSelecao: true  → picker para o checkout (retorna Map)
// =============================================================
class ClienteEnderecosPage extends StatefulWidget {
  final bool modoSelecao;
  const ClienteEnderecosPage({super.key, this.modoSelecao = false});

  @override
  State<ClienteEnderecosPage> createState() => _ClienteEnderecosPageState();
}

class _ClienteEnderecosPageState extends State<ClienteEnderecosPage> {
  List<Map<String, dynamic>> _enderecos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final id = SessionStore.idUsuario;
    if (id != null) {
      _enderecos = await ApiService.getEnderecosCliente(id);
    }
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _adicionarEndereco() async {
    final res = await Navigator.push<EnderecoSelecionado>(
      context,
      MaterialPageRoute(
        builder: (_) => const SelecionarEnderecoPage(
          titulo: 'Novo Endereço',
        ),
      ),
    );
    if (res == null || !mounted) return;

    // Pede apelido
    final apelido = await _pedirApelido();
    if (!mounted) return;

    final id = SessionStore.idUsuario;
    if (id == null) return;

    final erro = await ApiService.criarEnderecoCliente(
      idUsuario:  id,
      endereco:   res.endereco,
      apelido:    apelido,
      latitude:   res.lat,
      longitude:  res.lng,
    );

    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(erro), backgroundColor: Colors.red));
    } else {
      await _carregar();
      // Se modo seleção, retorna imediatamente o novo endereço
      if (widget.modoSelecao) {
        final novo = _enderecos.firstWhere(
          (e) => e['endereco'] == res.endereco,
          orElse: () => _enderecos.isNotEmpty ? _enderecos.first : {},
        );
        if (novo.isNotEmpty && mounted) Navigator.pop(context, novo);
      }
    }
  }

  Future<String> _pedirApelido() async {
    final ctrl = TextEditingController();
    String apelido = 'Casa';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apelido do endereço',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Ex.: Casa, Trabalho, Academia',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 12),
            // Sugestões rápidas
            Wrap(
              spacing: 8,
              children: ['Casa', 'Trabalho', 'Academia', 'Outro'].map((s) =>
                ActionChip(
                  label: Text(s),
                  backgroundColor: _cor.withValues(alpha: 0.1),
                  labelStyle: const TextStyle(color: _cor),
                  onPressed: () {
                    ctrl.text = s;
                  },
                ),
              ).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'Digite um apelido',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _cor, width: 2),
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (v) => apelido = v.trim().isEmpty ? 'Casa' : v.trim(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  apelido = ctrl.text.trim().isEmpty ? 'Casa' : ctrl.text.trim();
                  Navigator.pop(ctx);
                },
                child: const Text('Confirmar',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );

    return apelido;
  }

  Future<void> _deletar(int idEndereco) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover endereço?'),
        content: const Text('Este endereço será removido da sua lista.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    await ApiService.deletarEnderecoCliente(idEndereco);
    _carregar();
  }

  Future<void> _marcarPrincipal(int idEndereco) async {
    await ApiService.marcarEnderecoClientePrincipal(idEndereco);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _cor,
        foregroundColor: Colors.white,
        title: Text(
          widget.modoSelecao ? 'Selecionar endereço' : 'Meus endereços',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: _cor))
          : _enderecos.isEmpty
              ? _buildVazio()
              : _buildLista(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adicionarEndereco,
        backgroundColor: _cor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Novo endereço',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildVazio() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Nenhum endereço cadastrado.',
                style: TextStyle(fontSize: 15, color: Colors.grey[500])),
            const SizedBox(height: 6),
            Text('Adicione um para continuar.',
                style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          ],
        ),
      );

  Widget _buildLista() => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _enderecos.length,
        itemBuilder: (_, i) {
          final e = _enderecos[i];
          final idEndereco = e['id_endereco'] is int
              ? e['id_endereco'] as int
              : int.tryParse(e['id_endereco']?.toString() ?? '') ?? 0;
          final isPrincipal = e['principal'] as bool? ?? false;
          final apelido  = e['apelido']?.toString() ?? 'Casa';
          final endereco = e['endereco']?.toString() ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: isPrincipal
                  ? Border.all(color: _cor, width: 2)
                  : null,
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 5,
                    offset: Offset(0, 2))
              ],
            ),
            child: widget.modoSelecao
                // ── Modo seleção: toque retorna o endereço ────────
                ? ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    leading: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: isPrincipal
                            ? _cor.withValues(alpha: 0.15)
                            : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconeApelido(apelido),
                        color: isPrincipal ? _cor : Colors.grey[500],
                        size: 22,
                      ),
                    ),
                    title: Row(children: [
                      Text(apelido,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPrincipal ? _cor : Colors.black87)),
                      if (isPrincipal) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: _cor,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text('Padrão',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ]),
                    subtitle: Text(endereco,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right, color: _cor),
                    onTap: () => Navigator.pop(context, e),
                  )
                // ── Modo gerenciar: swipe/botões ──────────────────
                : Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: isPrincipal
                                ? _cor.withValues(alpha: 0.15)
                                : Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _iconeApelido(apelido),
                            color: isPrincipal ? _cor : Colors.grey[500],
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(apelido,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isPrincipal
                                            ? _cor
                                            : Colors.black87)),
                                if (isPrincipal) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: _cor,
                                        borderRadius: BorderRadius.circular(8)),
                                    child: const Text('Padrão',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ]),
                              const SizedBox(height: 3),
                              Text(endereco,
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey[700]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                              Row(children: [
                                if (!isPrincipal)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _cor,
                                      side: const BorderSide(color: _cor),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _marcarPrincipal(idEndereco),
                                    icon: const Icon(Icons.star_border, size: 15),
                                    label: const Text('Padrão',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 22),
                                  onPressed: () => _deletar(idEndereco),
                                  tooltip: 'Remover',
                                  visualDensity: VisualDensity.compact,
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          );
        },
      );

  IconData _iconeApelido(String apelido) {
    final lower = apelido.toLowerCase();
    if (lower.contains('casa') || lower.contains('home')) return Icons.home_outlined;
    if (lower.contains('trabalho') || lower.contains('work')) return Icons.work_outline;
    if (lower.contains('acad') || lower.contains('gym')) return Icons.fitness_center;
    return Icons.location_on_outlined;
  }
}
