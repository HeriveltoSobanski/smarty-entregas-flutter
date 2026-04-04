import 'package:flutter/material.dart';

import '../../../data/session_store.dart';
import '../../../services/api_service.dart';

const Color _cor = Color(0xFFFFA726);

// =============================================================
// PÁGINA PRINCIPAL DA EMPRESA
// =============================================================
class PaginaEmpresa extends StatefulWidget {
  const PaginaEmpresa({super.key});

  @override
  State<PaginaEmpresa> createState() => _PaginaEmpresaState();
}

class _PaginaEmpresaState extends State<PaginaEmpresa> {
  int _aba = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _cor,
        elevation: 0,
        title: Text(
          SessionStore.nome ?? 'Minha Empresa',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () {
            SessionStore.clear();
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/login', (_) => false);
          },
        ),
      ),
      body: IndexedStack(
        index: _aba,
        children: const [
          _TabProdutos(),
          _TabPedidos(),
          _TabConta(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _aba,
        onTap: (i) => setState(() => _aba = i),
        selectedItemColor: _cor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.fastfood), label: 'Produtos'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long), label: 'Pedidos'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: 'Conta'),
        ],
      ),
    );
  }
}

// =============================================================
// TAB: PRODUTOS
// =============================================================
class _TabProdutos extends StatefulWidget {
  const _TabProdutos();

  @override
  State<_TabProdutos> createState() => _TabProdutosState();
}

class _TabProdutosState extends State<_TabProdutos> {
  List<Map<String, dynamic>> _produtos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final id = SessionStore.idEmpresa;
    if (id != null) {
      final lista = await ApiService.getProdutosByEmpresa(id);
      if (mounted) setState(() => _produtos = lista);
    }
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _toggleAtivo(Map<String, dynamic> p) async {
    final id = p['id_produto'] is int
        ? p['id_produto'] as int
        : int.tryParse(p['id_produto'].toString()) ?? 0;
    await ApiService.toggleProdutoAtivo(id);
    _carregar();
  }

  Future<void> _deletar(Map<String, dynamic> p) async {
    final id = p['id_produto'] is int
        ? p['id_produto'] as int
        : int.tryParse(p['id_produto'].toString()) ?? 0;
    await ApiService.deleteProduto(id);
    _carregar();
  }

  void _abrirForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FormAddProduto(onSalvo: _carregar),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator(color: _cor));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _produtos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fastfood, size: 70, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Nenhum produto cadastrado',
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey[500])),
                  const SizedBox(height: 6),
                  Text('Toque em + para adicionar',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[400])),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _carregar,
              color: _cor,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _produtos.length,
                itemBuilder: (_, i) => _CardProduto(
                  produto: _produtos[i],
                  onToggle: () => _toggleAtivo(_produtos[i]),
                  onDelete: () => _deletar(_produtos[i]),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _cor,
        onPressed: _abrirForm,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// Card de produto
class _CardProduto extends StatelessWidget {
  final Map<String, dynamic> produto;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _CardProduto(
      {required this.produto,
      required this.onToggle,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final ativo   = produto['ativo'] == true;
    final preco   = double.tryParse(produto['preco']?.toString() ?? '0') ?? 0;
    final cat     = produto['categoria_nome']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Ícone categoria
          ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16)),
            child: Container(
              width: 90,
              height: 90,
              color: _cor.withValues(alpha: 0.15),
              child: const Icon(Icons.fastfood, color: _cor, size: 36),
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        produto['nome']?.toString() ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (cat.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _cor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(cat,
                            style: const TextStyle(
                                fontSize: 11,
                                color: _cor,
                                fontWeight: FontWeight.bold)),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    produto['descricao']?.toString() ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'R\$ ${preco.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          // Ações
          Column(children: [
            Switch(
              value: ativo,
              onChanged: (_) => onToggle(),
              thumbColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? _cor
                    : Colors.grey,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ]),
        ],
      ),
    );
  }
}

// Formulário de adição de produto
class _FormAddProduto extends StatefulWidget {
  final VoidCallback onSalvo;
  const _FormAddProduto({required this.onSalvo});

  @override
  State<_FormAddProduto> createState() => _FormAddProdutoState();
}

class _FormAddProdutoState extends State<_FormAddProduto> {
  final _nomeCtrl      = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final _precoCtrl     = TextEditingController();
  final _imagemCtrl    = TextEditingController();

  List<Map<String, dynamic>> _categorias = [];
  Map<String, dynamic>?      _catSel;
  String? _erro;
  bool    _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarCats();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descricaoCtrl.dispose();
    _precoCtrl.dispose();
    _imagemCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarCats() async {
    final cats = await ApiService.getCategorias();
    if (mounted && cats.isNotEmpty) {
      setState(() {
        _categorias = cats;
        _catSel = cats.first;
      });
    }
  }

  Future<void> _salvar() async {
    final nome     = _nomeCtrl.text.trim();
    final descricao = _descricaoCtrl.text.trim();
    final preco    =
        double.tryParse(_precoCtrl.text.trim().replaceAll(',', '.')) ?? 0;

    if (nome.isEmpty || preco <= 0 || _catSel == null) {
      setState(() => _erro = 'Preencha nome, preço e categoria.');
      return;
    }

    final idEmpresa = SessionStore.idEmpresa;
    if (idEmpresa == null) {
      setState(() => _erro = 'Sessão expirada. Faça login novamente.');
      return;
    }

    final idCategoria = _catSel!['id_categoria'] is int
        ? _catSel!['id_categoria'] as int
        : int.tryParse(_catSel!['id_categoria'].toString()) ?? 0;

    setState(() => _salvando = true);

    final erro = await ApiService.createProduto(
      idEmpresa:   idEmpresa,
      idCategoria: idCategoria,
      nome:        nome,
      descricao:   descricao,
      preco:       preco,
    );

    if (!mounted) return;
    setState(() => _salvando = false);

    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }

    widget.onSalvo();
    Navigator.pop(context);
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Adicionar Produto',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            TextField(
                controller: _nomeCtrl, decoration: _deco('Nome do produto *')),
            const SizedBox(height: 12),

            TextField(
              controller: _precoCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _deco('Preço (R\$) *'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descricaoCtrl,
              maxLines: 2,
              decoration: _deco('Ingredientes / Descrição'),
            ),
            const SizedBox(height: 12),

            // Preview + campo de URL de imagem
            Row(
              children: [
                if (_imagemCtrl.text.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _imagemCtrl.text,
                      width: 60, height: 60, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                if (_imagemCtrl.text.isNotEmpty) const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _imagemCtrl,
                    decoration: _deco('URL da imagem (opcional)'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dropdown categorias do banco
            _categorias.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: _cor))
                : DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _catSel,
                    decoration: _deco('Categoria *'),
                    items: _categorias
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child:
                                  Text(c['nome']?.toString() ?? ''),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _catSel = v),
                  ),
            const SizedBox(height: 12),

            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_erro!,
                    style: const TextStyle(color: Colors.red)),
              ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _salvando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Salvar Produto',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// TAB: PEDIDOS
// =============================================================
class _TabPedidos extends StatefulWidget {
  const _TabPedidos();

  @override
  State<_TabPedidos> createState() => _TabPedidosState();
}

class _TabPedidosState extends State<_TabPedidos> {
  List<Map<String, dynamic>> _pedidos = [];
  bool      _carregando  = true;
  DateTime  _dataInicio  = DateTime.now().subtract(const Duration(days: 7));
  DateTime  _dataFim     = DateTime.now();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  String _fmtApi(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtBR(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final id = SessionStore.idEmpresa;
    if (id != null) {
      final lista = await ApiService.getPedidosByEmpresa(
        id,
        inicio: _fmtApi(_dataInicio),
        fim:    _fmtApi(_dataFim),
      );
      if (mounted) setState(() => _pedidos = lista);
    }
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _selecionarData(bool isInicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isInicio ? _dataInicio : _dataFim,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light()
            .copyWith(colorScheme: const ColorScheme.light(primary: _cor)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isInicio) {
          _dataInicio = picked;
        } else {
          _dataFim = picked;
        }
      });
      _carregar();
    }
  }

  void _gerarRelatorio() {
    final entregues  = _pedidos.where((p) => p['status'] == 'Entregue').length;
    final cancelados = _pedidos.where((p) => p['status'] == 'Cancelado').length;
    final outros     = _pedidos.length - entregues - cancelados;
    final total      = _pedidos
        .where((p) => p['status'] != 'Cancelado')
        .fold(0.0, (s, p) =>
            s + (double.tryParse(p['valor_total']?.toString() ?? '0') ?? 0));
    final taxa = total * 0.15;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Relatório de Pedidos',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_fmtBR(_dataInicio)} – ${_fmtBR(_dataFim)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const Divider(height: 20),
            _linha('Total de pedidos', '${_pedidos.length}'),
            _linha('Entregues', '$entregues', cor: Colors.green),
            _linha('Em andamento / outros', '$outros', cor: Colors.orange),
            _linha('Cancelados', '$cancelados', cor: Colors.red),
            const Divider(height: 20),
            _linha('Receita bruta',
                'R\$ ${total.toStringAsFixed(2)}', bold: true),
            _linha('Taxa Smarty (15%)',
                '- R\$ ${taxa.toStringAsFixed(2)}', cor: Colors.red),
            _linha('Valor líquido',
                'R\$ ${(total - taxa).toStringAsFixed(2)}',
                bold: true, cor: Colors.blue),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar', style: TextStyle(color: _cor)),
          ),
        ],
      ),
    );
  }

  Widget _linha(String label, String valor,
      {Color? cor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal)),
          Text(valor,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cor ??
                      (bold ? Colors.black87 : Colors.black54),
                  fontSize: bold ? 15 : 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _pedidos
        .where((p) => p['status'] != 'Cancelado')
        .fold(0.0, (s, p) =>
            s + (double.tryParse(p['valor_total']?.toString() ?? '0') ?? 0));

    return Column(
      children: [
        // Filtro de período
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtrar por período:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _botaoData('De: ${_fmtBR(_dataInicio)}',
                        () => _selecionarData(true))),
                const SizedBox(width: 8),
                Expanded(
                    child: _botaoData('Até: ${_fmtBR(_dataFim)}',
                        () => _selecionarData(false))),
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _resumo('${_pedidos.length}', 'Pedidos'),
                    Container(width: 1, height: 30, color: _cor),
                    _resumo('R\$ ${total.toStringAsFixed(2)}', 'Receita'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Lista
        Expanded(
          child: _carregando
              ? const Center(
                  child: CircularProgressIndicator(color: _cor))
              : _pedidos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long,
                              size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('Nenhum pedido no período',
                              style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _carregar,
                      color: _cor,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pedidos.length,
                        itemBuilder: (_, i) =>
                            _CardPedido(pedido: _pedidos[i]),
                      ),
                    ),
        ),

        // Botão relatório
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _gerarRelatorio,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.bar_chart, color: Colors.white),
              label: const Text('Gerar Relatório',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _botaoData(String texto, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: _cor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(texto, style: const TextStyle(fontSize: 13)),
            const Icon(Icons.calendar_today, size: 16, color: _cor),
          ],
        ),
      ),
    );
  }

  Widget _resumo(String valor, String label) {
    return Column(children: [
      Text(valor,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: _cor)),
      Text(label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    ]);
  }
}

class _CardPedido extends StatelessWidget {
  final Map<String, dynamic> pedido;
  const _CardPedido({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final status = pedido['status']?.toString() ?? '';
    final valor  = double.tryParse(
            pedido['valor_total']?.toString() ?? '0') ??
        0;

    Color statusCor;
    switch (status) {
      case 'Entregue':
        statusCor = Colors.green;
        break;
      case 'Cancelado':
        statusCor = Colors.red;
        break;
      default:
        statusCor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('#${pedido['id_pedido']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusCor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status,
                    style: TextStyle(
                        color: statusCor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(pedido['cliente']?.toString() ?? '',
              style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 4),
          if ((pedido['itens']?.toString() ?? '').isNotEmpty)
            Text(pedido['itens']?.toString() ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(pedido['criado_em']?.toString().substring(0, 16) ?? '',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[400])),
              Text('R\$ ${valor.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================
// TAB: CONTA
// =============================================================
class _TabConta extends StatefulWidget {
  const _TabConta();

  @override
  State<_TabConta> createState() => _TabContaState();
}

class _TabContaState extends State<_TabConta> {
  List<Map<String, dynamic>> _pedidos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final id = SessionStore.idEmpresa;
    if (id != null) {
      final lista = await ApiService.getPedidosByEmpresa(id);
      if (mounted) setState(() => _pedidos = lista);
    }
    if (mounted) setState(() => _carregando = false);
  }

  double _totalStatus(String status) => _pedidos
      .where((p) => p['status'] == status)
      .fold(0.0, (s, p) =>
          s + (double.tryParse(p['valor_total']?.toString() ?? '0') ?? 0));

  double get _totalGeral =>
      _totalStatus('Entregue') + _totalStatus('Em Preparo') +
      _totalStatus('A Caminho');

  double get _totalMes {
    final agora = DateTime.now();
    return _pedidos
        .where((p) {
          if (p['status'] == 'Cancelado') return false;
          try {
            final d = DateTime.parse(p['criado_em']?.toString() ?? '');
            return d.year == agora.year && d.month == agora.month;
          } catch (_) {
            return false;
          }
        })
        .fold(0.0, (s, p) =>
            s + (double.tryParse(p['valor_total']?.toString() ?? '0') ?? 0));
  }

  double get _totalSemana {
    final agora = DateTime.now();
    final inicioSemana = agora.subtract(Duration(days: agora.weekday - 1));
    return _pedidos
        .where((p) {
          if (p['status'] == 'Cancelado') return false;
          try {
            final d = DateTime.parse(p['criado_em']?.toString() ?? '');
            return d.isAfter(
                DateTime(inicioSemana.year, inicioSemana.month,
                    inicioSemana.day)
                    .subtract(const Duration(seconds: 1)));
          } catch (_) {
            return false;
          }
        })
        .fold(0.0, (s, p) =>
            s + (double.tryParse(p['valor_total']?.toString() ?? '0') ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator(color: _cor));
    }

    final taxa    = _totalMes * 0.15;
    final liquido = _totalMes - taxa;

    return RefreshIndicator(
      onRefresh: _carregar,
      color: _cor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card receita total
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFA726), Color(0xFFFFEB3B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: _cor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Receita Total (todos os pedidos)',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    'R\$ ${_totalGeral.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Row(children: [
              Expanded(
                  child: _MiniCard(
                      titulo: 'Esta semana',
                      valor: 'R\$ ${_totalSemana.toStringAsFixed(2)}',
                      icone: Icons.today,
                      cor: Colors.blue)),
              const SizedBox(width: 12),
              Expanded(
                  child: _MiniCard(
                      titulo: 'Este mês',
                      valor: 'R\$ ${_totalMes.toStringAsFixed(2)}',
                      icone: Icons.calendar_month,
                      cor: Colors.purple)),
            ]),
            const SizedBox(height: 20),

            const Text('Detalhamento do mês',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6)
                ],
              ),
              child: Column(children: [
                _LinhaDetalhe('Receita bruta',
                    'R\$ ${_totalMes.toStringAsFixed(2)}', Colors.green),
                const Divider(),
                _LinhaDetalhe('Taxa Smarty (15%)',
                    '- R\$ ${taxa.toStringAsFixed(2)}', Colors.red),
                const Divider(),
                _LinhaDetalhe('Valor líquido',
                    'R\$ ${liquido.toStringAsFixed(2)}', Colors.blue,
                    bold: true),
              ]),
            ),
            const SizedBox(height: 20),

            const Text('Últimas transações',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (_pedidos.isEmpty)
              Center(
                child: Text('Nenhum pedido registrado.',
                    style: TextStyle(color: Colors.grey[500])),
              )
            else
              ..._pedidos
                  .where((p) => p['status'] != 'Cancelado')
                  .take(8)
                  .map((p) => _LinhaTransacao(pedido: p)),
          ],
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String titulo, valor;
  final IconData icone;
  final Color cor;
  const _MiniCard(
      {required this.titulo,
      required this.valor,
      required this.icone,
      required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone, color: cor, size: 24),
        const SizedBox(height: 8),
        Text(valor,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: cor)),
        Text(titulo,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ]),
    );
  }
}

class _LinhaDetalhe extends StatelessWidget {
  final String label, valor;
  final Color cor;
  final bool bold;
  const _LinhaDetalhe(this.label, this.valor, this.cor, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 15 : 14)),
          Text(valor,
              style: TextStyle(
                  color: cor,
                  fontWeight: FontWeight.bold,
                  fontSize: bold ? 15 : 14)),
        ],
      ),
    );
  }
}

class _LinhaTransacao extends StatelessWidget {
  final Map<String, dynamic> pedido;
  const _LinhaTransacao({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final valor =
        double.tryParse(pedido['valor_total']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4)
        ],
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.arrow_downward,
              color: Colors.green, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pedido['cliente']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                pedido['itens']?.toString() ?? '',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[500]),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Text('+ R\$ ${valor.toStringAsFixed(2)}',
            style: const TextStyle(
                color: Colors.green, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
