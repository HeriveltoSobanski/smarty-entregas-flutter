import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/session_store.dart';
import '../../../services/api_service.dart';
import '../selecionar_endereco/selecionar_endereco_page.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarEndereco());
  }

  Future<void> _verificarEndereco() async {
    final id = SessionStore.idEmpresa;
    if (id == null) return;

    final data = await ApiService.getEnderecoEmpresa(id);
    final endereco = data?['endereco']?.toString() ?? '';

    // Atualiza sessão
    SessionStore.enderecoEmpresa = endereco.isEmpty ? null : endereco;
    SessionStore.latEmpresa  = data?['latitude']  is num ? (data!['latitude']  as num).toDouble() : null;
    SessionStore.lngEmpresa  = data?['longitude'] is num ? (data!['longitude'] as num).toDouble() : null;

    if (!mounted) return;
    if (endereco.isEmpty) {
      _mostrarModalEnderecoObrigatorio();
    }
  }

  void _mostrarModalEnderecoObrigatorio() {
    showDialog(
      context: context,
      barrierDismissible: false, // obrigatório — não pode fechar sem cadastrar
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.location_on, color: Color(0xFFFFA726)),
            const SizedBox(width: 8),
            const Expanded(child: Text('Endereço obrigatório',
                style: TextStyle(fontSize: 17))),
          ]),
          content: const Text(
            'Para que os motoboys consigam encontrar sua empresa, '
            'você precisa cadastrar o endereço antes de continuar.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA726),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx); // fecha o dialog
                final res = await Navigator.push<EnderecoSelecionado>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SelecionarEnderecoPage(),
                  ),
                );
                if (res != null) {
                  await _salvarEndereco(res);
                } else {
                  // Não cadastrou — mostra de novo
                  if (mounted) _mostrarModalEnderecoObrigatorio();
                }
              },
              icon: const Icon(Icons.map_outlined),
              label: const Text('Cadastrar agora',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvarEndereco(EnderecoSelecionado res) async {
    final id = SessionStore.idEmpresa;
    if (id == null) return;
    final erro = await ApiService.atualizarEnderecoEmpresa(
        id, res.endereco, res.lat, res.lng);
    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(erro), backgroundColor: Colors.red));
      _mostrarModalEnderecoObrigatorio();
    } else {
      SessionStore.enderecoEmpresa = res.endereco;
      SessionStore.latEmpresa  = res.lat;
      SessionStore.lngEmpresa  = res.lng;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Endereço salvo com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

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
          onPressed: () async {
            await SessionStore.logout();
            if (!context.mounted) return;
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
              icon: const Icon(Icons.add_circle_outline, color: _cor),
              tooltip: 'Adicionais',
              onPressed: () {
                final id = produto['id_produto'] is int
                    ? produto['id_produto'] as int
                    : int.tryParse(produto['id_produto'].toString()) ?? 0;
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24))),
                  builder: (_) => _AdicionaisSheet(idProduto: id),
                );
              },
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

  String? _imagemBase64;
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
    super.dispose();
  }

  Future<void> _selecionarImagem() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 75,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final b64 = base64Encode(bytes);
    setState(() => _imagemBase64 = 'data:image/jpeg;base64,$b64');
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
      imagem:      _imagemBase64,
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

            // Seletor de imagem da galeria
            GestureDetector(
              onTap: _selecionarImagem,
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _imagemBase64 != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          base64Decode(_imagemBase64!.split(',').last),
                          width: double.infinity,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: _cor, size: 28),
                          SizedBox(width: 8),
                          Text('Adicionar foto da galeria',
                              style: TextStyle(color: _cor, fontSize: 14)),
                        ],
                      ),
              ),
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
// SHEET: ADICIONAIS DO PRODUTO
// =============================================================
class _AdicionaisSheet extends StatefulWidget {
  final int idProduto;
  const _AdicionaisSheet({required this.idProduto});

  @override
  State<_AdicionaisSheet> createState() => _AdicionaisSheetState();
}

class _AdicionaisSheetState extends State<_AdicionaisSheet> {
  List<Map<String, dynamic>> _grupos = [];
  bool _loading = true;

  // Form
  final _nomeCtrl      = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _precoCtrl     = TextEditingController();
  final _grupoCtrl     = TextEditingController(text: 'Adicionais');
  final _maxCtrl       = TextEditingController(text: '3');
  bool _obrigatorio    = false;
  String? _erro;
  bool _salvando       = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose(); _descCtrl.dispose(); _precoCtrl.dispose();
    _grupoCtrl.dispose(); _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final grupos = await ApiService.getAdicionais(widget.idProduto);
    if (mounted) setState(() { _grupos = grupos; _loading = false; });
  }

  Future<void> _salvar() async {
    final nome  = _nomeCtrl.text.trim();
    final grupo = _grupoCtrl.text.trim();
    final preco = double.tryParse(_precoCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
    final maximo = int.tryParse(_maxCtrl.text.trim()) ?? 3;

    if (nome.isEmpty || grupo.isEmpty) {
      setState(() => _erro = 'Nome e grupo são obrigatórios.');
      return;
    }

    setState(() { _salvando = true; _erro = null; });

    final erro = await ApiService.createAdicional(
      idProduto:   widget.idProduto,
      grupo:       grupo,
      maximoGrupo: maximo,
      obrigatorio: _obrigatorio,
      nome:        nome,
      descricao:   _descCtrl.text.trim(),
      preco:       preco,
    );

    if (!mounted) return;
    setState(() => _salvando = false);

    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }

    _nomeCtrl.clear(); _descCtrl.clear(); _precoCtrl.clear();
    _carregar();
  }

  Future<void> _deletar(int idAdicional) async {
    await ApiService.deleteAdicional(idAdicional);
    _carregar();
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Gerenciar Adicionais',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Opções extras que o cliente pode escolher ao pedir',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 16),

            // ── Lista de grupos/adicionais existentes ────────────
            if (_loading)
              const Center(child: CircularProgressIndicator(color: _cor))
            else if (_grupos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Nenhum adicional cadastrado ainda.',
                    style: TextStyle(color: Colors.grey[500])),
              )
            else
              ..._grupos.map((g) {
                final itens = List<Map<String, dynamic>>.from(
                    g['itens'] as List? ?? []);
                final obrig = g['obrigatorio'] == true;
                final max   = g['maximo_grupo'];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _cor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text(g['grupo']?.toString() ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        if (obrig)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('OBRIGATÓRIO',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        const SizedBox(width: 6),
                        Text('máx $max',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600])),
                      ]),
                    ),
                    ...itens.map((item) {
                      final preco = item['preco'];
                      final precoVal = preco is num
                          ? preco.toDouble()
                          : double.tryParse(preco?.toString() ?? '') ?? 0.0;
                      final id = item['id_adicional'] is int
                          ? item['id_adicional'] as int
                          : int.tryParse(
                                  item['id_adicional']?.toString() ?? '') ??
                              0;
                      return ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        title: Text(item['nome']?.toString() ?? '',
                            style: const TextStyle(fontSize: 14)),
                        subtitle: (item['descricao']?.toString() ?? '')
                                .isNotEmpty
                            ? Text(item['descricao'].toString(),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500]))
                            : null,
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                            precoVal == 0
                                ? 'Grátis'
                                : '+ R\$ ${precoVal.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: precoVal == 0
                                    ? Colors.green
                                    : Colors.black87,
                                fontSize: 13),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 18, color: Colors.red),
                            onPressed: () => _deletar(id),
                          ),
                        ]),
                      );
                    }),
                    const Divider(),
                  ],
                );
              }),

            const SizedBox(height: 8),
            const Text('Adicionar novo item',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Formulário
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                    controller: _grupoCtrl,
                    decoration: _deco('Grupo (ex: Molhos)')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                    controller: _maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _deco('Máx')),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Checkbox(
                value: _obrigatorio,
                onChanged: (v) => setState(() => _obrigatorio = v ?? false),
                activeColor: _cor,
              ),
              const Text('Obrigatório'),
            ]),
            const SizedBox(height: 4),
            TextField(
                controller: _nomeCtrl,
                decoration: _deco('Nome do item *')),
            const SizedBox(height: 8),
            TextField(
                controller: _descCtrl,
                decoration: _deco('Descrição (opcional)')),
            const SizedBox(height: 8),
            TextField(
              controller: _precoCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _deco('Preço extra (0 = grátis)'),
            ),
            const SizedBox(height: 8),
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _salvando
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Salvar Adicional',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
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
  // filtro manual (usado só pelo relatório)
  DateTime  _dataInicio  = DateTime.now().subtract(const Duration(days: 30));
  DateTime  _dataFim     = DateTime.now();
  Timer?    _timer;

  @override
  void initState() {
    super.initState();
    _carregar();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _carregar(silencioso: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtBR(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _carregar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _carregando = true);
    final id = SessionStore.idEmpresa;
    if (id != null) {
      // Sem filtro de data na lista ao vivo — evita problema de fuso horário
      // onde pedidos feitos à noite ficam fora do range UTC
      final lista = await ApiService.getPedidosByEmpresa(id);
      if (mounted) {
        setState(() => _pedidos = lista);
      }
    }
    if (mounted && !silencioso) { setState(() => _carregando = false); }
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
                            _CardPedido(
                              pedido: _pedidos[i],
                              onStatusAtualizado: _carregar,
                            ),
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
  final VoidCallback? onStatusAtualizado;
  const _CardPedido({required this.pedido, this.onStatusAtualizado});

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

    final idPedido = pedido['id_pedido'] is int
        ? pedido['id_pedido'] as int
        : int.tryParse(pedido['id_pedido']?.toString() ?? '') ?? 0;

    return GestureDetector(
      onTap: () async {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => _PedidoDetalheSheet(
            idPedido: idPedido,
            onStatusAtualizado: onStatusAtualizado,
          ),
        );
      },
      child: Container(
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
              Text('#$idPedido',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Row(children: [
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
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ]),
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
    ),
    );
  }
}

// =============================================================
// PEDIDO — detalhe sheet (empresa)
// =============================================================
class _PedidoDetalheSheet extends StatefulWidget {
  final int idPedido;
  final VoidCallback? onStatusAtualizado;
  const _PedidoDetalheSheet(
      {required this.idPedido, this.onStatusAtualizado});

  @override
  State<_PedidoDetalheSheet> createState() => _PedidoDetalheSheetState();
}

class _PedidoDetalheSheetState extends State<_PedidoDetalheSheet> {
  Map<String, dynamic>? _pedido;
  bool _carregando  = true;
  bool _atualizando = false;
  int  _motoboyCount = 0;

  // status IDs: 1 Criado, 2 Em Preparo, 3 A Caminho, 4 Entregue, 5 Cancelado, 6 Aguardando Motoboy
  static const _statusNomes = {
    1: 'Criado',
    2: 'Em Preparo',
    3: 'A Caminho',
    4: 'Entregue',
    5: 'Cancelado',
    6: 'Aguardando Motoboy',
  };

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final results = await Future.wait([
      ApiService.getPedidoDetalhes(widget.idPedido),
      ApiService.getMotoboyCount(),
    ]);
    if (mounted) {
      final count = results[1] as Map<String, dynamic>;
      setState(() {
        _pedido        = results[0];
        _motoboyCount  = (count['disponiveis'] is int
            ? count['disponiveis'] as int
            : int.tryParse(count['disponiveis']?.toString() ?? '0') ?? 0);
        _carregando    = false;
      });
    }
  }

  Future<void> _atualizarStatus(int novoIdStatus) async {
    setState(() => _atualizando = true);
    await ApiService.atualizarStatusPedido(widget.idPedido, novoIdStatus);
    await _carregar();
    setState(() => _atualizando = false);
    widget.onStatusAtualizado?.call();
  }

  Future<void> _marcarQuasePronto() async {
    setState(() => _atualizando = true);
    await ApiService.marcarQuasePronto(widget.idPedido);
    await _carregar();
    setState(() => _atualizando = false);
    widget.onStatusAtualizado?.call();
  }

  Future<void> _chamarMotoboy() async {
    setState(() => _atualizando = true);
    await ApiService.chamarMotoboy(widget.idPedido);
    await _carregar();
    setState(() => _atualizando = false);
    widget.onStatusAtualizado?.call();
  }

  Future<void> _entregaPropria() async {
    setState(() => _atualizando = true);
    await ApiService.entregaPropria(widget.idPedido);
    await _carregar();
    setState(() => _atualizando = false);
    widget.onStatusAtualizado?.call();
  }

  Color _corStatus(String status) {
    switch (status) {
      case 'Entregue': return Colors.green;
      case 'Cancelado': return Colors.red;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) {
        if (_carregando) {
          return const Center(child: CircularProgressIndicator(color: _cor));
        }
        if (_pedido == null) {
          return const Center(child: Text('Não foi possível carregar o pedido.'));
        }

        final p = _pedido!;
        final idStatus = p['id_status'] is int
            ? p['id_status'] as int
            : int.tryParse(p['id_status']?.toString() ?? '') ?? 1;
        final status      = p['status']?.toString() ?? '';
        final valor       = double.tryParse(p['valor_total']?.toString() ?? '0') ?? 0;
        final itens       = List<Map<String, dynamic>>.from(p['itens'] ?? []);
        final quasePronto = p['quase_pronto'] as bool? ?? false;
        final tipoEntrega = p['tipo_entrega']?.toString() ?? '';

        return SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // cabeçalho
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pedido #${p['id_pedido']}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _corStatus(status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status,
                        style: TextStyle(
                            color: _corStatus(status),
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // cliente
              _secao('Cliente'),
              _infoLinha(Icons.person_outline,
                  p['cliente']?.toString() ?? ''),
              if ((p['cliente_email']?.toString() ?? '').isNotEmpty)
                _infoLinha(Icons.email_outlined,
                    p['cliente_email']?.toString() ?? ''),
              if ((p['cliente_telefone']?.toString() ?? '').isNotEmpty)
                _infoLinha(Icons.phone_outlined,
                    p['cliente_telefone']?.toString() ?? ''),
              const SizedBox(height: 16),

              // endereço
              if ((p['endereco_entrega']?.toString() ?? '').isNotEmpty) ...[
                _secao('Endereço de entrega'),
                _infoLinha(Icons.location_on_outlined,
                    p['endereco_entrega']?.toString() ?? ''),
                const SizedBox(height: 16),
              ],

              // observação
              if ((p['observacao']?.toString() ?? '').isNotEmpty) ...[
                _secao('Observação'),
                _infoLinha(Icons.notes,
                    p['observacao']?.toString() ?? ''),
                const SizedBox(height: 16),
              ],

              // itens
              _secao('Itens do pedido'),
              ...itens.map((item) {
                final qtd = item['quantidade'] is int
                    ? item['quantidade'] as int
                    : int.tryParse(item['quantidade']?.toString() ?? '') ?? 1;
                final preco = double.tryParse(
                        item['preco_unit']?.toString() ?? '0') ??
                    0;
                final sub = qtd * preco;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['produto']?.toString() ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                                'Qtd: $qtd  ×  R\$ ${preco.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600])),
                            if ((item['observacao']?.toString() ?? '').isNotEmpty)
                              Text(
                                  item['observacao']!.toString(),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange[700],
                                      fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      Text('R\$ ${sub.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('R\$ ${valor.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _cor)),
                ],
              ),
              const SizedBox(height: 24),

              // ── ações ──────────────────────────────────────────
              if (idStatus < 4 && idStatus != 5) ...[
                _secao('Ações'),
                const SizedBox(height: 8),
                if (_atualizando)
                  const Center(child: CircularProgressIndicator(color: _cor))
                else
                  Column(
                    children: [
                      // Botão "Quase Pronto" — só no status Em Preparo (2) e ainda não marcado
                      if (idStatus == 2 && !quasePronto)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _marcarQuasePronto,
                              icon: const Icon(Icons.notifications_active, size: 18),
                              label: const Text('Avisar cliente: Quase Pronto!',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),

                      // Badge "Quase pronto enviado"
                      if (quasePronto)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(children: [
                            const Icon(Icons.check_circle, color: Colors.deepOrange, size: 16),
                            const SizedBox(width: 6),
                            Text('Cliente avisado que está quase pronto',
                                style: TextStyle(fontSize: 12, color: Colors.deepOrange[700])),
                          ]),
                        ),

                      // Opções de entrega — só no status Em Preparo (2) sem tipo definido
                      if (idStatus == 2 && tipoEntrega.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secao('Como será a entrega?'),
                              const SizedBox(height: 6),
                              Row(children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: _entregaPropria,
                                    icon: const Icon(Icons.directions_car, size: 18),
                                    label: const Text('Entrega Própria',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _cor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: _chamarMotoboy,
                                    icon: const Icon(Icons.delivery_dining, size: 18),
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Motoboy',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        if (_motoboyCount > 0) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text('$_motoboyCount',
                                                style: const TextStyle(
                                                    color: _cor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ),

                      // Badge tipo de entrega definido
                      if (tipoEntrega.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(children: [
                            Icon(
                              tipoEntrega == 'propria'
                                  ? Icons.directions_car
                                  : Icons.delivery_dining,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tipoEntrega == 'propria'
                                  ? 'Entrega própria em andamento'
                                  : 'Aguardando motoboy',
                              style: const TextStyle(fontSize: 12, color: Colors.green),
                            ),
                          ]),
                        ),

                      // Avançar status / Cancelar
                      if (idStatus != 2 || tipoEntrega.isNotEmpty)
                        Row(children: [
                          if (idStatus < 4 && idStatus != 6)
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _cor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _atualizarStatus(idStatus + 1),
                                icon: const Icon(Icons.arrow_forward, size: 18),
                                label: Text(_statusNomes[idStatus + 1] ?? 'Avançar'),
                              ),
                            ),
                          if (idStatus < 4 && idStatus != 6)
                            const SizedBox(width: 10),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _atualizarStatus(5),
                            child: const Text('Cancelar'),
                          ),
                        ]),
                    ],
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _secao(String titulo) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(titulo,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey)),
      );

  Widget _infoLinha(IconData icon, String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Expanded(
                child: Text(texto,
                    style: const TextStyle(fontSize: 14))),
          ],
        ),
      );
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
  String? _fotoPerfil;
  bool _salvandoFoto = false;
  String? _endereco;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final id = SessionStore.idEmpresa;
    if (id != null) {
      final results = await Future.wait([
        ApiService.getPedidosByEmpresa(id),
        ApiService.getEnderecoEmpresa(id),
      ]);
      final lista = results[0] as List<Map<String, dynamic>>;
      final endData = results[1] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _pedidos  = lista;
          _endereco = endData?['endereco']?.toString();
          _lat      = endData?['latitude']  is num ? (endData!['latitude']  as num).toDouble() : null;
          _lng      = endData?['longitude'] is num ? (endData!['longitude'] as num).toDouble() : null;
        });
      }
    }
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _editarEndereco() async {
    final res = await Navigator.push<EnderecoSelecionado>(
      context,
      MaterialPageRoute(
        builder: (_) => SelecionarEnderecoPage(
          enderecoInicial: _endereco,
          latInicial:      _lat,
          lngInicial:      _lng,
        ),
      ),
    );
    if (res == null || !mounted) return;
    final id = SessionStore.idEmpresa;
    if (id == null) return;
    final erro = await ApiService.atualizarEnderecoEmpresa(
        id, res.endereco, res.lat, res.lng);
    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(erro), backgroundColor: Colors.red));
    } else {
      SessionStore.enderecoEmpresa = res.endereco;
      SessionStore.latEmpresa  = res.lat;
      SessionStore.lngEmpresa  = res.lng;
      setState(() { _endereco = res.endereco; _lat = res.lat; _lng = res.lng; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Endereço atualizado!'),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _selecionarFoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600, maxHeight: 600, imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    setState(() => _salvandoFoto = true);
    final idEmpresa = SessionStore.idEmpresa;
    if (idEmpresa != null) {
      await ApiService.atualizarFotoEmpresa(idEmpresa, b64);
      if (mounted) setState(() { _fotoPerfil = b64; _salvandoFoto = false; });
    } else {
      setState(() => _salvandoFoto = false);
    }
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
            // ── Foto de perfil da empresa ──────────────────────
            GestureDetector(
              onTap: _selecionarFoto,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6)
                  ],
                ),
                child: Row(children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: _cor.withValues(alpha: 0.15),
                        backgroundImage: _fotoPerfil != null &&
                                _fotoPerfil!.contains(',')
                            ? MemoryImage(
                                base64Decode(_fotoPerfil!.split(',').last))
                            : null,
                        child: _fotoPerfil == null
                            ? Text(
                                (SessionStore.nome ?? 'E')
                                    .isNotEmpty
                                    ? (SessionStore.nome ?? 'E')[0]
                                        .toUpperCase()
                                    : 'E',
                                style: const TextStyle(
                                    fontSize: 28,
                                    color: _cor,
                                    fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      if (_salvandoFoto)
                        const Positioned.fill(
                          child: CircleAvatar(
                            backgroundColor: Colors.black26,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _cor,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Foto de perfil',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text(
                          _fotoPerfil == null
                              ? 'Toque para adicionar uma foto. Ela aparecerá na tela inicial.'
                              : 'Foto definida. Toque para alterar.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),

            // ── Endereço da empresa ────────────────────────────
            GestureDetector(
              onTap: _editarEndereco,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (_endereco == null || _endereco!.isEmpty)
                        ? Colors.red.shade300
                        : Colors.green.shade300,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6)
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: (_endereco == null || _endereco!.isEmpty)
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: (_endereco == null || _endereco!.isEmpty)
                          ? Colors.red
                          : Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Text('Endereço da empresa',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 6),
                          if (_endereco == null || _endereco!.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Obrigatório',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ]),
                        const SizedBox(height: 2),
                        Text(
                          (_endereco != null && _endereco!.isNotEmpty)
                              ? _endereco!
                              : 'Toque para cadastrar o endereço.',
                          style: TextStyle(
                            fontSize: 12,
                            color: (_endereco == null || _endereco!.isEmpty)
                                ? Colors.red[700]
                                : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_outlined,
                      color: Colors.grey[400], size: 20),
                ]),
              ),
            ),

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
