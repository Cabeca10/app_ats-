import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/tecnico.dart';
import 'offline_storage_service.dart';

/// Serviço para gerenciar a equipe de técnicos em campo
class TecnicosService {
  static final TecnicosService instance = TecnicosService._internal();
  TecnicosService._internal() {
    _carregarDados();
  }

  /// Notifier com a lista reativa de técnicos
  final ValueNotifier<List<Tecnico>> tecnicosNotifier = ValueNotifier<List<Tecnico>>([]);

  void _carregarDados() {
    // 1. Carrega estritamente os técnicos cadastrados pelo usuário no cache local
    final cached = OfflineStorageService.instance.obterTecnicosCache();
    if (cached.isNotEmpty) {
      tecnicosNotifier.value = cached.map((m) => Tecnico.fromMap(m)).toList();
    } else {
      tecnicosNotifier.value = [];
    }
  }

  /// Adiciona um novo técnico na equipe e persiste
  Future<Tecnico> adicionarTecnico({
    required String nome,
    required String telefone,
    String? email,
    String? especialidade,
  }) async {
    final novo = Tecnico(
      id: const Uuid().v4(),
      nome: nome.trim(),
      telefone: telefone.trim(),
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
        'perfil': 'tecnico',
      });
      debugPrint('[TecnicosService] Técnico ${novo.nome} salvo remotamente no Supabase.');
    } catch (e) {
      debugPrint('[TecnicosService] Técnico salvo localmente (offline): $e');
    }

    return novo;
  }

  /// Remove um técnico da lista e do banco remoto se existir
  Future<void> removerTecnico(String id) async {
    tecnicosNotifier.value = tecnicosNotifier.value.where((t) => t.id != id).toList();
    await _salvarLocalmente();
    try {
      await Supabase.instance.client.from('usuarios').delete().eq('id', id);
    } catch (_) {}
  }

  /// Limpa toda a equipe técnica da simulação
  Future<void> limparTudo({bool limparRemoto = true}) async {
    tecnicosNotifier.value = [];
    await _salvarLocalmente();
    if (limparRemoto) {
      try {
        await Supabase.instance.client
            .from('usuarios')
            .delete()
            .eq('perfil', 'tecnico');
        debugPrint('[TecnicosService] Técnicos remotos removidos com sucesso.');
      } catch (e) {
        debugPrint('[TecnicosService] Aviso ao limpar tecnicos remotos: $e');
      }
    }
    debugPrint('[TecnicosService] Equipe técnica limpa.');
  }

  Future<void> _salvarLocalmente() async {
    final list = tecnicosNotifier.value.map((t) => t.toMap()).toList();
    await OfflineStorageService.instance.salvarTecnicosCache(list);
  }

  /// Lista de nomes disponíveis para dropdowns de atribuição
  List<String> get nomesTecnicos => tecnicosNotifier.value.map((t) => t.nome).toList();
}
