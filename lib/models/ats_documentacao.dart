import 'package:uuid/uuid.dart';

/// Item individual de registro fotográfico com anotação estilo OneNote
class FotoDocumentacaoItem {
  static const List<String> categoriasPadrao = [
    'Alarme / Falha',
    'Serviço Realizado',
    'Ajuste / Medição',
    'Peça / Painel',
  ];

  final String id;
  final String url;
  final String localPath;
  final String descricao;
  final String categoria;
  final DateTime criadoEm;

  FotoDocumentacaoItem({
    String? id,
    this.url = '',
    this.localPath = '',
    this.descricao = '',
    this.categoria = 'Serviço Realizado',
    DateTime? criadoEm,
  })  : id = id ?? const Uuid().v4(),
        criadoEm = criadoEm ?? DateTime.now();

  FotoDocumentacaoItem copyWith({
    String? id,
    String? url,
    String? localPath,
    String? descricao,
    String? categoria,
    DateTime? criadoEm,
  }) {
    return FotoDocumentacaoItem(
      id: id ?? this.id,
      url: url ?? this.url,
      localPath: localPath ?? this.localPath,
      descricao: descricao ?? this.descricao,
      categoria: categoria ?? this.categoria,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'local_path': localPath,
      'descricao': descricao,
      'categoria': categoria,
      'criado_em': criadoEm.toIso8601String(),
    };
  }

  /// Mapa persistido no PostgreSQL (sem local_path de dispositivo)
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'url': url,
      'descricao': descricao,
      'categoria': categoria,
      'criado_em': criadoEm.toIso8601String(),
    };
  }

  factory FotoDocumentacaoItem.fromMap(Map<String, dynamic> map) {
    final categoriaBruta = map['categoria']?.toString().trim() ?? '';
    return FotoDocumentacaoItem(
      id: map['id']?.toString().isNotEmpty == true ? map['id'].toString() : null,
      url: map['url']?.toString() ?? '',
      localPath: map['local_path']?.toString() ?? '',
      descricao: map['descricao']?.toString() ?? '',
      categoria: categoriaBruta.isNotEmpty ? categoriaBruta : 'Serviço Realizado',
      criadoEm: map['criado_em'] != null
          ? (DateTime.tryParse(map['criado_em'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

/// Modelo para anotações e fotos de campo do atendimento técnico
class AtsDocumentacao {
  final String id;
  final String chamadoId;
  final String anotacoesCampo;
  final List<String> fotosUrls;
  final List<String> localFotosPaths;
  final List<FotoDocumentacaoItem> itensFotos;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pendingSync;

  AtsDocumentacao({
    String? id,
    required this.chamadoId,
    this.anotacoesCampo = '',
    this.fotosUrls = const [],
    this.localFotosPaths = const [],
    this.itensFotos = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.pendingSync = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get totalFotos => itensFotos.isNotEmpty ? itensFotos.length : fotosUrls.length;
  bool get possuiConteudo => anotacoesCampo.trim().isNotEmpty || totalFotos > 0;

  AtsDocumentacao copyWith({
    String? id,
    String? chamadoId,
    String? anotacoesCampo,
    List<String>? fotosUrls,
    List<String>? localFotosPaths,
    List<FotoDocumentacaoItem>? itensFotos,
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
      itensFotos: itensFotos ?? this.itensFotos,
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
      'itens_fotos': itensFotos.map((e) => e.toMap()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'pending_sync': pendingSync,
    };
  }

  /// Mapa estrito para envio ao banco PostgreSQL Supabase
  Map<String, dynamic> toDatabaseMap() {
    final urlsParaBanco = itensFotos.isNotEmpty
        ? itensFotos.map((e) => e.url.trim()).where((u) => u.isNotEmpty).toList()
        : fotosUrls;
    return {
      'id': id,
      'chamado_id': chamadoId,
      'anotacoes_campo': anotacoesCampo,
      'fotos_urls': urlsParaBanco,
      'itens_fotos': itensFotos.map((e) => e.toDatabaseMap()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AtsDocumentacao.fromMap(Map<String, dynamic> map) {
    final parsedUrls = (map['fotos_urls'] as List?)
            ?.map((e) => e.toString())
            .where((u) => u.trim().isNotEmpty)
            .toList() ??
        [];
    final parsedLocalPaths = (map['local_fotos_paths'] as List?)
            ?.map((e) => e.toString())
            .where((p) => p.trim().isNotEmpty)
            .toList() ??
        [];

    List<FotoDocumentacaoItem> parsedItens = [];
    final rawItens = map['itens_fotos'];
    if (rawItens is List && rawItens.isNotEmpty) {
      parsedItens = rawItens
          .whereType<Map>()
          .map((e) => FotoDocumentacaoItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } else if (parsedUrls.isNotEmpty || parsedLocalPaths.isNotEmpty) {
      final count = parsedUrls.isNotEmpty ? parsedUrls.length : parsedLocalPaths.length;
      for (int i = 0; i < count; i++) {
        parsedItens.add(
          FotoDocumentacaoItem(
            url: i < parsedUrls.length ? parsedUrls[i] : '',
            localPath: i < parsedLocalPaths.length ? parsedLocalPaths[i] : '',
          ),
        );
      }
    }

    return AtsDocumentacao(
      id: map['id']?.toString(),
      chamadoId: map['chamado_id']?.toString() ?? '',
      anotacoesCampo: map['anotacoes_campo']?.toString() ?? '',
      fotosUrls: parsedUrls,
      localFotosPaths: parsedLocalPaths,
      itensFotos: parsedItens,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      pendingSync: map['pending_sync'] == true,
    );
  }
}
