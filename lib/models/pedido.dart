class ItemPedido {
  final int idProduto;
  final String nome;
  final int quantidade;
  final double preco;
  final String? observacao;

  const ItemPedido({
    required this.idProduto,
    required this.nome,
    required this.quantidade,
    required this.preco,
    this.observacao,
  });

  factory ItemPedido.fromJson(Map<String, dynamic> json) => ItemPedido(
        idProduto: json['id_produto'] as int? ?? 0,
        nome: json['nome']?.toString() ?? '',
        quantidade: json['quantidade'] as int? ?? 1,
        preco: (json['preco'] as num?)?.toDouble() ?? 0.0,
        observacao: json['observacao']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id_produto': idProduto,
        'nome': nome,
        'quantidade': quantidade,
        'preco': preco,
        if (observacao != null) 'observacao': observacao,
      };
}

class Pedido {
  final int id;
  final String cliente;
  final String status;
  final double total;
  final String? enderecoEntrega;
  final String? observacao;
  final String? tipoEntrega;
  final bool quasePronto;
  final int? idMotoboy;
  final List<ItemPedido> itens;

  const Pedido({
    required this.id,
    required this.cliente,
    required this.status,
    required this.total,
    this.enderecoEntrega,
    this.observacao,
    this.tipoEntrega,
    this.quasePronto = false,
    this.idMotoboy,
    this.itens = const [],
  });

  factory Pedido.fromJson(Map<String, dynamic> json) {
    final itensRaw = json['itens'];
    final itensList = itensRaw is List
        ? itensRaw
            .map((e) => ItemPedido.fromJson(e as Map<String, dynamic>))
            .toList()
        : <ItemPedido>[];

    return Pedido(
      id: json['id_pedido'] as int? ?? 0,
      cliente: json['cliente']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      enderecoEntrega: json['endereco_entrega']?.toString(),
      observacao: json['observacao']?.toString(),
      tipoEntrega: json['tipo_entrega']?.toString(),
      quasePronto: json['quase_pronto'] as bool? ?? false,
      idMotoboy: json['id_motoboy'] as int?,
      itens: itensList,
    );
  }
}
