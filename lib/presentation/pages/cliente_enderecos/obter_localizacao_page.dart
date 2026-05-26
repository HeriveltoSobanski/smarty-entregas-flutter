import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/utils/app_logger.dart';
import '../selecionar_endereco/selecionar_endereco_page.dart';

const Color _cor = Color(0xFFF5841F);

class ObterLocalizacaoPage extends StatefulWidget {
  const ObterLocalizacaoPage({super.key});

  @override
  State<ObterLocalizacaoPage> createState() => _ObterLocalizacaoPageState();
}

class _ObterLocalizacaoPageState extends State<ObterLocalizacaoPage>
    with SingleTickerProviderStateMixin {
  bool _carregando = false;
  String _erro = '';
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _obterLocalizacao() async {
    setState(() {
      _carregando = true;
      _erro = '';
    });

    try {
      geo.LocationPermission permissao = await geo.Geolocator.checkPermission();
      if (permissao == geo.LocationPermission.denied) {
        permissao = await geo.Geolocator.requestPermission();
      }

      if (permissao == geo.LocationPermission.denied) {
        setState(() {
          _erro = 'Permissão de localização negada. Toque novamente para tentar.';
          _carregando = false;
        });
        return;
      }

      if (permissao == geo.LocationPermission.deniedForever) {
        setState(() {
          _erro =
              'Permissão negada permanentemente. Habilite a localização nas configurações do celular.';
          _carregando = false;
        });
        return;
      }

      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final endereco = await _reverseGeocode(pos.latitude, pos.longitude);
      if (!mounted) return;

      Navigator.pop(
        context,
        EnderecoSelecionado(
          endereco: endereco,
          lat: pos.latitude,
          lng: pos.longitude,
        ),
      );
    } catch (e, st) {
      AppLogger.e('ObterLocalizacao', e, st);
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível obter a localização. Tente novamente.';
          _carregando = false;
        });
      }
    }
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&countrycodes=br',
      );
      final resp = await http.get(url, headers: {
        'User-Agent': 'SmartyEntregas/1.0',
        'Accept-Language': 'pt-BR',
      });
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return _formatarEndereco(data);
      }
    } catch (e, st) {
      AppLogger.e('ObterLocalizacao.reverse', e, st);
    }
    return 'Lat: $lat, Lng: $lng';
  }

  String _formatarEndereco(Map<String, dynamic> data) {
    final addr = data['address'] as Map<String, dynamic>? ?? {};
    final partes = <String>[];
    final rua = addr['road']?.toString() ?? addr['pedestrian']?.toString() ?? '';
    final numero = addr['house_number']?.toString() ?? '';
    final bairro =
        addr['suburb']?.toString() ?? addr['neighbourhood']?.toString() ?? '';
    final cidade = addr['city']?.toString() ??
        addr['town']?.toString() ??
        addr['village']?.toString() ??
        '';
    final estado = addr['state']?.toString() ?? '';
    if (rua.isNotEmpty) partes.add(numero.isNotEmpty ? '$rua, $numero' : rua);
    if (bairro.isNotEmpty) partes.add(bairro);
    if (cidade.isNotEmpty) partes.add(cidade);
    if (estado.isNotEmpty) partes.add(estado);
    if (partes.isNotEmpty) return partes.join(' - ');
    return data['display_name']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _cor,
        foregroundColor: Colors.white,
        title: const Text(
          'Novo Endereço',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Ícone animado
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: _cor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: _cor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        size: 52,
                        color: _cor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Usar minha localização',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Vamos detectar automaticamente onde você está para salvar seu endereço com precisão.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: _cor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'O app pedirá permissão para acessar a localização do seu dispositivo.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[900],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_erro.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _erro,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  onPressed: _carregando ? null : _obterLocalizacao,
                  icon: _carregando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Icon(Icons.my_location_rounded, size: 22),
                  label: Text(
                    _carregando
                        ? 'Obtendo localização...'
                        : 'Obter minha localização atual',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
