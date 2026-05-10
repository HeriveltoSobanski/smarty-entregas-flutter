import 'dart:async';
import 'dart:convert';
import '../../../core/utils/image_cache.dart';
import '../../../core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/session_store.dart';
import '../../../services/api_service.dart';
import '../selecionar_endereco/selecionar_endereco_page.dart';
import '../empresa_motoboys/empresa_motoboys_page.dart';

// �� Design tokens �������������������������������������������������
const Color _cor      = Color(0xFFFFA726);
const Color _corDeep  = Color(0xFFF57C00);
const Color _bgPage   = Color(0xFFF1F3F8);
const Color _darkText = Color(0xFF1C1C1E);
const Color _muted    = Color(0xFF8E8E93);
const Color _card     = Colors.white;

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
    SessionStore.enderecoEmpresa = endereco.isEmpty ? null : endereco;
    SessionStore.latEmpresa  = data?['latitude']  is num ? (data!['latitude']  as num).toDouble() : null;
    SessionStore.lngEmpresa  = data?['longitude'] is num ? (data!['longitude'] as num).toDouble() : null;
    if (!mounted) return;
    if (endereco.isEmpty) _mostrarModalEnderecoObrigatorio();
  }

  void _mostrarModalEnderecoObrigatorio() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.location_on, color: _cor),
            SizedBox(width: 8),
            Expanded(child: Text('Endereço obrigatório', style: TextStyle(fontSize: 17))),
          ]),
          content: const Text(
            'Para que os motoboys consigam encontrar sua empresa, '
            'você precisa cadastrar o endereço antes de continuar.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _cor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await Navigator.push<EnderecoSelecionado>(
                  context,
                  MaterialPageRoute(builder: (_) => const SelecionarEnderecoPage()),
                );
                if (res != null) {
                  await _salvarEndereco(res);
                } else {
                  if (mounted) _mostrarModalEnderecoObrigatorio();
                }
              },
              icon: const Icon(Icons.map_outlined),
              label: const Text('Cadastrar agora', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvarEndereco(EnderecoSelecionado res) async {
    final id = SessionStore.idEmpresa;
    if (id == null) return;
    final erro = await ApiService.atualizarEnderecoEmpresa(id, res.endereco, res.lat, res.lng);
    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro), backgroundColor: Colors.red));
      _mostrarModalEnderecoObrigatorio();
    } else {
      SessionStore.enderecoEmpresa = res.endereco;
      SessionStore.latEmpresa = res.lat;
      SessionStore.lngEmpresa = res.lng;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Endereço salvo com sucesso!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nome = SessionStore.nome ?? 'Minha Empresa';
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : 'E';

    return Scaffold(
      backgroundColor: _bgPage,
      appBar: AppBar(
        toolbarHeight: 62,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_cor, _corDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.logout, color: Colors.white, size: 18),
              tooltip: 'Sair',
              onPressed: () async {
                await SessionStore.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              },
            ),
          ),
        ),
        title: Column(
          children: [
            Text(
              nome,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              'Painel operacional',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  inicial,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _aba,
        children: const [_TabProdutos(), _TabPedidos(), _TabFinanceiro(), _TabConta()],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: _card,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: _aba,
          onTap: (i) => setState(() => _aba = i),
          selectedItemColor: _cor,
          unselectedItemColor: Colors.grey.shade400,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu_outlined),
              activeIcon: Icon(Icons.restaurant_menu),
              label: 'Cardápio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Pedidos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Financeiro',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.manage_accounts_outlined),
              activeIcon: Icon(Icons.manage_accounts),
              label: 'Conta',
            ),
          ],
        ),
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

  Future<void> _confirmarDeletar(Map<String, dynamic> p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remover produto?'),
        content: Text('Tem certeza que deseja remover "${p['nome']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final id = p['id_produto'] is int
        ? p['id_produto'] as int
        : int.tryParse(p['id_produto'].toString()) ?? 0;
    await ApiService.deleteProduto(id);
    _carregar();
  }

  void _abrirForm([Map<String, dynamic>? produto]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FormProduto(onSalvo: _carregar, produto: produto),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // �� Header �������������������������������������������
        Container(
          color: _card,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Row(
            children: [
              Text('Cardápio',
                  style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.bold, color: _darkText)),
              const SizedBox(width: 8),
              if (_produtos.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: _cor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_produtos.length}',
                      style: GoogleFonts.poppins(
                          color: _corDeep, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: _abrirForm,
                style: TextButton.styleFrom(
                  backgroundColor: _cor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text('Adicionar',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ),

        // �� Lista ��������������������������������������������
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator(color: _cor))
              : _produtos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: _cor.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.restaurant_menu, size: 40, color: _cor),
                          ),
                          const SizedBox(height: 16),
                          Text('Nenhum produto no cardápio',
                              style: GoogleFonts.poppins(
                                  fontSize: 15, fontWeight: FontWeight.w600, color: _darkText)),
                          const SizedBox(height: 4),
                          Text('Adicione seu primeiro item para começar.',
                              style: GoogleFonts.poppins(fontSize: 13, color: _muted)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _carregar,
                      color: _cor,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _produtos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _CardProduto(
                          produto: _produtos[i],
                          onToggle: () => _toggleAtivo(_produtos[i]),
                          onDelete: () => _confirmarDeletar(_produtos[i]),
                          onEdit:   () => _abrirForm(_produtos[i]),
                          onAdicionais: () {
                            final id = _produtos[i]['id_produto'] is int
                                ? _produtos[i]['id_produto'] as int
                                : int.tryParse(_produtos[i]['id_produto'].toString()) ?? 0;
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                              builder: (_) => _AdicionaisSheet(idProduto: id),
                            );
                          },
                          onPizza: (_produtos[i]['is_pizza'] as bool? ?? false) ? () {
                            final id = _produtos[i]['id_produto'] is int
                                ? _produtos[i]['id_produto'] as int
                                : int.tryParse(_produtos[i]['id_produto'].toString()) ?? 0;
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                              builder: (_) => _PizzaSaboresSheet(idProduto: id),
                            );
                          } : null,
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

// �� Card de produto ��������������������������������������������
class _CardProduto extends StatelessWidget {
  final Map<String, dynamic> produto;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onAdicionais;
  final VoidCallback? onPizza;

  const _CardProduto({
    required this.produto,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onAdicionais,
    this.onPizza,
  });

  @override
  Widget build(BuildContext context) {
    final ativo = produto['ativo'] == true;
    final nome  = produto['nome']?.toString() ?? '';
    final desc  = produto['descricao']?.toString() ?? '';
    final preco = double.tryParse(produto['preco']?.toString() ?? '0') ?? 0;
    final cat   = produto['categoria_nome']?.toString() ?? '';
    final img   = produto['imagem']?.toString() ?? '';
    final temImg = img.isNotEmpty && img.contains(',');

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ativo ? _cor.withValues(alpha: 0.18) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // �� Imagem ����������������������������������������
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: temImg
                ? Image.memory(
                    Base64Cache.decode(img),
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                    color: ativo ? null : Colors.white.withValues(alpha: 0.5),
                    colorBlendMode: ativo ? null : BlendMode.lighten,
                  )
                : Container(
                    width: double.infinity,
                    height: 100,
                    color: ativo
                        ? _cor.withValues(alpha: 0.07)
                        : Colors.grey.shade100,
                    child: Icon(
                      Icons.restaurant_menu_outlined,
                      size: 48,
                      color: ativo ? _cor.withValues(alpha: 0.4) : Colors.grey.shade300,
                    ),
                  ),
          ),

          // �� Corpo �����������������������������������������
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nome + badge categoria
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        nome,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: ativo ? _darkText : _muted,
                        ),
                      ),
                    ),
                    if (cat.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _cor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(cat,
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: _corDeep, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),

                // Descrição
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: GoogleFonts.poppins(fontSize: 12, color: _muted, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),

                // Preço + status
                Row(
                  children: [
                    Text(
                      'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: GoogleFonts.poppins(
                        color: ativo ? const Color(0xFF2E7D32) : _muted,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (!ativo)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('INATIVO',
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5)),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // �� Barra de ações ��������������������������������
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: Row(
              children: [
                // Toggle ativo/inativo
                Expanded(
                  child: _ActionBtn(
                    icon: ativo ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    label: ativo ? 'Ativo' : 'Inativo',
                    color: ativo ? _cor : Colors.grey.shade400,
                    onTap: onToggle,
                  ),
                ),
                _divider(),
                // Editar
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.edit_outlined,
                    label: 'Editar',
                    color: _cor,
                    onTap: onEdit,
                  ),
                ),
                _divider(),
                // Adicionais
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.tune_outlined,
                    label: 'Extras',
                    color: _cor,
                    onTap: onAdicionais,
                  ),
                ),
                _divider(),
                // Sabores pizza
                if (produto['is_pizza'] as bool? ?? false) ...[
                  Expanded(
                    child: _ActionBtn(
                      icon: Icons.local_pizza_outlined,
                      label: 'Sabores',
                      color: _corDeep,
                      onTap: onPizza ?? () {},
                    ),
                  ),
                  _divider(),
                ],
                // Deletar
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.delete_outline,
                    label: 'Remover',
                    color: Colors.red.shade400,
                    onTap: onDelete,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 32, color: Colors.grey.shade100);
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 3),
            Text(label,
                style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// �� Formulário de adição / edição de produto ������������������
class _FormProduto extends StatefulWidget {
  final VoidCallback onSalvo;
  final Map<String, dynamic>? produto;
  const _FormProduto({required this.onSalvo, this.produto});

  @override
  State<_FormProduto> createState() => _FormProdutoState();
}

class _FormProdutoState extends State<_FormProduto> {
  final _nomeCtrl      = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final _precoCtrl     = TextEditingController();

  String? _imagemBase64;
  List<Map<String, dynamic>> _categorias = [];
  Map<String, dynamic>?      _catSel;
  String? _erro;
  bool    _salvando = false;

  bool _isPizza          = false;
  bool _pizzaMeioAMeio   = false;
  bool _pizzaTresSabores = false;

  bool get _editando => widget.produto != null;

  @override
  void initState() {
    super.initState();
    _carregarCats();
    if (_editando) {
      final p = widget.produto!;
      _nomeCtrl.text      = p['nome']?.toString() ?? '';
      _descricaoCtrl.text = p['descricao']?.toString() ?? '';
      _precoCtrl.text     = (double.tryParse(p['preco']?.toString() ?? '0') ?? 0)
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      final img = p['imagem']?.toString() ?? '';
      if (img.isNotEmpty) _imagemBase64 = img;
      _isPizza          = p['is_pizza']           as bool? ?? false;
      _pizzaMeioAMeio   = p['pizza_meio_a_meio']  as bool? ?? false;
      _pizzaTresSabores = p['pizza_tres_sabores'] as bool? ?? false;
    }
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
      source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 75,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _imagemBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}');
  }

  Future<void> _carregarCats() async {
    final cats = await ApiService.getCategorias();
    if (!mounted || cats.isEmpty) return;
    final idCat = widget.produto?['id_categoria'];
    final catInicial = idCat != null
        ? cats.firstWhere(
            (c) => c['id_categoria'].toString() == idCat.toString(),
            orElse: () => cats.first,
          )
        : cats.first;
    setState(() {
      _categorias = cats;
      _catSel = catInicial;
      _isPizza = (catInicial['nome']?.toString().toLowerCase() == 'pizzas');
    });
  }

  Future<void> _salvar() async {
    final nome      = _nomeCtrl.text.trim();
    final descricao = _descricaoCtrl.text.trim();
    final precoRaw = double.tryParse(
            _precoCtrl.text.trim().replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0;
    final preco = _isPizza ? 0.0 : precoRaw;
    if (nome.isEmpty || _catSel == null) {
      setState(() => _erro = 'Preencha nome e categoria.');
      return;
    }
    if (!_isPizza && preco <= 0) {
      setState(() => _erro = 'Preencha o preço.');
      return;
    }
    final idCategoria = _catSel!['id_categoria'] is int
        ? _catSel!['id_categoria'] as int
        : int.tryParse(_catSel!['id_categoria'].toString()) ?? 0;
    setState(() => _salvando = true);

    String? erro;
    if (_editando) {
      final idProduto = widget.produto!['id_produto'] is int
          ? widget.produto!['id_produto'] as int
          : int.tryParse(widget.produto!['id_produto'].toString()) ?? 0;
      erro = await ApiService.updateProduto(
        idProduto: idProduto, idCategoria: idCategoria,
        nome: nome, descricao: descricao, preco: preco, imagem: _imagemBase64,
        isPizza: _isPizza, pizzaMeioAMeio: _pizzaMeioAMeio, pizzaTresSabores: _pizzaTresSabores,
      );
    } else {
      final idEmpresa = SessionStore.idEmpresa;
      if (idEmpresa == null) { setState(() { _salvando = false; _erro = 'Sessão expirada.'; }); return; }
      erro = await ApiService.createProduto(
        idEmpresa: idEmpresa, idCategoria: idCategoria,
        nome: nome, descricao: descricao, preco: preco, imagem: _imagemBase64,
        isPizza: _isPizza, pizzaMeioAMeio: _pizzaMeioAMeio, pizzaTresSabores: _pizzaTresSabores,
      );
    }

    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) { setState(() => _erro = erro); return; }
    widget.onSalvo();
    Navigator.pop(context);
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: _bgPage,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cor, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(
              _editando ? 'Editar produto' : 'Novo produto',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _darkText),
            ),
            const SizedBox(height: 4),
            Text(
              _editando ? 'Altere os dados do produto' : 'Preencha os dados do item do cardápio',
              style: GoogleFonts.poppins(fontSize: 12, color: _muted),
            ),
            const SizedBox(height: 20),

            TextField(controller: _nomeCtrl, decoration: _deco('Nome do produto *')),
            const SizedBox(height: 12),
            if (!_isPizza) ...[ 
              TextField(
                controller: _precoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _deco('Preço (R\$) *'),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _descricaoCtrl,
              maxLines: 3,
              decoration: _deco('Ingredientes / Descrição'),
            ),
            const SizedBox(height: 12),

            // Foto
            GestureDetector(
              onTap: _selecionarImagem,
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  color: _bgPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _imagemBase64 != null ? _cor.withValues(alpha: 0.4) : Colors.grey.shade200,
                  ),
                ),
                child: _imagemBase64 != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              Base64Cache.decode(_imagemBase64!),
                              width: double.infinity, height: 110, fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 8, top: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                              child: IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: _selecionarImagem,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate_outlined, color: _cor, size: 30),
                          const SizedBox(height: 6),
                          Text('Toque para adicionar foto',
                              style: GoogleFonts.poppins(color: _cor, fontSize: 12)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),

            _categorias.isEmpty
                ? const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(color: _cor, strokeWidth: 2)))
                : DropdownButtonFormField<Map<String, dynamic>>(
                    // ignore: deprecated_member_use
                    value: _catSel,
                    decoration: _deco('Categoria *'),
                    items: _categorias
                        .map((c) => DropdownMenuItem(value: c, child: Text(c['nome']?.toString() ?? '')))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _catSel = v;
                      _isPizza = (v != null && (v['nome']?.toString().toLowerCase() == 'pizzas'));
                      if (!_isPizza) { _pizzaMeioAMeio = false; _pizzaTresSabores = false; }
                    }),
                  ),
            const SizedBox(height: 16),

            if (_isPizza) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _cor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Divisão de sabores',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600, color: _darkText)),
                    const SizedBox(height: 2),
                    Text('Quais divisões o cliente pode montar:',
                        style: GoogleFonts.poppins(fontSize: 11, color: _muted)),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Meio a meio (2 sabores)',
                          style: GoogleFonts.poppins(fontSize: 13, color: _darkText)),
                      value: _pizzaMeioAMeio,
                      activeColor: _cor,
                      onChanged: (v) => setState(() => _pizzaMeioAMeio = v ?? false),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('3 sabores',
                          style: GoogleFonts.poppins(fontSize: 13, color: _darkText)),
                      value: _pizzaTresSabores,
                      activeColor: _cor,
                      onChanged: (v) => setState(() => _pizzaTresSabores = v ?? false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(_erro!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                ),
              ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cor,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _salvando
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _editando ? 'Salvar alterações' : 'Adicionar ao cardápio',
                        style: GoogleFonts.poppins(
                            fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
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
  final _nomeCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _precoCtrl = TextEditingController();
  final _grupoCtrl = TextEditingController(text: 'Adicionais');
  final _maxCtrl   = TextEditingController(text: '3');
  bool _obrigatorio = false;
  String? _erro;
  bool _salvando = false;

  @override
  void initState() { super.initState(); _carregar(); }

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
      idProduto: widget.idProduto, grupo: grupo, maximoGrupo: maximo,
      obrigatorio: _obrigatorio, nome: nome, descricao: _descCtrl.text.trim(), preco: preco,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) { setState(() => _erro = erro); return; }
    _nomeCtrl.clear(); _descCtrl.clear(); _precoCtrl.clear();
    _carregar();
  }

  Future<void> _deletar(int idAdicional) async {
    await ApiService.deleteAdicional(idAdicional);
    _carregar();
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    filled: true, fillColor: _bgPage,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _cor)),
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
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Adicionais do produto',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _darkText)),
            const SizedBox(height: 2),
            Text('Opções extras que o cliente pode escolher',
                style: GoogleFonts.poppins(fontSize: 12, color: _muted)),
            const SizedBox(height: 16),

            if (_loading)
              const Center(child: CircularProgressIndicator(color: _cor))
            else if (_grupos.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _bgPage, borderRadius: BorderRadius.circular(12)),
                child: Text('Nenhum adicional cadastrado ainda.',
                    style: GoogleFonts.poppins(color: _muted, fontSize: 13)),
              )
            else
              ..._grupos.map((g) {
                final itens = List<Map<String, dynamic>>.from(g['itens'] as List? ?? []);
                final obrig = g['obrigatorio'] == true;
                final max   = g['maximo_grupo'];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _cor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text(g['grupo']?.toString() ?? '',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        if (obrig)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                            child: Text('OBRIGAT�RIO',
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        const SizedBox(width: 6),
                        Text('máx $max', style: GoogleFonts.poppins(fontSize: 11, color: _muted)),
                      ]),
                    ),
                    ...itens.map((item) {
                      final preco = item['preco'];
                      final precoVal = preco is num ? preco.toDouble() : double.tryParse(preco?.toString() ?? '') ?? 0.0;
                      final id = item['id_adicional'] is int
                          ? item['id_adicional'] as int
                          : int.tryParse(item['id_adicional']?.toString() ?? '') ?? 0;
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: Text(item['nome']?.toString() ?? '', style: GoogleFonts.poppins(fontSize: 13)),
                        subtitle: (item['descricao']?.toString() ?? '').isNotEmpty
                            ? Text(item['descricao'].toString(), style: GoogleFonts.poppins(fontSize: 11, color: _muted))
                            : null,
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                            precoVal == 0 ? 'Grátis' : '+ R\$ ${precoVal.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: precoVal == 0 ? Colors.green : _darkText,
                              fontSize: 12,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            onPressed: () => _deletar(id),
                          ),
                        ]),
                      );
                    }),
                    Divider(color: Colors.grey.shade100, height: 16),
                  ],
                );
              }),

            const SizedBox(height: 8),
            const _SecaoLabel('Adicionar novo item'),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(flex: 3, child: TextField(controller: _grupoCtrl, decoration: _deco('Grupo (ex: Molhos)'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _maxCtrl, keyboardType: TextInputType.number, decoration: _deco('Máx'))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Checkbox(value: _obrigatorio, onChanged: (v) => setState(() => _obrigatorio = v ?? false), activeColor: _cor),
              Text('Obrigatório', style: GoogleFonts.poppins(fontSize: 13)),
            ]),
            const SizedBox(height: 4),
            TextField(controller: _nomeCtrl, decoration: _deco('Nome do item *')),
            const SizedBox(height: 8),
            TextField(controller: _descCtrl, decoration: _deco('Descrição (opcional)')),
            const SizedBox(height: 8),
            TextField(
              controller: _precoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _deco('Preço extra (0 = grátis)'),
            ),
            const SizedBox(height: 8),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cor, elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _salvando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Salvar adicional',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
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
  bool      _carregando = true;
  DateTime  _dataInicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime  _dataFim    = DateTime.now();
  Timer?    _timer;

  @override
  void initState() {
    super.initState();
    _carregar();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _carregar(silencioso: true));
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  String _fmtBR(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _carregar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _carregando = true);
    final id = SessionStore.idEmpresa;
    if (id != null) {
      final lista = await ApiService.getPedidosByEmpresa(id);
      if (mounted) setState(() => _pedidos = lista);
    }
    if (mounted && !silencioso) setState(() => _carregando = false);
  }

  Future<void> _selecionarData(bool isInicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isInicio ? _dataInicio : _dataFim,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: _cor)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { if (isInicio) { _dataInicio = picked; } else { _dataFim = picked; } });
      _carregar();
    }
  }

  void _gerarRelatorio() {
    final entregues  = _pedidos.where((p) => p['status'] == 'Entregue').length;
    final cancelados = _pedidos.where((p) => p['status'] == 'Cancelado').length;
    final outros     = _pedidos.length - entregues - cancelados;
    final total      = _pedidos
        .where((p) => p['status'] != 'Cancelado')
        .fold(0.0, (s, p) => s + (double.tryParse(p['valor_total']?.toString() ?? '0') ?? 0));
    final taxa = total * 0.15;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.bar_chart, color: _cor, size: 20),
          ),
          const SizedBox(width: 10),
          Text('Relatório', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_fmtBR(_dataInicio)} � ${_fmtBR(_dataFim)}',
                style: GoogleFonts.poppins(color: _muted, fontSize: 12)),
            const Divider(height: 20),
            _linhaRelatorio('Total de pedidos', '${_pedidos.length}'),
            _linhaRelatorio('Entregues', '$entregues', cor: Colors.green),
            _linhaRelatorio('Em andamento', '$outros', cor: Colors.orange),
            _linhaRelatorio('Cancelados', '$cancelados', cor: Colors.red),
            const Divider(height: 20),
            _linhaRelatorio('Receita bruta', 'R\$ ${total.toStringAsFixed(2)}', bold: true),
            _linhaRelatorio('Taxa Smarty (15%)', '- R\$ ${taxa.toStringAsFixed(2)}', cor: Colors.red),
            _linhaRelatorio('Valor líquido', 'R\$ ${(total - taxa).toStringAsFixed(2)}',
                bold: true, cor: Colors.blue),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fechar', style: GoogleFonts.poppins(color: _cor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _linhaRelatorio(String label, String valor, {Color? cor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
          Text(valor, style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: cor ?? (bold ? _darkText : _muted),
            fontSize: bold ? 14 : 13,
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _pedidos
        .where((p) => p['status'] != 'Cancelado')
        .fold(0.0, (s, p) => s + (double.tryParse(p['valor_total']?.toString() ?? '0') ?? 0));

    final emAndamento = _pedidos.where((p) => p['status'] != 'Cancelado' && p['status'] != 'Entregue').length;

    return Column(
      children: [
        // �� Header de métricas ������������������������������
        Container(
          color: _card,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filtro de período
              Row(children: [
                Expanded(child: _ChipData('De: ${_fmtBR(_dataInicio)}', () => _selecionarData(true))),
                const SizedBox(width: 8),
                Expanded(child: _ChipData('Até: ${_fmtBR(_dataFim)}', () => _selecionarData(false))),
              ]),
              const SizedBox(height: 14),
              // Stats strip
              Row(children: [
                _StatChip(label: 'Pedidos', valor: '${_pedidos.length}', cor: _cor),
                const SizedBox(width: 8),
                _StatChip(label: 'Em andamento', valor: '$emAndamento', cor: Colors.orange),
                const SizedBox(width: 8),
                _StatChip(label: 'Receita', valor: 'R\$ ${total.toStringAsFixed(2)}', cor: const Color(0xFF2E7D32)),
              ]),
            ],
          ),
        ),

        // �� Lista de pedidos �������������������������������
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator(color: _cor))
              : _pedidos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('Nenhum pedido encontrado',
                              style: GoogleFonts.poppins(color: _muted, fontSize: 14)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _carregar,
                      color: _cor,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: _pedidos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _CardPedido(
                          pedido: _pedidos[i],
                          onStatusAtualizado: _carregar,
                        ),
                      ),
                    ),
        ),

        // �� Botão relatório ��������������������������������
        Container(
          color: _card,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: OutlinedButton.icon(
            onPressed: _gerarRelatorio,
            style: OutlinedButton.styleFrom(
              foregroundColor: _cor,
              side: const BorderSide(color: _cor, width: 1.4),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 0),
            ),
            icon: const Icon(Icons.bar_chart, size: 18),
            label: Text('Gerar relatório do período',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ],
    );
  }
}

class _ChipData extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;
  const _ChipData(this.texto, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          color: _bgPage,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(texto, style: GoogleFonts.poppins(fontSize: 12, color: _darkText)),
            const Icon(Icons.calendar_today, size: 14, color: _muted),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, valor;
  final Color cor;
  const _StatChip({required this.label, required this.valor, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valor, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: cor)),
            Text(label, style: GoogleFonts.poppins(fontSize: 10, color: _muted)),
          ],
        ),
      ),
    );
  }
}

// �� Card de pedido ���������������������������������������������
class _CardPedido extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final VoidCallback? onStatusAtualizado;
  const _CardPedido({required this.pedido, this.onStatusAtualizado});

  @override
  Widget build(BuildContext context) {
    final status = pedido['status']?.toString() ?? '';
    final valor  = double.tryParse(pedido['valor_total']?.toString() ?? '0') ?? 0;

    Color statusCor;
    switch (status) {
      case 'Entregue': statusCor = Colors.green; break;
      case 'Cancelado': statusCor = Colors.red; break;
      default: statusCor = Colors.orange;
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => _PedidoDetalheSheet(idPedido: idPedido, onStatusAtualizado: onStatusAtualizado),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Container(width: 4, color: statusCor, height: double.infinity,
                  constraints: const BoxConstraints(minHeight: 72)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('#$idPedido',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: _darkText)),
                          const SizedBox(width: 8),
                          Text(pedido['cliente']?.toString() ?? '',
                              style: GoogleFonts.poppins(fontSize: 13, color: _muted)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusCor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(status,
                                style: GoogleFonts.poppins(color: statusCor, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      if ((pedido['itens']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(pedido['itens']?.toString() ?? '',
                            style: GoogleFonts.poppins(fontSize: 12, color: _muted),
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time_outlined, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(pedido['criado_em']?.toString().substring(0, 16) ?? '',
                              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400)),
                          const Spacer(),
                          Text('R\$ ${valor.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32), fontSize: 14)),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// PEDIDO � detalhe sheet (empresa)
// =============================================================
class _PedidoDetalheSheet extends StatefulWidget {
  final int idPedido;
  final VoidCallback? onStatusAtualizado;
  const _PedidoDetalheSheet({required this.idPedido, this.onStatusAtualizado});

  @override
  State<_PedidoDetalheSheet> createState() => _PedidoDetalheSheetState();
}

class _PedidoDetalheSheetState extends State<_PedidoDetalheSheet> {
  Map<String, dynamic>? _pedido;
  bool _carregando  = true;
  bool _atualizando = false;
  int  _motoboyCount = 0;

  static const _statusNomes = {
    1: 'Criado', 2: 'Em Preparo', 3: 'A Caminho',
    4: 'Entregue', 5: 'Cancelado', 6: 'Aguardando Motoboy',
  };

  @override
  void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final results = await Future.wait([
      ApiService.getPedidoDetalhes(widget.idPedido),
      ApiService.getMotoboyCount(),
    ]);
    if (mounted) {
      final count = results[1] as Map<String, dynamic>;
      setState(() {
        _pedido       = results[0];
        _motoboyCount = (count['disponiveis'] is int
            ? count['disponiveis'] as int
            : int.tryParse(count['disponiveis']?.toString() ?? '0') ?? 0);
        _carregando   = false;
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
    final idEmpresa = SessionStore.idEmpresa;
    if (idEmpresa == null) return;
    final motoboys = await ApiService.getMotoboysDaEmpresa(idEmpresa);
    if (!mounted) return;
    if (motoboys.isEmpty) {
      setState(() => _atualizando = true);
      await ApiService.entregaPropria(widget.idPedido);
      await _carregar();
      setState(() => _atualizando = false);
      widget.onStatusAtualizado?.call();
      return;
    }
    final selecionado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ModalSelecionarMotoboy(motoboys: motoboys),
    );
    if (selecionado == null) return;
    setState(() => _atualizando = true);
    await ApiService.atribuirMotoboyEmpresa(
      idPedido: widget.idPedido,
      idMotoboyEmpresa: selecionado['id'] as int,
    );
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
        if (_carregando) return const Center(child: CircularProgressIndicator(color: _cor));
        if (_pedido == null) return Center(child: Text('Erro ao carregar pedido.', style: GoogleFonts.poppins()));

        final p = _pedido!;
        final idStatus    = p['id_status'] is int ? p['id_status'] as int : int.tryParse(p['id_status']?.toString() ?? '') ?? 1;
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
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // Cabeçalho do pedido
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pedido #${p['id_pedido']}',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _darkText)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _corStatus(status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status,
                        style: GoogleFonts.poppins(color: _corStatus(status), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _secao('Cliente'),
              _infoLinha(Icons.person_outline, p['cliente']?.toString() ?? ''),
              if ((p['cliente_email']?.toString() ?? '').isNotEmpty)
                _infoLinha(Icons.email_outlined, p['cliente_email']?.toString() ?? ''),
              if ((p['cliente_telefone']?.toString() ?? '').isNotEmpty)
                _infoLinha(Icons.phone_outlined, p['cliente_telefone']?.toString() ?? ''),
              const SizedBox(height: 16),

              if ((p['endereco_entrega']?.toString() ?? '').isNotEmpty) ...[
                _secao('Endereço de entrega'),
                _infoLinha(Icons.location_on_outlined, p['endereco_entrega']?.toString() ?? ''),
                const SizedBox(height: 16),
              ],

              if ((p['observacao']?.toString() ?? '').isNotEmpty) ...[
                _secao('Observação'),
                _infoLinha(Icons.notes, p['observacao']?.toString() ?? ''),
                const SizedBox(height: 16),
              ],

              _secao('Itens do pedido'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bgPage,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: itens.map((item) {
                    final qtd   = item['quantidade'] is int ? item['quantidade'] as int : int.tryParse(item['quantidade']?.toString() ?? '') ?? 1;
                    final preco = double.tryParse(item['preco_unit']?.toString() ?? '0') ?? 0;
                    final sub   = qtd * preco;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['produto']?.toString() ?? '',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text('$qtd×  R\$ ${preco.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: _muted)),
                                if ((item['observacao']?.toString() ?? '').isNotEmpty)
                                  Text(item['observacao']!.toString(),
                                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange[700], fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                          Text('R\$ ${sub.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('R\$ ${valor.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _cor)),
                ],
              ),
              const SizedBox(height: 24),

              // Ações
              if (idStatus < 4 && idStatus != 5) ...[
                _secao('Ações'),
                const SizedBox(height: 8),
                if (_atualizando)
                  const Center(child: CircularProgressIndicator(color: _cor))
                else
                  Column(children: [
                    if (idStatus == 2 && !quasePronto)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _marcarQuasePronto,
                            icon: const Icon(Icons.notifications_active, size: 18),
                            label: Text('Avisar cliente: Quase Pronto!',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    if (quasePronto)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          const Icon(Icons.check_circle, color: Colors.deepOrange, size: 16),
                          const SizedBox(width: 6),
                          Text('Cliente avisado que está quase pronto',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.deepOrange[700])),
                        ]),
                      ),
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
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: _entregaPropria,
                                  icon: const Icon(Icons.directions_car, size: 18),
                                  label: Text('Entrega Própria',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _cor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: _chamarMotoboy,
                                  icon: const Icon(Icons.delivery_dining, size: 18),
                                  label: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Text('Motoboy',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                                    if (_motoboyCount > 0) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                                        child: Text('$_motoboyCount',
                                            style: const TextStyle(color: _cor, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ]),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    if (tipoEntrega.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          Icon(tipoEntrega == 'propria' ? Icons.directions_car : Icons.delivery_dining,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 6),
                          Text(
                            tipoEntrega == 'propria' ? 'Entrega própria em andamento' : 'Aguardando motoboy',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.green),
                          ),
                        ]),
                      ),
                    if (idStatus != 2 || tipoEntrega.isNotEmpty)
                      Row(children: [
                        if (idStatus < 4 && idStatus != 6)
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _cor, foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _atualizarStatus(idStatus + 1),
                              icon: const Icon(Icons.arrow_forward, size: 18),
                              label: Text(_statusNomes[idStatus + 1] ?? 'Avançar',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        if (idStatus < 4 && idStatus != 6) const SizedBox(width: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _atualizarStatus(5),
                          child: Text('Cancelar', style: GoogleFonts.poppins()),
                        ),
                      ]),
                  ]),
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
        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: _muted, letterSpacing: 0.5)),
  );

  Widget _infoLinha(IconData icon, String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _muted),
        const SizedBox(width: 6),
        Expanded(child: Text(texto, style: GoogleFonts.poppins(fontSize: 13, color: _darkText))),
      ],
    ),
  );
}


// =============================================================
// SHEET: SABORES DE PIZZA DA EMPRESA
// =============================================================
class _PizzaSaboresSheet extends StatefulWidget {
  final int idProduto;
  const _PizzaSaboresSheet({required this.idProduto});

  @override
  State<_PizzaSaboresSheet> createState() => _PizzaSaboresSheetState();
}

class _PizzaSaboresSheetState extends State<_PizzaSaboresSheet> {
  List<Map<String, dynamic>> _sabores = [];
  bool _loading = true;
  final _nomeCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _precoCtrl = TextEditingController();
  String? _erro;
  bool _salvando = false;

  @override
  void initState() { super.initState(); _carregar(); }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descCtrl.dispose();
    _precoCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final s = await ApiService.getPizzaSabores(widget.idProduto);
    if (mounted) setState(() { _sabores = s; _loading = false; });
  }

  Future<void> _salvar() async {
    final nome  = _nomeCtrl.text.trim();
    final desc  = _descCtrl.text.trim();
    final preco = double.tryParse(_precoCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    if (nome.isEmpty || preco <= 0) {
      setState(() => _erro = 'Nome e preço são obrigatórios.');
      return;
    }
    setState(() { _salvando = true; _erro = null; });
    final erro = await ApiService.createPizzaSabor(
      idProduto: widget.idProduto, nome: nome, descricao: desc, preco: preco,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) { setState(() => _erro = erro); return; }
    _nomeCtrl.clear(); _descCtrl.clear(); _precoCtrl.clear();
    _carregar();
  }

  Future<void> _deletar(int idSabor) async {
    await ApiService.deletePizzaSabor(idSabor);
    _carregar();
  }

  Future<void> _toggleAtivo(Map<String, dynamic> s) async {
    final idSabor = s['id_sabor'] is int ? s['id_sabor'] as int
        : int.tryParse(s['id_sabor'].toString()) ?? 0;
    final novoAtivo = !(s['ativo'] as bool? ?? true);
    await ApiService.updatePizzaSabor(idSabor: idSabor, ativo: novoAtivo);
    _carregar();
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: _bgPage,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cor, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, sc) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.local_pizza_outlined, color: _cor),
                  const SizedBox(width: 8),
                  Text('Sabores de Pizza',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _darkText)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Preço base da pizza + média dos sabores escolhidos',
                  style: GoogleFonts.poppins(fontSize: 11, color: _muted)),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  // Formulário de novo sabor
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _cor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _cor.withValues(alpha: 0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Adicionar sabor',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _darkText)),
                        const SizedBox(height: 10),
                        TextField(controller: _nomeCtrl, decoration: _deco('Nome do sabor *')),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _precoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _deco('Preço adicional (R\$) *'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _descCtrl,
                          maxLines: 2,
                          decoration: _deco('Ingredientes / Descrição'),
                        ),
                        if (_erro != null) ...[
                          const SizedBox(height: 8),
                          Text(_erro!, style: TextStyle(color: Colors.red.shade600, fontSize: 12)),
                        ],
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _salvando ? null : _salvar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _cor, foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: _salvando
                                ? const SizedBox(width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.add, size: 18),
                            label: Text('Adicionar', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Lista de sabores
                  Text('Sabores cadastrados',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _darkText)),
                  const SizedBox(height: 10),
                  if (_loading)
                    const Center(child: CircularProgressIndicator(color: _cor, strokeWidth: 2))
                  else if (_sabores.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text('Nenhum sabor cadastrado ainda.',
                            style: GoogleFonts.poppins(color: _muted, fontSize: 13)),
                      ),
                    )
                  else
                    ...(_sabores.map((s) {
                      final id    = s['id_sabor'] is int ? s['id_sabor'] as int
                          : int.tryParse(s['id_sabor'].toString()) ?? 0;
                      final nome  = s['nome']?.toString() ?? '';
                      final desc  = s['descricao']?.toString() ?? '';
                      final preco = double.tryParse(s['preco']?.toString() ?? '0') ?? 0;
                      final ativo = s['ativo'] as bool? ?? true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ativo ? _cor.withValues(alpha: 0.15) : Colors.grey.shade200,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: ativo ? _cor.withValues(alpha: 0.12) : Colors.grey.shade100,
                            child: Icon(Icons.local_pizza_outlined,
                                color: ativo ? _cor : Colors.grey.shade400, size: 20),
                          ),
                          title: Text(nome,
                              style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w600,
                                  color: ativo ? _darkText : _muted)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (desc.isNotEmpty)
                                Text(desc, style: GoogleFonts.poppins(fontSize: 11, color: _muted),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('+ R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12, color: const Color(0xFF2E7D32),
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  ativo ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: ativo ? _cor : Colors.grey.shade400, size: 20,
                                ),
                                onPressed: () => _toggleAtivo(s),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                                onPressed: () async {
                                  final conf = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text('Remover sabor', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                                      content: Text('Remover "$nome"?', style: GoogleFonts.poppins()),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false),
                                            child: Text('Cancelar', style: GoogleFonts.poppins())),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red, foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: Text('Remover', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (conf == true) _deletar(id);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// TAB: FINANCEIRO
// =============================================================
class _TabFinanceiro extends StatefulWidget {
  const _TabFinanceiro();
  @override
  State<_TabFinanceiro> createState() => _TabFinanceiroState();
}

class _TabFinanceiroState extends State<_TabFinanceiro> {
  Map<String, dynamic>? _dados;
  bool _carregando = true;
  int _periodoSel = 1; // 0=hoje, 1=7dias, 2=30dias

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  String _dataInicio(int opcao) {
    final hoje = DateTime.now();
    final d = opcao == 0
        ? hoje
        : opcao == 1
            ? hoje.subtract(const Duration(days: 6))
            : hoje.subtract(const Duration(days: 29));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _dataFim() {
    final hoje = DateTime.now();
    return '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final dados = await ApiService.getRelatorioFinanceiro(
      inicio: _dataInicio(_periodoSel),
      fim: _dataFim(),
    );
    if (mounted) setState(() { _dados = dados; _carregando = false; });
  }

  @override
  Widget build(BuildContext context) {
    final resumo       = _dados?['resumo']       as Map<String, dynamic>? ?? {};
    final porPagamento = (_dados?['por_pagamento'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final topProdutos  = (_dados?['top_produtos']  as List?)?.cast<Map<String, dynamic>>() ?? [];
    final porDia       = (_dados?['por_dia']       as List?)?.cast<Map<String, dynamic>>() ?? [];

    final totalFaturado = (resumo['total_faturado'] as num?)?.toDouble() ?? 0.0;
    final totalPedidos  = (resumo['total_pedidos']  as num?)?.toInt()    ?? 0;
    final ticketMedio   = (resumo['ticket_medio']   as num?)?.toDouble() ?? 0.0;
    final cancelados    = (resumo['pedidos_cancelados'] as num?)?.toInt() ?? 0;

    final labels = ['Hoje', '7 dias', '30 dias'];

    return RefreshIndicator(
      onRefresh: _carregar,
      color: _cor,
      child: _carregando
          ? const Center(child: CircularProgressIndicator(color: _cor))
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Seletor de período
                  Row(
                    children: List.generate(labels.length, (i) {
                      final sel = i == _periodoSel;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_periodoSel == i) return;
                            setState(() => _periodoSel = i);
                            _carregar();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: sel ? _cor : _bgPage,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: sel ? _cor : Colors.grey.shade200),
                            ),
                            child: Text(
                              labels[i],
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                color: sel ? Colors.white : _muted,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Card destaque — faturamento total
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_cor, _corDeep],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(color: _cor.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.trending_up, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Text('Faturamento do período',
                              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                        ]),
                        const SizedBox(height: 10),
                        Text(
                          'R\$ ${totalFaturado.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalPedidos pedidos · $cancelados cancelados',
                          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mini cards: ticket médio + cancelados
                  Row(children: [
                    Expanded(child: _MiniCard(
                      titulo: 'Ticket médio',
                      valor: 'R\$ ${ticketMedio.toStringAsFixed(2)}',
                      icone: Icons.receipt_outlined,
                      cor: const Color(0xFF1565C0),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _MiniCard(
                      titulo: 'Pedidos entregues',
                      valor: '$totalPedidos',
                      icone: Icons.check_circle_outline,
                      cor: Colors.green.shade700,
                    )),
                  ]),
                  const SizedBox(height: 20),

                  // Formas de pagamento
                  if (porPagamento.isNotEmpty) ...[
                    const _SecaoLabel('Formas de pagamento'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                      ),
                      child: Column(
                        children: porPagamento.asMap().entries.map((e) {
                          final i   = e.key;
                          final pag = e.value;
                          final forma = pag['forma']?.toString() ?? '';
                          final qtd   = (pag['qtd']   as num?)?.toInt()    ?? 0;
                          final total = (pag['total'] as num?)?.toDouble() ?? 0.0;
                          return Column(
                            children: [
                              if (i > 0) Divider(height: 16, color: Colors.grey.shade100),
                              Row(children: [
                                Container(
                                  width: 34, height: 34,
                                  decoration: BoxDecoration(
                                    color: _cor.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.payment_outlined, color: _cor, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(forma, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _darkText)),
                                    Text('$qtd pedido${qtd != 1 ? 's' : ''}',
                                        style: GoogleFonts.poppins(fontSize: 11, color: _muted)),
                                  ]),
                                ),
                                Text('R\$ ${total.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: _darkText)),
                              ]),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Top produtos
                  if (topProdutos.isNotEmpty) ...[
                    const _SecaoLabel('Produtos mais vendidos'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                      ),
                      child: Column(
                        children: topProdutos.asMap().entries.map((e) {
                          final rank  = e.key + 1;
                          final prod  = e.value;
                          final nome  = prod['nome']?.toString()  ?? '';
                          final qtd   = (prod['qtd']   as num?)?.toInt()    ?? 0;
                          final total = (prod['total'] as num?)?.toDouble() ?? 0.0;
                          final rankColor = rank == 1
                              ? const Color(0xFFFFB300)
                              : rank == 2
                                  ? const Color(0xFF9E9E9E)
                                  : rank == 3
                                      ? const Color(0xFF8D6E63)
                                      : _muted;
                          return Column(
                            children: [
                              if (rank > 1) Divider(height: 16, color: Colors.grey.shade100),
                              Row(children: [
                                Container(
                                  width: 34, height: 34,
                                  decoration: BoxDecoration(
                                    color: rankColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$rank',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: rankColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(nome, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _darkText)),
                                    Text('$qtd unidade${qtd != 1 ? 's' : ''} vendida${qtd != 1 ? 's' : ''}',
                                        style: GoogleFonts.poppins(fontSize: 11, color: _muted)),
                                  ]),
                                ),
                                Text('R\$ ${total.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: _darkText)),
                              ]),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Faturamento por dia
                  if (porDia.isNotEmpty) ...[
                    const _SecaoLabel('Por dia'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                      ),
                      child: Column(
                        children: porDia.asMap().entries.map((e) {
                          final i     = e.key;
                          final dia   = e.value;
                          final data  = dia['dia']?.toString()     ?? '';
                          final peds  = (dia['pedidos'] as num?)?.toInt()    ?? 0;
                          final total = (dia['total']   as num?)?.toDouble() ?? 0.0;
                          // Formata YYYY-MM-DD → DD/MM
                          String dataFmt = data;
                          try {
                            final partes = data.split('-');
                            if (partes.length == 3) dataFmt = '${partes[2]}/${partes[1]}';
                          } catch (e, st) { AppLogger.e('PaginaEmpresa', e, st); }
                          return Column(
                            children: [
                              if (i > 0) Divider(height: 16, color: Colors.grey.shade100),
                              Row(children: [
                                Text(dataFmt,
                                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _darkText)),
                                const SizedBox(width: 8),
                                Text('· $peds pedido${peds != 1 ? 's' : ''}',
                                    style: GoogleFonts.poppins(fontSize: 12, color: _muted)),
                                const Spacer(),
                                Text('R\$ ${total.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                              ]),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  if (_dados == null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(children: [
                          Icon(Icons.bar_chart_outlined, size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('Não foi possível carregar o relatório.',
                              style: GoogleFonts.poppins(color: _muted, fontSize: 14)),
                        ]),
                      ),
                    ),
                ],
              ),
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
  bool _carregando = true;
  String? _fotoPerfil;
  String? _fotoCapa;
  bool _salvandoFotoPerfil = false;
  bool _salvandoFotoCapa = false;
  String? _endereco;
  double? _lat;
  double? _lng;
  double _taxaMinima   = 7.0;
  int    _tempoPreparo = 30;

  @override
  void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final id = SessionStore.idEmpresa;
    if (id != null) {
      final results = await Future.wait([
        ApiService.getEnderecoEmpresa(id),
        ApiService.getFotosEmpresa(id),
        ApiService.getConfiguracoes(id),
      ]);
      final endData = results[0];
      final fotos   = results[1] as Map<String, String?>;
      final config  = results[2];
      if (mounted) {
        setState(() {
          _endereco   = endData?['endereco']?.toString();
          _lat        = endData?['latitude']  is num ? (endData!['latitude']  as num).toDouble() : null;
          _lng        = endData?['longitude'] is num ? (endData!['longitude'] as num).toDouble() : null;
          final fotoPerfil = fotos['foto_perfil'];
          final fotoCapa = fotos['foto_capa'];
          if (fotoPerfil != null && fotoPerfil.isNotEmpty) _fotoPerfil = fotoPerfil;
          if (fotoCapa != null && fotoCapa.isNotEmpty) _fotoCapa = fotoCapa;
          if (config != null) {
            _taxaMinima   = config['taxa_minima']   is num ? (config['taxa_minima']   as num).toDouble() : _taxaMinima;
            _tempoPreparo = config['tempo_preparo'] is int ?  config['tempo_preparo'] as int
                : int.tryParse(config['tempo_preparo']?.toString() ?? '') ?? _tempoPreparo;
          }
        });
      }
    }
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _editarEndereco() async {
    final res = await Navigator.push<EnderecoSelecionado>(
      context,
      MaterialPageRoute(builder: (_) => SelecionarEnderecoPage(
        enderecoInicial: _endereco, latInicial: _lat, lngInicial: _lng,
      )),
    );
    if (res == null || !mounted) return;
    final id = SessionStore.idEmpresa;
    if (id == null) return;
    final erro = await ApiService.atualizarEnderecoEmpresa(id, res.endereco, res.lat, res.lng);
    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro), backgroundColor: Colors.red));
    } else {
      SessionStore.enderecoEmpresa = res.endereco;
      SessionStore.latEmpresa = res.lat;
      SessionStore.lngEmpresa = res.lng;
      setState(() { _endereco = res.endereco; _lat = res.lat; _lng = res.lng; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Endereço atualizado!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _selecionarFotoPerfil() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600, maxHeight: 600, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    setState(() => _salvandoFotoPerfil = true);
    final idEmpresa = SessionStore.idEmpresa;
    if (idEmpresa != null) {
      await ApiService.atualizarFotoEmpresa(idEmpresa, fotoPerfil: b64);
      if (mounted) setState(() { _fotoPerfil = b64; _salvandoFotoPerfil = false; });
    } else {
      setState(() => _salvandoFotoPerfil = false);
    }
  }

  Future<void> _selecionarFotoCapa() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1400, maxHeight: 900, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    setState(() => _salvandoFotoCapa = true);
    final idEmpresa = SessionStore.idEmpresa;
    if (idEmpresa != null) {
      await ApiService.atualizarFotoEmpresa(idEmpresa, fotoCapa: b64);
      if (mounted) setState(() { _fotoCapa = b64; _salvandoFotoCapa = false; });
    } else {
      setState(() => _salvandoFotoCapa = false);
    }
  }

  Future<void> _editarConfiguracoes() async {
    final taxaCtrl  = TextEditingController(text: _taxaMinima.toStringAsFixed(2));
    final tempoCtrl = TextEditingController(text: _tempoPreparo.toString());
    String? erro;

    final salvo = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Configurações de entrega',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: taxaCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Taxa mínima (R\$)',
                  prefixText: 'R\$ ',
                  helperText: 'Mínimo cobrado por entrega. Ex: 7.00',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: _bgPage,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: tempoCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Tempo de preparo (min)',
                  suffixText: 'min',
                  helperText: 'Tempo médio até ficar pronto. Ex: 30',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: _bgPage,
                ),
              ),
              if (erro != null) ...[
                const SizedBox(height: 8),
                Text(erro!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _cor, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final taxa  = double.tryParse(taxaCtrl.text.trim().replaceAll(',', '.'));
                final tempo = int.tryParse(tempoCtrl.text.trim());
                if (taxa == null || taxa < 0) { setS(() => erro = 'Taxa inválida.'); return; }
                if (tempo == null || tempo < 1) { setS(() => erro = 'Tempo inválido.'); return; }
                final id = SessionStore.idEmpresa;
                if (id == null) return;
                final erroApi = await ApiService.atualizarConfiguracoes(id, taxaMinima: taxa, tempoPreparo: tempo);
                if (!ctx.mounted) return;
                if (erroApi != null) { setS(() => erro = erroApi); return; }
                Navigator.pop(ctx, true);
              },
              child: Text('Salvar', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    taxaCtrl.dispose();
    tempoCtrl.dispose();

    if (salvo == true && mounted) {
      final id = SessionStore.idEmpresa;
      if (id == null) return;
      final config = await ApiService.getConfiguracoes(id);
      if (config != null && mounted) {
        setState(() {
          _taxaMinima   = config['taxa_minima']   is num ? (config['taxa_minima']   as num).toDouble() : _taxaMinima;
          _tempoPreparo = config['tempo_preparo'] is int ?  config['tempo_preparo'] as int
              : int.tryParse(config['tempo_preparo']?.toString() ?? '') ?? _tempoPreparo;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações salvas!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Center(child: CircularProgressIndicator(color: _cor));

    final temEndereco = _endereco != null && _endereco!.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _carregar,
      color: _cor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // �� SE��O: PERFIL ����������������������������������
            const _SecaoLabel('Perfil'),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(children: [
                GestureDetector(
                  onTap: _selecionarFotoPerfil,
                  child: Stack(children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: _cor.withValues(alpha: 0.12),
                      backgroundImage: _fotoPerfil != null && _fotoPerfil!.contains(',')
                          ? MemoryImage(Base64Cache.decode(_fotoPerfil!))
                          : null,
                      child: _fotoPerfil == null
                          ? Text(
                              (SessionStore.nome ?? 'E').isNotEmpty ? (SessionStore.nome ?? 'E')[0].toUpperCase() : 'E',
                              style: GoogleFonts.poppins(fontSize: 26, color: _cor, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    if (_salvandoFotoPerfil)
                      const Positioned.fill(
                        child: CircleAvatar(
                          backgroundColor: Colors.black26,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _cor, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(SessionStore.nome ?? 'Minha Empresa',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _darkText)),
                      const SizedBox(height: 2),
                      Text(SessionStore.email ?? '',
                          style: GoogleFonts.poppins(fontSize: 12, color: _muted),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _selecionarFotoPerfil,
                        child: Text(
                          _fotoPerfil == null ? 'Adicionar foto de perfil ' : 'Alterar foto de perfil ',
                          style: GoogleFonts.poppins(fontSize: 12, color: _cor, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _selecionarFotoCapa,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 124,
                      child: _fotoCapa != null && _fotoCapa!.contains(',')
                          ? Image.memory(
                              Base64Cache.decode(_fotoCapa!),
                              fit: BoxFit.cover,
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_corDeep, _cor.withValues(alpha: 0.80)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Foto de capa',
                                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: _darkText)),
                                const SizedBox(height: 2),
                                Text(
                                  _fotoCapa == null
                                      ? 'Adicione uma imagem maior para destacar seu restaurante.'
                                      : 'Toque para trocar a imagem de capa do restaurante.',
                                  style: GoogleFonts.poppins(fontSize: 12, color: _muted),
                                ),
                              ],
                            ),
                          ),
                          if (_salvandoFotoCapa)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _cor),
                            )
                          else
                            const Icon(Icons.photo_camera_outlined, color: _cor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // �� SE��O: OPERA��O ��������������������������������
            const _SecaoLabel('Operação'),
            const SizedBox(height: 10),

            // Grupo de configurações (iOS-style)
            Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  // Endereço
                  _SettingsRow(
                    icon: Icons.location_on_outlined,
                    iconColor: temEndereco ? Colors.green : Colors.red,
                    iconBg: temEndereco ? Colors.green.shade50 : Colors.red.shade50,
                    title: 'Endereço da empresa',
                    subtitle: temEndereco ? _endereco! : 'Não cadastrado � obrigatório',
                    subtitleColor: temEndereco ? null : Colors.red,
                    trailing: temEndereco ? null : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                      child: Text('Obrigatório', style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    onTap: _editarEndereco,
                    isFirst: true,
                  ),
                  Divider(height: 1, indent: 60, color: Colors.grey.shade100),

                  // Configurações de entrega
                  _SettingsRow(
                    icon: Icons.tune_outlined,
                    iconColor: _cor,
                    iconBg: _cor.withValues(alpha: 0.10),
                    title: 'Entrega e preparo',
                    subtitle: 'Taxa mínima: R\$ ${_taxaMinima.toStringAsFixed(2)}  ·  Preparo: $_tempoPreparo min',
                    onTap: _editarConfiguracoes,
                  ),
                  Divider(height: 1, indent: 60, color: Colors.grey.shade100),

                  // Equipe
                  _SettingsRow(
                    icon: Icons.delivery_dining_outlined,
                    iconColor: const Color(0xFF5C6BC0),
                    iconBg: const Color(0xFFEDE7F6),
                    title: 'Minha Equipe',
                    subtitle: 'Gerencie seus motoboys de entrega',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmpresaMotoboyPage()),
                    ),
                    isLast: true,
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}

// =============================================================
// WIDGETS COMPARTILHADOS
// =============================================================

class _SecaoLabel extends StatelessWidget {
  final String texto;
  const _SecaoLabel(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 2),
      child: Row(children: [
        Container(
          width: 3, height: 14,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(color: _cor, borderRadius: BorderRadius.circular(2)),
        ),
        Text(
          texto.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: _muted,
            letterSpacing: 1.0,
          ),
        ),
      ]),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool isFirst, isLast;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.trailing,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: _darkText)),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontSize: 11, color: subtitleColor ?? _muted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ?? Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 20),
        ]),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String titulo, valor;
  final IconData icone;
  final Color cor;
  const _MiniCard({required this.titulo, required this.valor, required this.icone, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: cor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
          child: Icon(icone, color: cor, size: 18),
        ),
        const SizedBox(height: 10),
        Text(valor, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: cor)),
        Text(titulo, style: GoogleFonts.poppins(fontSize: 11, color: _muted)),
      ]),
    );
  }
}

// =============================================================
// MODAL � Selecionar motoboy da empresa para entrega própria
// =============================================================
class _ModalSelecionarMotoboy extends StatelessWidget {
  final List<Map<String, dynamic>> motoboys;
  const _ModalSelecionarMotoboy({required this.motoboys});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Text('Selecionar motoboy',
                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: _darkText)),
            const SizedBox(height: 2),
            Text('Quem vai fazer a entrega?',
                style: GoogleFonts.poppins(fontSize: 13, color: _muted)),
            const SizedBox(height: 16),
            ...motoboys.map((m) {
              final nome = m['nome']?.toString() ?? '';
              final tel  = m['telefone']?.toString() ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _bgPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: _cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delivery_dining, color: _cor, size: 22),
                  ),
                  title: Text(nome, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: tel.isNotEmpty
                      ? Text(tel, style: GoogleFonts.poppins(fontSize: 11, color: _muted))
                      : null,
                  trailing: const Icon(Icons.chevron_right, color: _cor),
                  onTap: () => Navigator.pop(context, m),
                ),
              );
            }),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.poppins(color: _muted)),
            ),
          ],
        ),
      ),
    );
  }
}

