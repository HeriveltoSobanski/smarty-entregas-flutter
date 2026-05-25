import 'dart:convert';
import '../../../core/utils/app_logger.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

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
  State<SelecionarEnderecoPage> createState() => _SelecionarEnderecoPageState();
}

class _SelecionarEnderecoPageState extends State<SelecionarEnderecoPage> {
  MapboxMap? _map;
  CircleAnnotationManager? _circleManager;
  CircleAnnotation?        _pinAnnotation;

  final _searchCtrl = TextEditingController();
  final _focusNode  = FocusNode();

  // Brasil centro como default
  Position _pin     = Position(-47.93, -15.78);
  String   _endereco = '';
  bool     _buscando    = false;
  bool     _pegandoGps  = false;
  String   _erro        = '';

  @override
  void initState() {
    super.initState();
    if (widget.latInicial != null && widget.lngInicial != null) {
      _pin = Position(widget.lngInicial!, widget.latInicial!);
    }
    if (widget.enderecoInicial != null && widget.enderecoInicial!.isNotEmpty) {
      _endereco = widget.enderecoInicial!;
      _searchCtrl.text = widget.enderecoInicial!;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    _circleManager = await map.annotations.createCircleAnnotationManager();

    // Tap no mapa move o pin
    map.setOnMapTapListener((coordinate) {
      _moverPin(coordinate.point.coordinates);
      _reverseGeocode(coordinate.point.coordinates);
    });

    final zoom = _endereco.isNotEmpty ? 15.0 : 5.0;
    await map.setCamera(CameraOptions(
      center: Point(coordinates: _pin),
      zoom: zoom,
    ));

    await _renderizarPin();
  }

  Future<void> _renderizarPin() async {
    if (_circleManager == null) return;
    await _circleManager!.deleteAll();
    _pinAnnotation = await _circleManager!.create(CircleAnnotationOptions(
      geometry:          Point(coordinates: _pin),
      circleRadius:      12.0,
      circleColor:       const Color(0xFFE53935).toARGB32(),
      circleStrokeWidth: 2.5,
      circleStrokeColor: Colors.white.toARGB32(),
    ));
  }

  Future<void> _moverPin(Position pos) async {
    setState(() => _pin = pos);
    if (_pinAnnotation != null && _circleManager != null) {
      _pinAnnotation!.geometry = Point(coordinates: pos);
      await _circleManager!.update(_pinAnnotation!);
    }
  }

  // ── Localização atual via GPS ─────────────────────────────────
  Future<void> _usarLocalizacaoAtual() async {
    setState(() { _pegandoGps = true; _erro = ''; });

    try {
      geo.LocationPermission permissao = await geo.Geolocator.checkPermission();
      if (permissao == geo.LocationPermission.denied) {
        permissao = await geo.Geolocator.requestPermission();
      }

      if (permissao == geo.LocationPermission.denied ||
          permissao == geo.LocationPermission.deniedForever) {
        setState(() {
          _erro = permissao == geo.LocationPermission.deniedForever
              ? 'Permissão negada permanentemente. Habilite nas configurações do celular.'
              : 'Permissão de localização negada.';
        });
        return;
      }

      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final mapPos = Position(pos.longitude, pos.latitude);
      await _moverPin(mapPos);
      await _reverseGeocode(mapPos);

      await _map?.flyTo(
        CameraOptions(center: Point(coordinates: mapPos), zoom: 16.0),
        MapAnimationOptions(duration: 600),
      );
    } catch (e, st) {
      AppLogger.e('SelecionarEndereco.GPS', e, st);
      setState(() => _erro = 'Não foi possível obter a localização.');
    } finally {
      setState(() => _pegandoGps = false);
    }
  }

  // ── Geocodificação direta (endereço → coord) ──────────────────
  Future<void> _buscar() async {
    final texto = _searchCtrl.text.trim();
    if (texto.isEmpty) return;
    _focusNode.unfocus();
    setState(() { _buscando = true; _erro = ''; });

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(texto)}'
      '&format=json&limit=1&countrycodes=br',
    );

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

          final pos = Position(lon, lat);
          await _moverPin(pos);
          setState(() => _endereco = _simplificarEndereco(displayName));

          await _map?.flyTo(
            CameraOptions(center: Point(coordinates: pos), zoom: 15.0),
            MapAnimationOptions(duration: 500),
          );
        } else {
          setState(() => _erro = 'Endereço não encontrado. Tente ser mais específico.');
        }
      }
    } catch (e, st) {
      AppLogger.e('SelecionarEndereco', e, st);
      setState(() => _erro = 'Erro ao buscar. Verifique a conexão.');
    }

    setState(() => _buscando = false);
  }

  // ── Geocodificação reversa (coord → endereço) ─────────────────
  Future<void> _reverseGeocode(Position pos) async {
    setState(() { _buscando = true; _erro = ''; });

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?format=json&lat=${pos.lat}&lon=${pos.lng}'
      '&countrycodes=br',
    );

    try {
      final resp = await http.get(url, headers: {
        'User-Agent': 'SmartyEntregas/1.0',
        'Accept-Language': 'pt-BR',
      });

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final enderecoFmt = _formatarDoReverse(data);
        final displayName = data['display_name']?.toString() ?? '';
        setState(() {
          _endereco = enderecoFmt.isNotEmpty ? enderecoFmt : displayName;
          _searchCtrl.text = _endereco;
        });
      }
    } catch (e, st) {
      AppLogger.e('SelecionarEndereco', e, st);
    }

    setState(() => _buscando = false);
  }

  String _formatarDoReverse(Map<String, dynamic> data) {
    final addr = data['address'] as Map<String, dynamic>? ?? {};
    final partes = <String>[];
    final rua    = addr['road']?.toString() ?? addr['pedestrian']?.toString() ?? '';
    final numero = addr['house_number']?.toString() ?? '';
    final bairro = addr['suburb']?.toString() ?? addr['neighbourhood']?.toString() ?? '';
    final cidade = addr['city']?.toString() ?? addr['town']?.toString() ?? addr['village']?.toString() ?? '';
    final estado = addr['state']?.toString() ?? '';
    if (rua.isNotEmpty)    partes.add(numero.isNotEmpty ? '$rua, $numero' : rua);
    if (bairro.isNotEmpty) partes.add(bairro);
    if (cidade.isNotEmpty) partes.add(cidade);
    if (estado.isNotEmpty) partes.add(estado);
    return partes.join(' - ');
  }

  String _simplificarEndereco(String displayName) {
    final partes = displayName.split(', ');
    final filtradas = partes
        .where((p) => p != 'Brasil' && !RegExp(r'^\d{5}-\d{3}$').hasMatch(p))
        .toList();
    return filtradas.length > 5
        ? filtradas.sublist(0, 5).join(', ')
        : filtradas.join(', ');
  }

  void _confirmar() {
    if (_endereco.isEmpty) {
      setState(() => _erro = 'Busque um endereço antes de confirmar.');
      return;
    }
    Navigator.pop(
      context,
      EnderecoSelecionado(
        endereco: _endereco,
        lat:      _pin.lat.toDouble(),
        lng:      _pin.lng.toDouble(),
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
          // ── Barra de busca ──────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller:      _searchCtrl,
                        focusNode:       _focusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted:     (_) => _buscar(),
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
                        onPressed: _buscando || _pegandoGps ? null : _buscar,
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
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      width: 44,
                      child: ElevatedButton(
                        onPressed: _buscando || _pegandoGps ? null : _usarLocalizacaoAtual,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.zero,
                        ),
                        child: _pegandoGps
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.my_location, size: 20),
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

          // ── Instrução ───────────────────────────────────────────
          Container(
            color: const Color(0xFFFFF3E0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.touch_app, size: 16, color: Color(0xFFE65100)),
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

          // ── Mapa ────────────────────────────────────────────────
          Expanded(
            child: MapWidget(
              styleUri: MapboxStyles.MAPBOX_STREETS,
              onMapCreated: _onMapCreated,
            ),
          ),

          // ── Barra inferior ──────────────────────────────────────
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
                        child: Text(_endereco,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  Text('Nenhum endereço selecionado ainda.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
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
