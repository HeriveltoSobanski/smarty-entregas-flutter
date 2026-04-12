class EnderecoCliente {
  final int id;
  final int idUsuario;
  final String apelido;
  final String endereco;
  final double? latitude;
  final double? longitude;
  final bool principal;

  const EnderecoCliente({
    required this.id,
    required this.idUsuario,
    required this.apelido,
    required this.endereco,
    this.latitude,
    this.longitude,
    this.principal = false,
  });

  factory EnderecoCliente.fromJson(Map<String, dynamic> json) => EnderecoCliente(
        id: json['id_endereco'] as int? ?? 0,
        idUsuario: json['id_usuario'] as int? ?? 0,
        apelido: json['apelido']?.toString() ?? 'Casa',
        endereco: json['endereco']?.toString() ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        principal: json['principal'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id_endereco': id,
        'id_usuario': idUsuario,
        'apelido': apelido,
        'endereco': endereco,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'principal': principal,
      };
}
