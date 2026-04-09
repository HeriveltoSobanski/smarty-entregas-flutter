import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// Resultado retornado ao confirmar
class EnderecoSelecionado {
  final String endereco;
  final double lat;
  final double lng;
  const EnderecoSelecionado({
    required this.endereco,
    required this.lat,
    required this.lng,
  });
}

// =============================================================
// SelecionarEnderecoPage
//
// Uso:
//   final res = await Navigator.push<EnderecoSelecionado>(
//     context,
//     MaterialPageRoute(builder: (_) => SelecionarEnderecoPage(
//       enderecoInicial: 'Rua X, 100, SP',  // opcional
//       latInicial: -23.5, lngInicial: -46.6,
//     )),
//   );
// =============================================================
class SelecionarEnderecoPage extends StatefulWidget {
  final String? enderecoInicial;
  final double? latInicial;
  final double? lngInicial;
  final String titulo;

  const SelecionarEnderecoPage({
    super.key,
    this.enderecoInicial,
    this.latInicial,
    this.lngInicial,
    this.titulo = 'Endereço da Empresa',
  });

  @override
  State<SelecionarEnderecoPage> createState() =>
      _SelecionarEnderecoPageState();
}

class _SelecionarEnderecoPageState extends State<SelecionarEnderecoPage> {
  final MapController _mapCtrl  = MapController();
  final _searchCtrl             = TextEditingController();
  final _focusNode              = FocusNode();

  // Brasil centro (Goiânia) como default; sobrescrito se lat/lng forem passados
  LatLng _pin     = const LatLng(-15.78, -47.93);
  String _endereco = '';
  bool   _buscando = false;
  String _erro     = '';

  @override
  void initState() {
    super.initState();
    if (widget.latInicial != null && widget.lngInicial != null) {
      _pin = LatLng(widget.latInicial!, widget.lngInicial!);
    }
    if (widget.enderecoInicial != null && widget.enderecoInicial!.isNotEmpty) {
      _endereco = widget.enderecoInicial!;
      _searchCtrl.text = widget.enderecoInicial!;
      // Se já tem lat/lng, não precisa geocodificar
      if (widget.latInicial == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _buscar());
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapCtrl.move(_pin, 16);
        });
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Geocodificação direta (endereço → coord) ────────────────
  Future<void> _buscar() async {
    final texto = _searchCtrl.text.trim();
    if (texto.isEmpty) return;
    _focusNode.unfocus();
    setState(() { _buscando = true; _erro = ''; });

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(texto)}'
        '&format=json&limit=1&countrycodes=br');

    try {
      final resp = await http.get(url, headers: {
        'User-Agent': 'SmartyEntregas/1.0',
        'Accept-Language': 'pt-BR',
      });

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lon = double.parse(data[0]['lon'].toString());
          final displayName = data[0]['display_name']?.toString() ?? texto;

          setState(() {
            _pin      = LatLng(lat, lon);
            _endereco = _simplificarEndereco(displayName);
          });
          _mapCtrl.move(_pin, 16);
        } else {
          setState(() => _erro = 'Endereço não encontrado. Tente ser mais específico.');
        }
      }
    } catch (_) {
      setState(() => _erro = 'Erro ao buscar. Verifique a conexão.');
    }

    setState(() => _buscando = false);
  }

  // ── Geocodificação reversa (coord → endereço) ───────────────
  Future<void> _reverseGeocode(LatLng ponto) async {
    setState(() { _buscando = true; _erro = ''; });

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=${ponto.latitude}&lon=${ponto.longitude}'
        '&countrycodes=br');

    try {
      final resp = await http.get(url, headers: {
        'User-Agent': 'SmartyEntregas/1.0',
        'Accept-Language': 'pt-BR',
      });

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final displayName = data['display_name']?.toString() ?? '';
        final enderecoFmt = _formatarDoReverse(data);

        setState(() {
          _endereco = enderecoFmt.isNotEmpty ? enderecoFmt : displayName;
          _searchCtrl.text = _endereco;
        });
      }
    } catch (_) {/* silencia — pin já está posicionado */}

    setState(() => _buscando = false);
  }

  // ── Formata o resultado do reverse de forma legível ─────────
  String _formatarDoReverse(Map<String, dynamic> data) {
    final addr = data['address'] as Map<String, dynamic>? ?? {};
    final partes = <String>[];

    final rua    = addr['road']?.toString() ?? addr['pedestrian']?.toString() ?? '';
    final numero = addr['house_number']?.toString() ?? '';
    final bairro = addr['suburb']?.toString() ?? addr['neighbourhood']?.toString() ?? '';
    final cidade = addr['city']?.toString() ?? addr['town']?.toString() ?? addr['village']?.toString() ?? '';
    final estado = addr['state']?.toString() ?? '';

    if (rua.isNotEmpty) {
      partes.add(numero.isNotEmpty ? '$rua, $numero' : rua);
    }
    if (bairro.isNotEmpty) partes.add(bairro);
    if (cidade.isNotEmpty) partes.add(cidade);
    if (estado.isNotEmpty) partes.add(estado);

    return partes.join(' - ');
  }

  // ── Simplifica o display_name do Nominatim ──────────────────
  String _simplificarEndereco(String displayName) {
    // displayName vem como "Rua X, 100, Bairro, Cidade, Estado, País"
    // Remove o país e mantém os primeiros segmentos relevantes
    final partes = displayName.split(', ');
    // Remove 'Brasil' e 'CEP' do final
    final filtradas = partes
        .where((p) => p != 'Brasil' && !RegExp(r'^\d{5}-\d{3}$').hasMatch(p))
        .toList();
    if (filtradas.length > 5) {
      return filtradas.sublist(0, 5).join(', ');
    }
    return filtradas.join(', ');
  }

  // ── Confirma e retorna ──────────────────────────────────────
  void _confirmar() {
    if (_endereco.isEmpty) {
      setState(() => _erro = 'Busque um endereço antes de confirmar.');
      return;
    }
    Navigator.pop(
      context,
      EnderecoSelecionado(
        endereco: _endereco,
        lat:      _pin.latitude,
        lng:      _pin.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFA726),
        foregroundColor: Colors.white,
        title: Text(widget.titulo,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Barra de busca ──────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller:  _searchCtrl,
                        focusNode:   _focusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted:  (_) => _buscar(),
                        decoration: InputDecoration(
                          hintText: 'Ex: Rua das Flores, 100, São Paulo',
                          prefixIcon: const Icon(Icons.search,
                              color: Color(0xFFFFA726)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFFFA726), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _buscando ? null : _buscar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFA726),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: _buscando
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Buscar',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                if (_erro.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 14, color: Colors.red),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(_erro,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Instrução ───────────────────────────────────────
          Container(
            color: const Color(0xFFFFF3E0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.touch_app,
                    size: 16, color: Color(0xFFE65100)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Busque o endereço ou toque no mapa para ajustar o pin.',
                    style: TextStyle(fontSize: 12, color: Colors.orange[900]),
                  ),
                ),
              ],
            ),
          ),

          // ── Mapa ────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: _pin,
                    initialZoom:   _endereco.isNotEmpty ? 16 : 5,
                    onTap: (tapPos, point) {
                      setState(() => _pin = point);
                      _reverseGeocode(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'br.com.smartyentregas',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point:  _pin,
                          width:  48,
                          height: 56,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            // Permite arrastar o pin
                            onPanUpdate: (details) {
                              // Calcula nova posição a partir do pan
                              final size = MediaQuery.of(context).size;
                              final offset = details.delta;
                              final newLat = _pin.latitude
                                  - offset.dy / (size.height * 0.6) * 0.1;
                              final newLng = _pin.longitude
                                  + offset.dx / size.width * 0.1;
                              setState(() => _pin = LatLng(newLat, newLng));
                            },
                            onPanEnd: (_) => _reverseGeocode(_pin),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE53935),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black38,
                                          blurRadius: 6,
                                          offset: Offset(0, 3))
                                    ],
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(Icons.store,
                                        color: Colors.white, size: 22),
                                  ),
                                ),
                                CustomPaint(
                                  painter: _PinTailPainter(),
                                  size: const Size(12, 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Loading overlay
                if (_buscando)
                  const Positioned(
                    top: 12, left: 0, right: 0,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFFFA726)),
                              ),
                              SizedBox(width: 10),
                              Text('Buscando...', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Barra inferior: endereço selecionado + confirmar ─
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_endereco.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on,
                          color: Color(0xFFE53935), size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _endereco,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  Text(
                    'Nenhum endereço selecionado ainda.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _endereco.isNotEmpty
                          ? Colors.green
                          : Colors.grey[400],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _endereco.isEmpty ? null : _confirmar,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      _endereco.isNotEmpty
                          ? 'Confirmar este endereço'
                          : 'Busque um endereço primeiro',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Triângulo da cauda do pin ────────────────────────────────
class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.fill;
    final path = ui.Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
