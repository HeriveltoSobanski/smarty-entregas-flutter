import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/api_service.dart';

// =============================================================
// MapaEntregaPage — exibe rota no mapa para o motoboy
// A chave ORS fica no backend — não exposta no app.
// =============================================================
class MapaEntregaPage extends StatefulWidget {
  final String enderecoOrigem;   // endereço da empresa (origem)
  final String enderecoDestino;  // endereço de entrega (destino)
  final String nomeEmpresa;
  final int    idPedido;

  const MapaEntregaPage({
    super.key,
    required this.enderecoOrigem,
    required this.enderecoDestino,
    required this.nomeEmpresa,
    required this.idPedido,
  });

  @override
  State<MapaEntregaPage> createState() => _MapaEntregaPageState();
}

class _MapaEntregaPageState extends State<MapaEntregaPage> {
  final MapController _mapCtrl = MapController();

  LatLng? _origem;
  LatLng? _destino;
  List<LatLng> _rota = [];

  bool   _carregando   = true;
  String _erro         = '';
  double _distanciaKm  = 0;
  int    _duracaoMin   = 0;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    setState(() { _carregando = true; _erro = ''; });

    try {
      // Geocodifica os dois endereços em paralelo
      final results = await Future.wait([
        _geocodificar(widget.enderecoOrigem),
        _geocodificar(widget.enderecoDestino),
      ]);

      final origem  = results[0];
      final destino = results[1];

      if (origem == null) {
        setState(() {
          _erro = 'Não foi possível encontrar o endereço da empresa:\n'
              '"${widget.enderecoOrigem}"';
          _carregando = false;
        });
        return;
      }
      if (destino == null) {
        setState(() {
          _erro = 'Não foi possível encontrar o endereço de entrega:\n'
              '"${widget.enderecoDestino}"';
          _carregando = false;
        });
        return;
      }

      setState(() {
        _origem  = origem;
        _destino = destino;
      });

      await _calcularRota(origem, destino);
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar mapa.';
        _carregando = false;
      });
    }
  }

  // ── Geocodificação via Nominatim (OpenStreetMap, gratuito) ──
  Future<LatLng?> _geocodificar(String endereco) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(endereco)}'
        '&format=json&limit=1&countrycodes=br');

    final resp = await http.get(url, headers: {
      'User-Agent': 'SmartyEntregas/1.0 (flutter app)',
      'Accept-Language': 'pt-BR',
    });

    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as List;
    if (data.isEmpty) return null;

    final lat = double.tryParse(data[0]['lat']?.toString() ?? '');
    final lon = double.tryParse(data[0]['lon']?.toString() ?? '');
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
  }

  // ── Rota via proxy do backend (chave ORS não exposta no app) ──
  Future<void> _calcularRota(LatLng origem, LatLng destino) async {
    try {
      final data = await ApiService.getRotaORS(
        origemLat: origem.latitude,
        origemLng: origem.longitude,
        destLat: destino.latitude,
        destLng: destino.longitude,
      );

      if (data != null) {
        final features = (data['features'] as List?) ?? [];
        if (features.isNotEmpty) {
          final feature  = features.first as Map<String, dynamic>;
          final geometry = feature['geometry'] as Map<String, dynamic>;
          final coords   = geometry['coordinates'] as List;
          final props    = (feature['properties'] as Map?)
                               ?['summary'] as Map? ?? {};

          final pontos = coords.map((c) {
            final arr = c as List;
            return LatLng(
                (arr[1] as num).toDouble(), (arr[0] as num).toDouble());
          }).toList();

          setState(() {
            _rota        = pontos;
            _distanciaKm = ((props['distance'] as num?)?.toDouble() ?? 0) / 1000;
            _duracaoMin  =
                (((props['duration'] as num?)?.toDouble() ?? 0) / 60).round();
          });
        }
      }
    } catch (_) {
      // Rota falhou — exibe pins sem polyline
    }

    setState(() => _carregando = false);
    _ajustarCamara();
  }

  void _ajustarCamara() {
    if (_origem == null || _destino == null) return;
    final bounds = LatLngBounds.fromPoints([_origem!, _destino!]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapCtrl.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    });
  }

  Future<void> _abrirNavegacao() async {
    if (_origem == null || _destino == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${_origem!.latitude},${_origem!.longitude}'
        '&destination=${_destino!.latitude},${_destino!.longitude}'
        '&travelmode=driving');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      final fallback = Uri.parse(
          'geo:${_destino!.latitude},${_destino!.longitude}'
          '?q=${Uri.encodeComponent(widget.enderecoDestino)}');
      await launchUrl(fallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFA726),
        foregroundColor: Colors.white,
        title: Text('Pedido #${widget.idPedido}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _carregando
          ? _buildLoading()
          : _erro.isNotEmpty
              ? _buildErro()
              : _buildMapa(),
      floatingActionButton: (!_carregando && _erro.isEmpty && _destino != null)
          ? FloatingActionButton.extended(
              onPressed: _abrirNavegacao,
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.navigation_rounded),
              label: const Text('Navegar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildLoading() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFFA726)),
            const SizedBox(height: 20),
            Text('Calculando rota...',
                style: TextStyle(color: Colors.grey[600], fontSize: 15)),
          ],
        ),
      );

  Widget _buildErro() => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_erro,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700], fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA726),
                foregroundColor: Colors.white,
              ),
              onPressed: _inicializar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );

  Widget _buildMapa() => Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(child: _infoItem(Icons.store_outlined,
                    widget.nomeEmpresa, Colors.red[700]!)),
                const SizedBox(width: 8),
                Container(width: 1, height: 36, color: Colors.grey[300]),
                const SizedBox(width: 8),
                Expanded(child: _infoItem(Icons.location_on_outlined,
                    widget.enderecoDestino, Colors.green[700]!)),
              ],
            ),
          ),
          if (_distanciaKm > 0)
            Container(
              color: const Color(0xFFFFA726).withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.route, size: 16, color: Color(0xFFFFA726)),
                  const SizedBox(width: 6),
                  Text(
                    '${_distanciaKm.toStringAsFixed(1)} km  •  ~$_duracaoMin min',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFFE65100)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: _origem ?? const LatLng(-23.55, -46.63),
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'br.com.smartyentregas',
                ),
                if (_rota.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _rota,
                        color: Colors.blue,
                        strokeWidth: 4.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_origem != null)
                      Marker(
                        point: _origem!,
                        width: 40,
                        height: 40,
                        child: _marcador(
                            Icons.store, Colors.red[700]!, 'Restaurante'),
                      ),
                    if (_destino != null)
                      Marker(
                        point: _destino!,
                        width: 40,
                        height: 40,
                        child: _marcador(
                            Icons.location_on, Colors.green[700]!, 'Cliente'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

  Widget _infoItem(IconData icon, String texto, Color cor) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: cor),
          const SizedBox(width: 4),
          Expanded(
            child: Text(texto,
                style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );

  Widget _marcador(IconData icon, Color cor, String tooltip) => Tooltip(
        message: tooltip,
        child: Container(
          decoration: BoxDecoration(
            color: cor,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      );
}
