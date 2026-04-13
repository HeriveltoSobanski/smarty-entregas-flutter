import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';
import '../../../data/session_store.dart';

const Color _cor = Color(0xFFF5841F);

class EmpresaMotoboyPage extends StatefulWidget {
  const EmpresaMotoboyPage({super.key});

  @override
  State<EmpresaMotoboyPage> createState() => _EmpresaMotoboyPageState();
}

class _EmpresaMotoboyPageState extends State<EmpresaMotoboyPage> {
  List<Map<String, dynamic>> _motoboys = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final id = SessionStore.idEmpresa;
    if (id == null) { setState(() => _loading = false); return; }
    final lista = await ApiService.getMotoboysDaEmpresa(id);
    if (mounted) setState(() { _motoboys = lista; _loading = false; });
  }

  Future<void> _adicionar() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ModalAdicionarMotoboy(
        onSalvo: (idUsuario) async {
          final id = SessionStore.idEmpresa!;
          final erro = await ApiService.criarMotoboyEmpresa(
            idEmpresa: id,
            idUsuario: idUsuario,
          );
          if (erro != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(erro), backgroundColor: Colors.red),
            );
          }
          await _carregar();
        },
      ),
    );
  }

  Future<void> _deletar(int id, String nome) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remover motoboy'),
        content: Text('Remover "$nome" da sua equipe?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.deletarMotoboyEmpresa(id);
      await _carregar();
    }
  }

  Color _corStatus(String status) {
    switch (status) {
      case 'disponivel': return Colors.green;
      case 'em_rota':    return Colors.blue;
      default:           return Colors.grey;
    }
  }

  String _labelStatus(String status) {
    switch (status) {
      case 'disponivel': return 'Disponível';
      case 'em_rota':    return 'Em Rota';
      default:           return 'Offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _cor,
        foregroundColor: Colors.white,
        title: const Text('Minha Equipe',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _carregar),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _cor,
        foregroundColor: Colors.white,
        onPressed: _adicionar,
        icon: const Icon(Icons.person_add),
        label: const Text('Adicionar',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _cor))
          : _motoboys.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.delivery_dining,
                        size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('Nenhum motoboy na equipe',
                        style: TextStyle(
                            fontSize: 17, color: Colors.grey.shade500)),
                    const SizedBox(height: 8),
                    Text('Adicione usando o ID do motoboy',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade400)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: _motoboys.length,
                  itemBuilder: (_, i) {
                    final m      = _motoboys[i];
                    final id     = m['id'] as int;
                    final nome   = m['nome']?.toString() ?? '';
                    final tel    = m['telefone']?.toString() ?? '';
                    final status = m['status_motoboy']?.toString() ?? 'offline';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: _cor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delivery_dining,
                              color: _cor, size: 26),
                        ),
                        title: Text(nome,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (tel.isNotEmpty)
                              Text(tel,
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Row(children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _corStatus(status),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(_labelStatus(status),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _corStatus(status),
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _deletar(id, nome),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ── Modal adicionar motoboy ──────────────────────────────────────
class _ModalAdicionarMotoboy extends StatefulWidget {
  final Future<void> Function(int idUsuario) onSalvo;
  const _ModalAdicionarMotoboy({required this.onSalvo});

  @override
  State<_ModalAdicionarMotoboy> createState() => _ModalAdicionarMotoboyState();
}

class _ModalAdicionarMotoboyState extends State<_ModalAdicionarMotoboy> {
  final _idCtrl = TextEditingController();
  Map<String, dynamic>? _motoboyEncontrado;
  bool _buscando  = false;
  bool _salvando  = false;
  String? _erroBusca;

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final id = int.tryParse(_idCtrl.text.trim());
    if (id == null) {
      setState(() { _erroBusca = 'Digite um ID válido'; _motoboyEncontrado = null; });
      return;
    }
    setState(() { _buscando = true; _erroBusca = null; _motoboyEncontrado = null; });
    final resultado = await ApiService.buscarMotoboyPorId(id);
    if (!mounted) return;
    if (resultado == null) {
      setState(() { _buscando = false; _erroBusca = 'ID não encontrado. Verifique com o motoboy.'; });
    } else {
      setState(() { _buscando = false; _motoboyEncontrado = resultado; });
    }
  }

  Future<void> _salvar() async {
    if (_motoboyEncontrado == null) return;
    setState(() => _salvando = true);
    final idUsuario = _motoboyEncontrado!['id'] is int
        ? _motoboyEncontrado!['id'] as int
        : int.parse(_motoboyEncontrado!['id'].toString());
    await widget.onSalvo(idUsuario);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Text('Adicionar motoboy',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('O motoboy precisa ter cadastro no app.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 20),

        // Campo ID
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _idCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _deco('ID do motoboy', Icons.badge_outlined),
              onFieldSubmitted: (_) => _buscar(),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _buscando ? null : _buscar,
            child: _buscando
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Buscar'),
          ),
        ]),

        // Erro
        if (_erroBusca != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(_erroBusca!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          ]),
        ],

        // Motoboy encontrado
        if (_motoboyEncontrado != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _cor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delivery_dining, color: _cor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_motoboyEncontrado!['nome']?.toString() ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    if ((_motoboyEncontrado!['telefone']?.toString() ?? '').isNotEmpty)
                      Text(_motoboyEncontrado!['telefone'].toString(),
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, color: Colors.green, size: 22),
            ]),
          ),
        ],

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: (_salvando || _motoboyEncontrado == null) ? null : _salvar,
            child: _salvando
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white)))
                : const Text('Confirmar',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: _cor),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _cor, width: 2)),
      );
}
