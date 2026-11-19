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
  static const String _selectedRoleKey = 'auth_selected_role';
  Box? _box;

  /// Retorna a caixa segura caso esteja aberta ou nula caso contrário
  Box? get boxOrNull => (_box != null && _box!.isOpen) ? _box : null;

  /// Inicializa o Hive e abre o Box de persistência offline
  Future<void> init() async {
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox(boxName);
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Hive inicializado com sucesso. Box: $boxName');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Erro ao inicializar Hive: $e');
      }
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
      if (_box != null && _box!.isOpen) {
        await _box!.clear();
      }
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Cache local limpo com sucesso.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Erro ao limpar cache Hive: $e');
      }
    }
  }

  /// Salva ou atualiza um atendimento localmente com a flag de sincronização
  Future<void> salvarAtendimentoLocal({
    required String id,
    required Map<String, dynamic> dados,
    bool pendingSync = true,
  }) async {
    try {
      final safeBox = boxOrNull ?? await Hive.openBox(boxName);
      final payload = Map<String, dynamic>.from(dados);
      payload['id'] = id;
      payload['pending_sync'] = pendingSync;
      payload['local_saved_at'] = DateTime.now().toIso8601String();

      await safeBox.put(id, payload);
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Atendimento $id salvo localmente. pending_sync: $pendingSync');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Erro ao salvar atendimento local: $e');
      }
    }
  }

  /// Recupera um atendimento armazenado localmente
  Map<String, dynamic>? obterAtendimento(String id) {
    try {
      final safeBox = boxOrNull;
      if (safeBox == null) return null;
      final data = safeBox.get(id);
      if (data != null && data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Erro ao obter atendimento $id: $e');
      }
    }
    return null;
  }

  /// Retorna todos os atendimentos marcados com pending_sync = true
  List<Map<String, dynamic>> obterPendentes() {
    final pendentes = <Map<String, dynamic>>[];
    try {
      final safeBox = boxOrNull;
      if (safeBox == null) return pendentes;
      for (var key in safeBox.keys) {
        final item = safeBox.get(key);
        if (item is Map && item['pending_sync'] == true) {
          pendentes.add(Map<String, dynamic>.from(item));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Erro ao obter pendentes: $e');
      }
    }
    return pendentes;
  }

  /// Marca um atendimento como sincronizado no Supabase
  Future<void> marcarSincronizado(String id) async {
    try {
      final safeBox = boxOrNull;
      if (safeBox == null) return;
      final item = obterAtendimento(id);
      if (item != null) {
        item['pending_sync'] = false;
        item['synced_at'] = DateTime.now().toIso8601String();
        await safeBox.put(id, item);
        if (kDebugMode) {
          debugPrint('[OfflineStorage] Atendimento $id marcado como sincronizado.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Erro ao marcar sincronizado: $e');
      }
    }
  }

  /// Remove registro do armazenamento local
  Future<void> remover(String id) async {
    try {
      final safeBox = boxOrNull;
      if (safeBox != null) {
        await safeBox.delete(id);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Erro ao remover $id: $e');
      }
    }
  }

  /// Remove completamente um chamado, suas documentações e referências do cache local do técnico
  Future<void> removerChamadoCompletamente(
    String chamadoId, {
    String? numeroAts,
  }) async {
    try {
      final safeBox = boxOrNull;
      if (safeBox == null) return;

      await safeBox.delete(chamadoId);
      await safeBox.delete('doc_$chamadoId');

      String? rawAts;
      String? cleanAts;
      if (numeroAts != null && numeroAts.trim().isNotEmpty) {
        rawAts = numeroAts.trim();
        cleanAts = rawAts.replaceAll('ATS-', '').trim();
        await safeBox.delete(rawAts);
        await safeBox.delete(cleanAts);
        await safeBox.delete('ATS-$cleanAts');
      }

      final cached = safeBox.get('cached_tecnico_chamados');
      if (cached is List) {
        final filtrada = cached.where((item) {
          if (item is! Map) return true;
          final idItem = item['id']?.toString();
          if (idItem == chamadoId) return false;
          if (cleanAts != null && cleanAts.isNotEmpty) {
            final atsItem = item['numero_ats']?.toString().trim();
            if (atsItem != null &&
                (atsItem == rawAts ||
                    atsItem == cleanAts ||
                    atsItem.replaceAll('ATS-', '').trim() == cleanAts)) {
              return false;
            }
          }
          return true;
        }).toList();
        await safeBox.put('cached_tecnico_chamados', filtrada);
      }

      if (kDebugMode) {
        debugPrint('[OfflineStorage] Chamado $chamadoId removido completamente do cache Hive.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Erro ao remover chamado completamente ($chamadoId): $e');
      }
    }
  }

  /// Salva a lista de chamados atribuídos ao técnico em cache local
  Future<void> salvarChamadosTecnicoCache(List<Map<String, dynamic>> chamados) async {
    try {
      final safeBox = boxOrNull ?? await Hive.openBox(boxName);
      await safeBox.put('cached_tecnico_chamados', chamados);
      if (kDebugMode) {
        debugPrint('[OfflineStorage] ${chamados.length} chamados do técnico salvos no cache local do Hive.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Erro ao salvar chamados do técnico: $e');
      }
    }
  }

  /// Recupera a lista em cache local dos chamados do técnico (para uso offline no chão de fábrica)
  List<Map<String, dynamic>> obterChamadosTecnicoCache() {
    try {
      final safeBox = boxOrNull;
      if (safeBox == null) return [];
      final cached = safeBox.get('cached_tecnico_chamados');
      if (cached != null && cached is List) {
        return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Erro ao obter cache de chamados do técnico: $e');
      }
    }
    return [];
  }

  /// Salva as anotações e fotos de documentação do chamado localmente no Hive
  Future<void> salvarDocumentacaoLocal(AtsDocumentacao doc) async {
    try {
      final safeBox = boxOrNull ?? await Hive.openBox(boxName);
      await safeBox.put('doc_${doc.chamadoId}', doc.toMap());
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Documentação do chamado ${doc.chamadoId} salva localmente.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Erro ao salvar documentação local: $e');
      }
    }
  }

  /// Recupera as anotações e fotos de documentação do chamado do cache local do Hive
  AtsDocumentacao? obterDocumentacaoLocal(String chamadoId) {
    try {
      final safeBox = boxOrNull;
      if (safeBox == null) return null;
      final data = safeBox.get('doc_$chamadoId');
      if (data != null && data is Map) {
        return AtsDocumentacao.fromMap(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Erro ao obter documentação local: $e');
      }
    }
    return null;
  }

  /// Salva lista de técnicos cadastrados no cache do Hive
  Future<void> salvarTecnicosCache(List<Map<String, dynamic>> tecnicos) async {
    try {
      final safeBox = boxOrNull ?? await Hive.openBox(boxName);
      await safeBox.put('cached_equipe_tecnicos', tecnicos);
      if (kDebugMode) {
        debugPrint('[OfflineStorage] ${tecnicos.length} técnicos salvos no cache local.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Erro ao salvar técnicos em cache: $e');
      }
    }
  }

  /// Recupera a lista de técnicos do cache local do Hive
  List<Map<String, dynamic>> obterTecnicosCache() {
    try {
      final safeBox = boxOrNull;
      if (safeBox == null) return [];
      final cached = safeBox.get('cached_equipe_tecnicos');
      if (cached != null && cached is List) {
        return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Erro ao obter técnicos do cache: $e');
      }
    }
    return [];
  }

  /// Persiste o perfil selecionado ('Gerente' ou 'Técnico') para sobreviver a F5 na Web
  Future<void> salvarPerfilSelecionado(String role) async {
    try {
      final safeBox = boxOrNull ?? await Hive.openBox(boxName);
      _box ??= safeBox;
      await safeBox.put(_selectedRoleKey, role);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Erro ao salvar perfil selecionado: $e');
      }
    }
  }

  /// Recupera o último perfil selecionado ('Gerente' ou 'Técnico'), se existir
  String? obterPerfilSelecionado() {
    try {
      final safeBox = boxOrNull;
      if (safeBox == null) return null;
      return safeBox.get(_selectedRoleKey)?.toString();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineStorage] Erro ao obter perfil selecionado: $e');
      }
    }
    return null;
  }
}
