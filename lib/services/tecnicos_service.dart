import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/tecnico.dart';
import 'offline_storage_service.dart';

/// Serviço para gerenciar a equipe de técnicos em campo
class TecnicosService {
  static TecnicosService? _instance;
  static TecnicosService get instance => _instance ??= TecnicosService._internal();

  /// Notifier com a lista reativa de técnicos inicializado de forma segura
  final ValueNotifier<List<Tecnico>> tecnicosNotifier;

  /// Flag que indica se o serviço concluiu a inicialização dos dados
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  TecnicosService._internal()
      : tecnicosNotifier = ValueNotifier<List<Tecnico>>([]) {
    _isInitialized = true;
    _carregarDados();
  }

  void _carregarDados() {
    try {
      // 1. Carrega estritamente os técnicos cadastrados pelo usuário no cache local
      final cached = OfflineStorageService.instance.obterTecnicosCache();
      if (cached.isNotEmpty) {
        tecnicosNotifier.value = cached.map((m) => Tecnico.fromMap(m)).toList();
      } else {
        tecnicosNotifier.value = [];
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[TecnicosService] Erro ao carregar dados do cache: $e\n$stack');
      }
      tecnicosNotifier.value = [];
    }
  }

  /// Adiciona um novo técnico na equipe e persiste
  Future<Tecnico> adicionarTecnico({
    required String nome,
    required String telefone,
    String? fone,
    String? email,
    String? especialidade,
  }) async {
    final telFinal = telefone.trim().isNotEmpty ? telefone.trim() : (fone?.trim() ?? '');
    final novo = Tecnico(
      id: const Uuid().v4(),
      nome: nome.trim(),
      telefone: telFinal,
      email: email?.trim(),
      especialidade: especialidade?.trim(),
    );

    tecnicosNotifier.value = [...tecnicosNotifier.value, novo];
    await _salvarLocalmente();

    // Tenta salvar no Supabase remoto se disponível
    try {
      final userEmail = email != null && email.isNotEmpty
          ? email.trim()
          : '${nome.toLowerCase().replaceAll(RegExp(r'\s+'), '.')}@pmach.com.br';

      await Supabase.instance.client.from('usuarios').insert({
        'id': novo.id,
        'nome': novo.nome,
        'email': userEmail,
        'telefone': novo.telefone,
        'perfil': 'tecnico',
      });
      if (kDebugMode) {
        debugPrint('[TecnicosService] Técnico ${novo.nome} salvo remotamente no Supabase.');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[TecnicosService] Técnico salvo localmente (offline): $e\n$stack');
      }
    }

    return novo;
  }

  /// Remove um técnico da lista e do banco remoto se existir
  Future<void> removerTecnico(String id) async {
    tecnicosNotifier.value = tecnicosNotifier.value.where((t) => t.id != id).toList();
    await _salvarLocalmente();
    try {
      await Supabase.instance.client.from('usuarios').delete().eq('id', id);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[TecnicosService] Erro ao remover técnico no Supabase: $e\n$stackTrace');
      }
    }
  }

  /// Limpa toda a equipe técnica da simulação
  Future<void> limparTudo({bool limparRemoto = true}) async {
    try {
      tecnicosNotifier.value = [];
      await _salvarLocalmente();
      if (limparRemoto) {
        try {
          await Supabase.instance.client
              .from('usuarios')
              .delete()
              .eq('perfil', 'tecnico');
          if (kDebugMode) {
            debugPrint('[TecnicosService] Técnicos remotos removidos com sucesso.');
          }
        } catch (e, stack) {
          if (kDebugMode) {
            debugPrint('[TecnicosService] Aviso ao limpar tecnicos remotos: $e\n$stack');
          }
        }
      }
      if (kDebugMode) {
        debugPrint('[TecnicosService] Equipe técnica limpa.');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[TecnicosService] Erro em limparTudo: $e\n$stack');
      }
    }
  }

  Future<void> _salvarLocalmente() async {
    try {
      final list = tecnicosNotifier.value.map((t) => t.toMap()).toList();
      await OfflineStorageService.instance.salvarTecnicosCache(list);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[TecnicosService] Erro ao salvar localmente: $e\n$stack');
      }
    }
  }

  /// Lista de nomes disponíveis para dropdowns de atribuição
  List<String> get nomesTecnicos =>
      tecnicosNotifier.value.map((t) => t.nome).where((n) => n.trim().isNotEmpty).toList();
}
