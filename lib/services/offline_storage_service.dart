import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/ats_documentacao.dart';

/// Serviço de armazenamento local offline-first utilizando Hive.
/// Garante que todos os dados de atendimentos e logs técnicos
/// sejam persistidos localmente antes de qualquer tentativa de envio de rede.
class OfflineStorageService {
  static final OfflineStorageService instance = OfflineStorageService._internal();
  OfflineStorageService._internal();

  static const String boxName = 'ats_offline_data';
  Box? _box;

  /// Inicializa o Hive e abre o Box de persistência offline
  Future<void> init() async {
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox(boxName);
      debugPrint('[OfflineStorage] Hive inicializado com sucesso. Box: $boxName');
    } catch (e) {
      debugPrint('[OfflineStorage] Erro ao inicializar Hive: $e');
    }
  }

  Box get box {
    if (_box == null || !_box!.isOpen) {
      throw StateError('OfflineStorageService não inicializado. Chame init() previamente.');
    }
    return _box!;
  }

  /// Limpa todos os dados armazenados localmente no Hive
  Future<void> limparTudo() async {
    try {
      await box.clear();
      debugPrint('[OfflineStorage] Cache local limpo com sucesso.');
    } catch (e) {
      debugPrint('[OfflineStorage] Erro ao limpar cache Hive: $e');
    }
  }

  /// Salva ou atualiza um atendimento localmente com a flag de sincronização
  Future<void> salvarAtendimentoLocal({
    required String id,
    required Map<String, dynamic> dados,
    bool pendingSync = true,
  }) async {
    final payload = Map<String, dynamic>.from(dados);
    payload['id'] = id;
    payload['pending_sync'] = pendingSync;
    payload['local_saved_at'] = DateTime.now().toIso8601String();

    await box.put(id, payload);
    debugPrint('[OfflineStorage] Atendimento $id salvo localmente. pending_sync: $pendingSync');
  }

  /// Recupera um atendimento armazenado localmente
  Map<String, dynamic>? obterAtendimento(String id) {
    final data = box.get(id);
    if (data != null && data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// Retorna todos os atendimentos marcados com pending_sync = true
  List<Map<String, dynamic>> obterPendentes() {
    final pendentes = <Map<String, dynamic>>[];
    for (var key in box.keys) {
      final item = box.get(key);
      if (item is Map && item['pending_sync'] == true) {
        pendentes.add(Map<String, dynamic>.from(item));
      }
    }
    return pendentes;
  }

  /// Marca um atendimento como sincronizado no Supabase
  Future<void> marcarSincronizado(String id) async {
    final item = obterAtendimento(id);
    if (item != null) {
      item['pending_sync'] = false;
      item['synced_at'] = DateTime.now().toIso8601String();
      await box.put(id, item);
      debugPrint('[OfflineStorage] Atendimento $id marcado como sincronizado.');
    }
  }

  /// Remove registro do armazenamento local
  Future<void> remover(String id) async {
    await box.delete(id);
  }

  /// Salva a lista de chamados atribuídos ao técnico em cache local
  Future<void> salvarChamadosTecnicoCache(List<Map<String, dynamic>> chamados) async {
    await box.put('cached_tecnico_chamados', chamados);
    debugPrint('[OfflineStorage] ${chamados.length} chamados do técnico salvos no cache local do Hive.');
  }

  /// Recupera a lista em cache local dos chamados do técnico (para uso offline no chão de fábrica)
  List<Map<String, dynamic>> obterChamadosTecnicoCache() {
    final cached = box.get('cached_tecnico_chamados');
    if (cached != null && cached is List) {
      return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Salva as anotações e fotos de documentação do chamado localmente no Hive
  Future<void> salvarDocumentacaoLocal(AtsDocumentacao doc) async {
    await box.put('doc_${doc.chamadoId}', doc.toMap());
    debugPrint('[OfflineStorage] Documentação do chamado ${doc.chamadoId} salva localmente.');
  }

  /// Recupera as anotações e fotos de documentação do chamado do cache local do Hive
  AtsDocumentacao? obterDocumentacaoLocal(String chamadoId) {
    final data = box.get('doc_$chamadoId');
    if (data != null && data is Map) {
      return AtsDocumentacao.fromMap(Map<String, dynamic>.from(data));
    }
    return null;
  }

  /// Salva lista de técnicos cadastrados no cache do Hive
  Future<void> salvarTecnicosCache(List<Map<String, dynamic>> tecnicos) async {
    await box.put('cached_equipe_tecnicos', tecnicos);
    debugPrint('[OfflineStorage] ${tecnicos.length} técnicos salvos no cache local.');
  }

  /// Recupera a lista de técnicos do cache local do Hive
  List<Map<String, dynamic>> obterTecnicosCache() {
    final cached = box.get('cached_equipe_tecnicos');
    if (cached != null && cached is List) {
      return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }
}
