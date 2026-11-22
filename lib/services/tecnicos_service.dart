import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tecnico.dart';
import 'offline_storage_service.dart';

/// Serviço para gerenciar a equipe de técnicos em campo com contas reais no Supabase Auth + public.usuarios
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
    _carregarDadosLocais();
  }

  void _carregarDadosLocais() {
    try {
      final cached = OfflineStorageService.instance.obterTecnicosCache();
      if (cached.isNotEmpty) {
        final list = cached
            .map((m) => Tecnico.fromMap(m))
            .where((t) => t.ativo)
            .toList()
          ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
        tecnicosNotifier.value = list;
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

  /// Carrega do cache local e sincroniza a equipe técnica real a partir de public.usuarios
  Future<void> inicializarESincronizar() async {
    if (tecnicosNotifier.value.isEmpty) {
      _carregarDadosLocais();
    }
    await recarregarTecnicos();
  }

  /// Consulta public.usuarios filtrando perfis 'tecnico' e 'gerente_tecnico' ativos
  Future<void> recarregarTecnicos() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final response = await Supabase.instance.client
          .from('usuarios')
          .select('id, nome, email, telefone, especialidade, role, perfil, ativo, created_at, criado_em')
          .order('nome', ascending: true);

      final lista = <Tecnico>[];
      for (final raw in (response as List)) {
        final map = Map<String, dynamic>.from(raw as Map);
        final roleStr = (map['role'] ?? map['perfil'] ?? '').toString().toLowerCase().trim();
        final isAtivo = map['ativo'] is bool ? (map['ativo'] as bool) : true;
        if (isAtivo && (roleStr == 'tecnico' || roleStr == 'gerente_tecnico')) {
          lista.add(Tecnico.fromMap(map));
        }
      }

      lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
      tecnicosNotifier.value = lista;
      await _salvarLocalmente();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[TecnicosService] Falha ao sincronizar equipe técnica com Supabase: $e\n$stack');
      }
    }
  }

  String _extrairErroEdgeFunction(Object err) {
    if (err is FunctionException) {
      final details = err.details;
      if (details is Map && details['error'] != null) {
        return details['error'].toString();
      }
      if (details != null && details.toString().trim().isNotEmpty) {
        return details.toString();
      }
      return err.reasonPhrase ?? 'Erro ao comunicar com o servidor (${err.status}).';
    }
    return err.toString().replaceFirst('Exception: ', '');
  }

  /// Cria uma conta real de técnico (Auth + public.usuarios) via Edge Function manage-technician
  Future<Tecnico> adicionarTecnico({
    required String nome,
    required String telefone,
    required String email,
    required String password,
    String? especialidade,
  }) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'manage-technician',
        body: {
          'action': 'create',
          'nome': nome.trim(),
          'telefone': telefone.trim(),
          'email': email.trim(),
          'password': password.trim(),
          if (especialidade != null && especialidade.trim().isNotEmpty)
            'especialidade': especialidade.trim(),
        },
      );

      final data = res.data;
      if (res.status != 200 || data is! Map || data['tecnico'] == null) {
        final msg = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'Erro ao cadastrar técnico no servidor.';
        throw Exception(msg);
      }

      final novo = Tecnico.fromMap(Map<String, dynamic>.from(data['tecnico'] as Map));
      final atualizada = [
        ...tecnicosNotifier.value.where((t) => t.id != novo.id),
        novo,
      ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

      tecnicosNotifier.value = atualizada;
      await _salvarLocalmente();
      return novo;
    } catch (e) {
      throw Exception(_extrairErroEdgeFunction(e));
    }
  }

  /// Atualiza dados e/ou redefine a senha de um técnico existente via Edge Function manage-technician
  Future<Tecnico> atualizarTecnico({
    required String id,
    required String nome,
    required String telefone,
    String? especialidade,
    String? novaSenha,
  }) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'manage-technician',
        body: {
          'action': 'update',
          'id': id,
          'nome': nome.trim(),
          'telefone': telefone.trim(),
          'especialidade': especialidade?.trim() ?? '',
          if (novaSenha != null && novaSenha.trim().isNotEmpty)
            'password': novaSenha.trim(),
        },
      );

      final data = res.data;
      if (res.status != 200 || data is! Map || data['tecnico'] == null) {
        final msg = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'Erro ao atualizar dados do técnico.';
        throw Exception(msg);
      }

      final atualizado = Tecnico.fromMap(Map<String, dynamic>.from(data['tecnico'] as Map));
      final lista = [
        ...tecnicosNotifier.value.where((t) => t.id != atualizado.id),
        atualizado,
      ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

      tecnicosNotifier.value = lista;
      await _salvarLocalmente();
      return atualizado;
    } catch (e) {
      throw Exception(_extrairErroEdgeFunction(e));
    }
  }

  /// Remove um técnico do Auth e de public.usuarios via Edge Function manage-technician
  Future<void> removerTecnico(String id) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'manage-technician',
        body: {
          'action': 'delete',
          'id': id,
        },
      );

      final data = res.data;
      if (res.status != 200) {
        final msg = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'Erro ao remover técnico no servidor.';
        throw Exception(msg);
      }

      tecnicosNotifier.value = tecnicosNotifier.value.where((t) => t.id != id).toList();
      await _salvarLocalmente();
    } catch (e) {
      throw Exception(_extrairErroEdgeFunction(e));
    }
  }

  Tecnico? buscarPorNome(String? nome) {
    if (nome == null || nome.trim().isEmpty) return null;
    final alvo = nome.trim().toLowerCase();
    for (final t in tecnicosNotifier.value) {
      if (t.nome.trim().toLowerCase() == alvo) return t;
    }
    return null;
  }

  Tecnico? buscarPorId(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    for (final t in tecnicosNotifier.value) {
      if (t.id == id.trim()) return t;
    }
    return null;
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
