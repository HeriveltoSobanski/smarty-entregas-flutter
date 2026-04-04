class Pedido {
  final String id;
  final String cliente;
  final List<String> itens;
  final double valor;
  final DateTime data;
  final String status; // 'Entregue', 'Em andamento', 'Cancelado'

  Pedido({
    required this.id,
    required this.cliente,
    required this.itens,
    required this.valor,
    required this.data,
    required this.status,
  });
}

class PedidoStore {
  static final List<Pedido> _pedidos = [
    Pedido(
      id: '#001',
      cliente: 'Maria Silva',
      itens: ['X-Burger', 'Coca-Cola 350ml'],
      valor: 32.50,
      data: DateTime.now().subtract(const Duration(hours: 2)),
      status: 'Entregue',
    ),
    Pedido(
      id: '#002',
      cliente: 'João Santos',
      itens: ['Pizza Calabresa', 'Suco de Laranja'],
      valor: 55.00,
      data: DateTime.now().subtract(const Duration(hours: 5)),
      status: 'Entregue',
    ),
    Pedido(
      id: '#003',
      cliente: 'Ana Costa',
      itens: ['Feijoada', 'Refrigerante'],
      valor: 38.90,
      data: DateTime.now().subtract(const Duration(days: 1)),
      status: 'Entregue',
    ),
    Pedido(
      id: '#004',
      cliente: 'Pedro Lima',
      itens: ['X-Bacon', 'Batata Frita'],
      valor: 28.00,
      data: DateTime.now().subtract(const Duration(days: 2)),
      status: 'Cancelado',
    ),
    Pedido(
      id: '#005',
      cliente: 'Carla Nunes',
      itens: ['Sorvete de Chocolate', 'Água Mineral'],
      valor: 19.90,
      data: DateTime.now().subtract(const Duration(days: 3)),
      status: 'Entregue',
    ),
    Pedido(
      id: '#006',
      cliente: 'Lucas Ferreira',
      itens: ['Parmegiana de Frango', 'Suco de Maracujá'],
      valor: 42.50,
      data: DateTime.now().subtract(const Duration(days: 5)),
      status: 'Entregue',
    ),
    Pedido(
      id: '#007',
      cliente: 'Fernanda Souza',
      itens: ['Pizza Mussarela', 'Coca-Cola 2L'],
      valor: 65.00,
      data: DateTime.now().subtract(const Duration(days: 7)),
      status: 'Entregue',
    ),
  ];

  static List<Pedido> get todos => List.unmodifiable(_pedidos);

  static List<Pedido> porPeriodo(DateTime inicio, DateTime fim) {
    final inicioNorm = DateTime(inicio.year, inicio.month, inicio.day);
    final fimNorm = DateTime(fim.year, fim.month, fim.day, 23, 59, 59);
    return _pedidos
        .where((p) =>
            p.data.isAfter(inicioNorm.subtract(const Duration(seconds: 1))) &&
            p.data.isBefore(fimNorm.add(const Duration(seconds: 1))))
        .toList();
  }

  static double totalPeriodo(DateTime inicio, DateTime fim) =>
      porPeriodo(inicio, fim)
          .where((p) => p.status != 'Cancelado')
          .fold(0.0, (sum, p) => sum + p.valor);

  static double totalGeral() => _pedidos
      .where((p) => p.status != 'Cancelado')
      .fold(0.0, (sum, p) => sum + p.valor);
}
