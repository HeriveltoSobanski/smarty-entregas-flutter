import 'dart:convert';
import '../../../core/utils/app_logger.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/api_service.dart';

class MapaEntregaPage extends StatefulWidget {
  final String enderecoOrigem;
  final String enderecoDestino;
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
  MapboxMap? _map;
  PolylineAnnotationManager? _polylineManager;
  CircleAnnotationManager?   _circleManager;

  Position? _origem;
  Position? _destino;

  bool   _carregando  = true;
  String _erro        = '';
  double _distanciaKm = 0;
  int    _duracaoMin  = 0;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    setState(() { _carregando = true; _erro = ''; });
    try {
      final results = await Future.wait([
        _geocodificar(widget.enderecoOrigem),
        _geocodificar(widget.enderecoDestino),
      ]);

      final origem  = results[0];
      final destino = results[1];

      if (origem == null) {
        setState(() {
          _erro = 'Não foi possível encontrar o endereço da empresa:\n"${widget.enderecoOrigem}"';
          _carregando = false;
        });
        return;
      }
      if (destino == null) {
        setState(() {
          _erro = 'Não foi possível encontrar o endereço de entrega:\n"${widget.enderecoDestino}"';
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
      setState(() { _erro = 'Erro ao carregar mapa.'; _carregando = false; });
    }
  }

  Future<Position?> _geocodificar(String endereco) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(endereco)}'
      '&format=json&limit=1&countrycodes=br',
    );
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
    return Position(lon, lat);
  }

  Future<void> _calcularRota(Position origem, Position destino) async {
    try {
      final data = await ApiService.getRota(
        origemLat: origem.lat.toDouble(),
        origemLng: origem.lng.toDouble(),
        destLat:   destino.lat.toDouble(),
        destLng:   destino.lng.toDouble(),
      );

      if (data != null) {
        final routes = (data['routes'] as List?) ?? [];
        if (routes.isNotEmpty) {
          final route    = routes.first as Map<String, dynamic>;
          final geometry = route['geometry'] as Map<String, dynamic>;
          final coords   = geometry['coordinates'] as List;

          final pontos = coords
              .map((c) {
                final arr = c as List;
                return Position(
                  (arr[0] as num).toDouble(),
                  (arr[1] as num).toDouble(),
                );
              })
              .toList();

          setState(() {
            _distanciaKm = ((route['distance'] as num?)?.toDouble() ?? 0) / 1000;
            _duracaoMin  = (((route['duration'] as num?)?.toDouble() ?? 0) / 60).round();
          });

          if (_map != null) await _desenharRota(pontos);
        }
      }
    } catch (e, st) {
      AppLogger.e('MapaEntrega', e, st);
    }

    setState(() => _carregando = false);
    if (_map != null) await _ajustarCamara();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    _polylineManager = await map.annotations.createPolylineAnnotationManager();
    _circleManager   = await map.annotations.createCircleAnnotationManager();

    // Câmera inicial enquanto geocodificação ainda está rodando
    if (_origem != null) {
      await map.setCamera(CameraOptions(
        center: Point(coordinates: _origem!),
        zoom: 13.0,
      ));
    }

    if (_origem != null && _destino != null && !_carregando) {
      await _ajustarCamara();
    }
  }

  Future<void> _desenharRota(List<Position> pontos) async {
    await _polylineManager?.deleteAll();
    await _circleManager?.deleteAll();

    if (pontos.isNotEmpty) {
      await _polylineManager?.create(PolylineAnnotationOptions(
        geometry: LineString(coordinates: pontos),
        lineColor: const Color(0xFF1565C0).toARGB32(),
        lineWidth:  4.5,
      ));
    }

    if (_origem != null) {
      await _circleManager?.create(CircleAnnotationOptions(
        geometry: Point(coordinates: _origem!),
        circleRadius:      10.0,
        circleColor:       Colors.red.toARGB32(),
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.toARGB32(),
      ));
    }
    if (_destino != null) {
      await _circleManager?.create(CircleAnnotationOptions(
        geometry: Point(coordinates: _destino!),
        circleRadius:      10.0,
        circleColor:       Colors.green.toARGB32(),
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.toARGB32(),
      ));
    }
  }

  Future<void> _ajustarCamara() async {
    if (_map == null || _origem == null || _destino == null) return;

    final bounds = CoordinateBounds(
      southwest: Point(coordinates: Position(
        _origem!.lng < _destino!.lng ? _origem!.lng.toDouble() : _destino!.lng.toDouble(),
        _origem!.lat < _destino!.lat ? _origem!.lat.toDouble() : _destino!.lat.toDouble(),
      )),
      northeast: Point(coordinates: Position(
        _origem!.lng > _destino!.lng ? _origem!.lng.toDouble() : _destino!.lng.toDouble(),
        _origem!.lat > _destino!.lat ? _origem!.lat.toDouble() : _destino!.lat.toDouble(),
      )),
      infiniteBounds: false,
    );

    final camera = await _map!.cameraForCoordinateBounds(
      bounds,
      MbxEdgeInsets(top: 80, left: 60, bottom: 80, right: 60),
      null, null, null, null,
    );
    await _map!.flyTo(camera, MapAnimationOptions(duration: 600));
  }

  Future<void> _abrirNavegacao() async {
    if (_origem == null || _destino == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${_origem!.lat},${_origem!.lng}'
      '&destination=${_destino!.lat},${_destino!.lng}'
      '&travelmode=driving',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      final fallback = Uri.parse(
        'geo:${_destino!.lat},${_destino!.lng}'
        '?q=${Uri.encodeComponent(widget.enderecoDestino)}',
      );
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
                Expanded(child: _infoItem(
                    Icons.store_outlined, widget.nomeEmpresa, Colors.red[700]!)),
                const SizedBox(width: 8),
                Container(width: 1, height: 36, color: Colors.grey[300]),
                const SizedBox(width: 8),
                Expanded(child: _infoItem(
                    Icons.location_on_outlined,
                    widget.enderecoDestino,
                    Colors.green[700]!)),
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
            child: MapWidget(
              styleUri: MapboxStyles.MAPBOX_STREETS,
              onMapCreated: _onMapCreated,
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
}
