import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../cardapio_empresa/cardapio_empresa_page.dart';

const Color _laranja = Color(0xFFF5841F);
const Color _amarelo = Color(0xFFFFC107);

// Categorias com cores e ícones
const _categorias = [
  _CatData('Lanches',    [Color(0xFFF5841F), Color(0xFFFF6B00)], Icons.lunch_dining),
  _CatData('Pizzas',     [Color(0xFFE53935), Color(0xFFFF6B6B)], Icons.local_pizza),
  _CatData('Almoços',    [Color(0xFF43A047), Color(0xFF66BB6A)], Icons.rice_bowl),
  _CatData('Bebidas',    [Color(0xFF1E88E5), Color(0xFF42A5F5)], Icons.local_drink),
  _CatData('Sobremesas', [Color(0xFFAB47BC), Color(0xFFCE93D8)], Icons.icecream),
];

class _CatData {
  final String label;
  final List<Color> gradient;
  final IconData icon;
  const _CatData(this.label, this.gradient, this.icon);
}

class BuscaPage extends StatefulWidget {
  const BuscaPage({super.key});

  @override
  State<BuscaPage> createState() => _BuscaPageState();
}

class _BuscaPageState extends State<BuscaPage> {
  final _ctrl   = TextEditingController();
  final _focus  = FocusNode();

  List<Map<String, dynamic>> _resultados = [];
  bool _loading    = false;
  bool _pesquisou  = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _buscar(String termo) async {
    if (termo.trim().isEmpty) {
      setState(() { _resultados = []; _pesquisou = false; });
      return;
    }
    setState(() { _loading = true; _pesquisou = true; });
    final r = await ApiService.buscarProdutos(termo.trim());
    if (mounted) setState(() { _resultados = r; _loading = false; });
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() { _resultados = []; _pesquisou = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _buscar(v.trim()));
  }

  void _limpar() {
    _ctrl.clear();
    setState(() { _resultados = []; _pesquisou = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(children: [
          // ── Barra de busca ────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _buscar,
                    onChanged: _onChanged,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'O que vai pedir hoje?',
                      hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF9E9E9E), size: 20),
                      suffixIcon: _ctrl.text.isNotEmpty
                          ? GestureDetector(
                              onTap: _limpar,
                              child: const Icon(Icons.close, size: 18, color: Color(0xFF9E9E9E)),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              if (_pesquisou) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _limpar,
                  child: const Text('Cancelar',
                      style: TextStyle(color: _laranja, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ],
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFE8E8E8)),

          // ── Conteúdo ──────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _laranja))
                : !_pesquisou
                    ? _buildGrid()
                    : _resultados.isEmpty
                        ? _buildVazio()
                        : _buildResultados(),
          ),
        ]),
      ),
    );
  }

  // ── Grid de categorias (estado inicial) ─────────────────────────
  Widget _buildGrid() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text('Categorias',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _CategoriaCard(cat: _categorias[i], onTap: () {
                _ctrl.text = _categorias[i].label;
                _buscar(_categorias[i].label);
              }),
              childCount: _categorias.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.8,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  // ── Lista de resultados ─────────────────────────────────────────
  Widget _buildResultados() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _resultados.length,
      itemBuilder: (_, i) {
        final empresa  = _resultados[i];
        final nome     = empresa['nome']?.toString() ?? '';
        final produtos = List<Map<String, dynamic>>.from(empresa['produtos'] as List? ?? []);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: InkWell(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => CardapioEmpresaPage(empresa: empresa))),
            borderRadius: BorderRadius.circular(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header do restaurante
              Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_laranja, _amarelo]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  const Icon(Icons.storefront, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(nome,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  Text('${produtos.length} item(s)',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              // Produtos
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: produtos.take(3).map((p) {
                    final precoRaw = p['preco'];
                    final preco = precoRaw is num
                        ? precoRaw.toDouble()
                        : double.tryParse(precoRaw?.toString() ?? '') ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        _MiniImagem(imagem: p['imagem']?.toString(), size: 40),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p['nome']?.toString() ?? '',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            if ((p['categoria_nome']?.toString() ?? '').isNotEmpty)
                              Text(p['categoria_nome'].toString(),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ]),
                        ),
                        Text('R\$ ${preco.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: _laranja, fontWeight: FontWeight.bold, fontSize: 13)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('Ver cardápio →',
                      style: TextStyle(color: _laranja, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildVazio() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off, size: 72, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text('Nenhum resultado para "${_ctrl.text}"',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _limpar,
          child: const Text('Limpar busca',
              style: TextStyle(color: _laranja, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── Card de categoria ─────────────────────────────────────────────
class _CategoriaCard extends StatelessWidget {
  final _CatData cat;
  final VoidCallback onTap;
  const _CategoriaCard({required this.cat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: cat.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: cat.gradient.first.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(cat.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
            Icon(cat.icon, color: Colors.white.withValues(alpha: 0.85), size: 34),
          ],
        ),
      ),
    );
  }
}

// ── Miniatura da imagem do produto ────────────────────────────────
class _MiniImagem extends StatelessWidget {
  final String? imagem;
  final double size;
  const _MiniImagem({this.imagem, this.size = 56});

  @override
  Widget build(BuildContext context) {
    if (imagem != null && imagem!.contains(',')) {
      try {
        final bytes = base64Decode(imagem!.split(',').last);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _laranja.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.fastfood, color: _laranja, size: size * 0.45),
    );
  }
}
