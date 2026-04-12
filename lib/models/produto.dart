class Adicional {
  final int id;
  final String grupo;
  final int maximoGrupo;
  final bool obrigatorio;
  final String nome;
  final String descricao;
  final double preco;
  final bool ativo;

  const Adicional({
    required this.id,
    required this.grupo,
    required this.maximoGrupo,
    required this.obrigatorio,
    required this.nome,
    required this.descricao,
    required this.preco,
    this.ativo = true,
  });

  factory Adicional.fromJson(Map<String, dynamic> json) => Adicional(
        id: json['id_adicional'] as int? ?? 0,
        grupo: json['grupo']?.toString() ?? 'Adicionais',
        maximoGrupo: json['maximo_grupo'] as int? ?? 1,
        obrigatorio: json['obrigatorio'] as bool? ?? false,
        nome: json['nome']?.toString() ?? '',
        descricao: json['descricao']?.toString() ?? '',
        preco: (json['preco'] as num?)?.toDouble() ?? 0.0,
        ativo: json['ativo'] as bool? ?? true,
      );
}

class Produto {
  final int id;
  final int idEmpresa;
  final int idCategoria;
  final String nome;
  final String descricao;
  final double preco;
  final String? imagem;
  final bool ativo;

  const Produto({
    required this.id,
    required this.idEmpresa,
    required this.idCategoria,
    required this.nome,
    required this.descricao,
    required this.preco,
    this.imagem,
    this.ativo = true,
  });

  factory Produto.fromJson(Map<String, dynamic> json) => Produto(
        id: json['id_produto'] as int? ?? 0,
        idEmpresa: json['id_empresa'] as int? ?? 0,
        idCategoria: json['id_categoria'] as int? ?? 0,
        nome: json['nome']?.toString() ?? '',
        descricao: json['descricao']?.toString() ?? '',
        preco: (json['preco'] as num?)?.toDouble() ?? 0.0,
        imagem: json['imagem']?.toString(),
        ativo: json['ativo'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id_produto': id,
        'id_empresa': idEmpresa,
        'id_categoria': idCategoria,
        'nome': nome,
        'descricao': descricao,
        'preco': preco,
        if (imagem != null) 'imagem': imagem,
        'ativo': ativo,
      };
}
