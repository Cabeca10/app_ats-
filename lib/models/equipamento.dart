/// Modelo de Equipamento que espelha com exatidão a tabela 'equipamentos'
/// do Supabase com projeção de colunas otimizada para AppSec.
class Equipamento {
  final String id;
  final String modelo;
  final String fabricante;
  final String numeroSerie;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Projeção estrita de colunas para tráfego de rede otimizado (Princípio de Minimização de Dados)
  static const String selectColumns = 'id, modelo, fabricante, numero_serie, created_at, updated_at';

  Equipamento({
    required this.id,
    required this.modelo,
    required this.fabricante,
    required this.numeroSerie,
    this.createdAt,
    this.updatedAt,
  });

  factory Equipamento.fromJson(Map<String, dynamic> json) {
    return Equipamento(
      id: json['id']?.toString() ?? '',
      modelo: json['modelo']?.toString() ?? '',
      fabricante: json['fabricante']?.toString() ?? '',
      numeroSerie: json['numero_serie']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'modelo': modelo,
      'fabricante': fabricante,
      'numero_serie': numeroSerie,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Equipamento copyWith({
    String? id,
    String? modelo,
    String? fabricante,
    String? numeroSerie,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Equipamento(
      id: id ?? this.id,
      modelo: modelo ?? this.modelo,
      fabricante: fabricante ?? this.fabricante,
      numeroSerie: numeroSerie ?? this.numeroSerie,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
