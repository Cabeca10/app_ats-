import 'package:uuid/uuid.dart';

/// Modelo para anotações e fotos de campo do atendimento técnico
class AtsDocumentacao {
  final String id;
  final String chamadoId;
  final String anotacoesCampo;
  final List<String> fotosUrls;
  final List<String> localFotosPaths;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pendingSync;

  AtsDocumentacao({
    String? id,
    required this.chamadoId,
    this.anotacoesCampo = '',
    this.fotosUrls = const [],
    this.localFotosPaths = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.pendingSync = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  AtsDocumentacao copyWith({
    String? id,
    String? chamadoId,
    String? anotacoesCampo,
    List<String>? fotosUrls,
    List<String>? localFotosPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? pendingSync,
  }) {
    return AtsDocumentacao(
      id: id ?? this.id,
      chamadoId: chamadoId ?? this.chamadoId,
      anotacoesCampo: anotacoesCampo ?? this.anotacoesCampo,
      fotosUrls: fotosUrls ?? this.fotosUrls,
      localFotosPaths: localFotosPaths ?? this.localFotosPaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chamado_id': chamadoId,
      'anotacoes_campo': anotacoesCampo,
      'fotos_urls': fotosUrls,
      'local_fotos_paths': localFotosPaths,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'pending_sync': pendingSync,
    };
  }

  /// Mapa estrito para envio ao banco PostgreSQL Supabase
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'chamado_id': chamadoId,
      'anotacoes_campo': anotacoesCampo,
      'fotos_urls': fotosUrls,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AtsDocumentacao.fromMap(Map<String, dynamic> map) {
    return AtsDocumentacao(
      id: map['id']?.toString(),
      chamadoId: map['chamado_id']?.toString() ?? '',
      anotacoesCampo: map['anotacoes_campo']?.toString() ?? '',
      fotosUrls: (map['fotos_urls'] as List?)?.map((e) => e.toString()).toList() ?? [],
      localFotosPaths: (map['local_fotos_paths'] as List?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      pendingSync: map['pending_sync'] == true,
    );
  }
}
