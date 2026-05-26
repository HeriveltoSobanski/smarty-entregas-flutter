import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../presentation/navigation/app_routes.dart';
import '../../../services/api_service.dart';
import '../acompanhamento_pedido/acompanhamento_pedido_page.dart';

const Color _cor = Color(0xFFFFA726);

class PagamentoPixPage extends StatefulWidget {
  final int    idPedido;
  final int    idEmpresa;
  final String nomeEmpresa;
  final String enderecoEntrega;
  final String qrCodePix;
  final String qrCodeBase64;
  final String idPagamentoMp;
  final double valorTotal;

  const PagamentoPixPage({
    super.key,
    required this.idPedido,
    required this.idEmpresa,
    required this.nomeEmpresa,
    required this.enderecoEntrega,
    required this.qrCodePix,
    required this.qrCodeBase64,
    required this.idPagamentoMp,
    required this.valorTotal,
  });

  @override
  State<PagamentoPixPage> createState() => _PagamentoPixPageState();
}

class _PagamentoPixPageState extends State<PagamentoPixPage> {
  Timer?  _timer;
  String  _status = 'pending';
  bool    _copiado = false;

  @override
  void initState() {
    super.initState();
    _iniciarPolling();
  }

  void _iniciarPolling() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final result = await ApiService.consultarPagamentoPedido(widget.idPedido);
      if (!mounted) return;
      final status = result['status_pagamento']?.toString() ?? 'pending';
      setState(() => _status = status);

      if (status == 'approved') {
        _timer?.cancel();
        _navegarParaAcompanhamento();
      } else if (status == 'rejected' || status == 'cancelled') {
        _timer?.cancel();
      }
    });
  }

  void _navegarParaAcompanhamento() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AcompanhamentoPedidoPage(
          idPedido:        widget.idPedido,
          idEmpresa:       widget.idEmpresa,
          nomeEmpresa:     widget.nomeEmpresa,
          enderecoEntrega: widget.enderecoEntrega,
        ),
      ),
    );
  }

  void _copiarCodigo() {
    Clipboard.setData(ClipboardData(text: widget.qrCodePix));
    setState(() => _copiado = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copiado = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pago      = _status == 'approved';
    final rejeitado = _status == 'rejected' || _status == 'cancelled';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _cor,
        title: const Text('Pagar com PIX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Status banner
            if (pago)
              _banner(Icons.check_circle_rounded, 'Pagamento confirmado!', Colors.green)
            else if (rejeitado)
              _banner(Icons.cancel_rounded, 'Pagamento não aprovado', Colors.red)
            else
              _banner(Icons.hourglass_top_rounded, 'Aguardando pagamento...', Colors.orange),

            const SizedBox(height: 24),

            // QR Code
            if (!pago) ...[
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'R\$ ${widget.valorTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _cor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Pedido #${widget.idPedido}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      const SizedBox(height: 20),
                      QrImageView(
                        data: widget.qrCodePix,
                        version: QrVersions.auto,
                        size: 220,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Escaneie com o app do seu banco',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Copiar código
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PIX Copia e Cola',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          widget.qrCodePix,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _copiado ? Colors.green : _cor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _copiarCodigo,
                          icon: Icon(_copiado ? Icons.check : Icons.copy, size: 18),
                          label: Text(_copiado ? 'Copiado!' : 'Copiar código PIX'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Instruções
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Como pagar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _instrucao('1', 'Abra o app do seu banco'),
                      _instrucao('2', 'Escolha pagar via PIX'),
                      _instrucao('3', 'Escaneie o QR Code ou cole o código'),
                      _instrucao('4', 'Confirme o pagamento'),
                      _instrucao('5', 'Aguarde a confirmação automática aqui'),
                    ],
                  ),
                ),
              ),
            ],

            if (pago) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _navegarParaAcompanhamento,
                  icon: const Icon(Icons.delivery_dining),
                  label: const Text('Acompanhar pedido',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],

            if (rejeitado) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
                  child: const Text('Voltar ao início'),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _banner(IconData icon, String texto, Color cor) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(icon, color: cor, size: 24),
          const SizedBox(width: 10),
          Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
      );

  Widget _instrucao(String num, String texto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: _cor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(num, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _cor)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13))),
        ]),
      );
}
