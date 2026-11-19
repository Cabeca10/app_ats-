import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/chamado.dart';
import '../utils/url_helper.dart';
import 'offline_storage_service.dart';

/// Serviço compartilhado para gerenciamento de chamados e sincronização entre Gerente e Técnico
class ChamadosService {
  static ChamadosService? _instance;
  static ChamadosService get instance => _instance ??= ChamadosService._internal();
  ChamadosService._internal();

  /// Constrói a URL pública do orçamento / proposta para o cliente
  static String buildOrcamentoUrl(String token) => UrlHelper.buildOrcamentoUrl(token);

  /// Notifier com a lista reativa de chamados em memória
  final ValueNotifier<List<Chamado>> chamadosNotifier = ValueNotifier<List<Chamado>>([]);

  /// Notifier para propagar avisos de falhas de sincronização/rede para a interface
  final ValueNotifier<String?> syncErrorNotifier = ValueNotifier<String?>(null);

  RealtimeChannel? _realtimeChannel;
  bool _realtimeAtivo = false;

  /// Inicializa a escuta Realtime (se ainda não estiver ativa) e sincroniza os chamados
  Future<void> inicializarESincronizar() async {
    if (!_realtimeAtivo) {
      _configurarRealtime();
    }
    await _sincronizarComSupabase();
  }

  void _configurarRealtime() {
    try {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = Supabase.instance.client
          .channel('public:chamados')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'chamados',
            callback: (payload) {
              if (kDebugMode) {
                debugPrint('[ChamadosService] Realtime: alteração na tabela chamados (${payload.eventType})');
              }
              _sincronizarComSupabase();
            },
          )
          .subscribe();
      _realtimeAtivo = true;
    } catch (e, stack) {
      _realtimeAtivo = false;
      if (kDebugMode) {
        debugPrint('[ChamadosService] Aviso ao configurar realtime: $e\n$stack');
      }
    }
  }

  /// Recarrega os chamados do servidor de forma segura sem propagar Uncaught in promise
  Future<void> recarregarChamados() async {
    try {
      await inicializarESincronizar();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ChamadosService] Erro ao recarregar chamados: $e\n$stack');
      }
    }
  }

  /// Limpa todos os chamados em memória e esvazia o cache do dispositivo
  Future<void> limparTudo({bool limparRemoto = false}) async {
    try {
      chamadosNotifier.value = [];
      await OfflineStorageService.instance.limparTudo();
      if (limparRemoto) {
        try {
          await Supabase.instance.client
              .from('chamados')
              .delete()
              .neq('id', '00000000-0000-0000-0000-000000000000');
          if (kDebugMode) {
            debugPrint('[ChamadosService] Registros remotos de chamados limpos no Supabase.');
          }
        } catch (e, stack) {
          if (kDebugMode) {
            debugPrint('[ChamadosService] Aviso ao limpar remoto no Supabase: $e\n$stack');
          }
        }
      }
      syncErrorNotifier.value = null;
      if (kDebugMode) {
        debugPrint('[ChamadosService] Memória e armazenamento limpos com sucesso.');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ChamadosService] Erro geral em limparTudo: $e\n$stack');
      }
    }
  }

  /// Busca os chamados atualizados no Supabase de forma padronizada e resiliente
  Future<void> _sincronizarComSupabase() async {
    try {
      dynamic response;
      // 1. Tenta consulta padrão com as colunas completas ordenando por 'created_at'
      try {
        response = await Supabase.instance.client
            .from('chamados')
            .select(Chamado.selectColumnsCompletas)
            .order('created_at', ascending: false);
      } catch (errCreatedAt) {
        if (kDebugMode) {
          debugPrint('[ChamadosService] Falha ao ordenar por created_at ($errCreatedAt). Tentando fallback por criado_em...');
        }
        // 2. Fallback caso a tabela utilize a convenção em português 'criado_em'
        try {
          response = await Supabase.instance.client
              .from('chamados')
              .select(Chamado.selectColumnsCompletas)
              .order('criado_em', ascending: false);
        } catch (errSelect) {
          if (kDebugMode) {
            debugPrint('[ChamadosService] Falha na seleção de colunas específicas ($errSelect). Tentando select(*)...');
          }
          // 3. Fallback genérico select(*)
          try {
            response = await Supabase.instance.client
                .from('chamados')
                .select('*')
                .order('created_at', ascending: false);
          } catch (_) {
            response = await Supabase.instance.client
                .from('chamados')
                .select('*')
                .order('criado_em', ascending: false);
          }
        }
      }

      if (response != null && response is List) {
        final lista = response.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return Chamado.fromMap(map);
        }).toList();
        final remoteIds = lista.map((c) => c.id).toSet();
        final pendentesLocais = chamadosNotifier.value
            .where((c) => c.pendingSync == true && !remoteIds.contains(c.id))
            .toList();
        chamadosNotifier.value = [...pendentesLocais, ...lista];
      }
      syncErrorNotifier.value = null;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ChamadosService] Aviso ao sincronizar com Supabase: $e');
        debugPrint(stack.toString());
      }
      syncErrorNotifier.value = 'Falha ao sincronizar com o servidor: $e';
    }
  }

  /// Recupera chamado por número ATS ou ID a partir da memória
  Chamado? obterChamadoPorNumeroAts(String numeroAts) {
    try {
      final limpo = numeroAts.replaceAll('ATS-', '').trim();
      return chamadosNotifier.value.cast<Chamado?>().firstWhere(
        (c) => c != null && (c.numeroAts == numeroAts || c.numeroAts == limpo || c.id == numeroAts),
        orElse: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Recupera chamado por Token de URL a partir da memória
  Chamado? obterChamadoPorToken(String token) {
    try {
      return chamadosNotifier.value.cast<Chamado?>().firstWhere(
        (c) => c != null && c.tokenUrl == token,
        orElse: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Recupera chamado por ID a partir da memória
  Chamado? obterChamadoPorId(String id) {
    try {
      return chamadosNotifier.value.cast<Chamado?>().firstWhere(
        (c) => c != null && c.id == id,
        orElse: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Busca remotamente um chamado pelo token da URL de forma segura
  Future<Chamado?> buscarChamadoPorTokenRemoto(String token) async {
    try {
      dynamic response;
      try {
        response = await Supabase.instance.client
            .from('chamados')
            .select(Chamado.selectColumnsCompletas)
            .eq('token_url', token)
            .maybeSingle();
      } catch (_) {
        response = await Supabase.instance.client
            .from('chamados')
            .select('*')
            .eq('token_url', token)
            .maybeSingle();
      }

      if (response != null && response is Map) {
        return Chamado.fromMap(Map<String, dynamic>.from(response));
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ChamadosService] Erro ao buscar chamado por token: $e\n$stack');
      }
    }
    return null;
  }

  /// Atribui os técnicos ao chamado, alterando o status para 'atribuido'
  Future<bool> atribuirTecnico({
    required String chamadoId,
    required String tecnicoNome,
    String? tecnicoId,
    String? tecnico2Nome,
    String? tecnico2Id,
  }) async {
    bool remotoAtualizado = false;
    try {
      // 1. Atualiza no Supabase remoto
      await Supabase.instance.client.from('chamados').update({
        'status': ChamadoStatus.atribuido,
        'tecnico_nome': tecnicoNome,
        'tecnico_id': tecnicoId,
        'tecnico2_nome': tecnico2Nome,
        'tecnico2_id': tecnico2Id,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', chamadoId);
      remotoAtualizado = true;
      syncErrorNotifier.value = null;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ChamadosService] Erro ao atribuir técnico no Supabase: $e\n$stack');
      }
      syncErrorNotifier.value = 'Erro ao atribuir técnico no servidor: $e';
    }

    try {
      // 2. Atualiza no estado reativo local
      final listaAtual = List<Chamado>.from(chamadosNotifier.value);
      final index = listaAtual.indexWhere((c) => c.id == chamadoId || c.numeroAts == chamadoId);

      if (index != -1) {
        listaAtual[index] = listaAtual[index].copyWith(
          status: ChamadoStatus.atribuido,
          tecnicoNome: tecnicoNome,
          tecnicoId: tecnicoId ?? listaAtual[index].tecnicoId,
          tecnico2Nome: tecnico2Nome,
          tecnico2Id: tecnico2Id ?? listaAtual[index].tecnico2Id,
          pendingSync: !remotoAtualizado,
          updatedAt: DateTime.now(),
        );
        chamadosNotifier.value = listaAtual;
        return true;
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ChamadosService] Erro ao atualizar memória em atribuirTecnico: $e\n$stack');
      }
    }

    return false;
  }

  /// Atualiza os dados de um chamado existente no estado local e no Supabase
  Future<bool> atualizarChamado(Chamado chamadoAtualizado) async {
    bool remotoAtualizado = false;
    try {
      await Supabase.instance.client
          .from('chamados')
          .update(chamadoAtualizado.toDatabaseMap())
          .eq('id', chamadoAtualizado.id);
      remotoAtualizado = true;
      syncErrorNotifier.value = null;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ChamadosService] Erro ao atualizar chamado no Supabase: $e\n$stack');
      }
      syncErrorNotifier.value = 'Falha ao sincronizar alteração: $e';
    }

    try {
      final listaAtual = List<Chamado>.from(chamadosNotifier.value);
      final index = listaAtual.indexWhere((c) => c.id == chamadoAtualizado.id || c.tokenUrl == chamadoAtualizado.tokenUrl);

      if (index != -1) {
        listaAtual[index] = chamadoAtualizado.copyWith(
          pendingSync: !remotoAtualizado,
        );
        chamadosNotifier.value = listaAtual;
        return true;
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ChamadosService] Erro ao atualizar memória em atualizarChamado: $e\n$stack');
      }
    }
    return false;
  }

  /// Registra o carimbo de envio do link (WhatsApp ou Copiar Link) e atualiza para orcamento_enviado
  Future<bool> registrarEnvioLink({
    required String chamadoId,
    required String anotacao,
  }) async {
    final agora = DateTime.now();
    bool remotoAtualizado = false;

    try {
      await Supabase.instance.client.from('chamados').update({
        'status': ChamadoStatus.orcamentoEnviado,
        'anotacao_envio': anotacao,
        'data_envio_link': agora.toIso8601String(),
        'updated_at': agora.toIso8601String(),
      }).eq('id', chamadoId);
      remotoAtualizado = true;
      syncErrorNotifier.value = null;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ChamadosService] Erro ao registrar envio do link no Supabase: $e\n$stack');
      }
      syncErrorNotifier.value = 'Falha ao registrar envio no servidor: $e';
    }

    try {
      final listaAtual = List<Chamado>.from(chamadosNotifier.value);
      final index = listaAtual.indexWhere((c) => c.id == chamadoId || c.numeroAts == chamadoId);

      if (index != -1) {
        listaAtual[index] = listaAtual[index].copyWith(
          status: ChamadoStatus.orcamentoEnviado,
          anotacaoEnvio: anotacao,
          dataEnvioLink: agora,
          pendingSync: !remotoAtualizado,
          updatedAt: agora,
        );
        chamadosNotifier.value = listaAtual;
        return true;
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ChamadosService] Erro ao atualizar memória em registrarEnvioLink: $e\n$stack');
      }
    }

    return false;
  }

  /// Cria uma nova proposta simplificada aberta pelo Gerente com compatibilidade de telefone e fone
  Future<Chamado> criarNovoChamado({
    required String contato,
    String telefone = '',
    String? fone,
    String? emailCliente,
    String? clienteEmail,
    String fabricante = '',
    String modeloMaquina = '',
    String defeitoRelatado = '',
    String? razaoSocial,
    String? endereco,
  }) async {
    final telFinal = telefone.trim().isNotEmpty ? telefone.trim() : (fone?.trim() ?? '');
    final agora = DateTime.now();
    final dataFormatada = '${agora.year}${agora.month.toString().padLeft(2, '0')}${agora.day.toString().padLeft(2, '0')}';
    final sequencial = (chamadosNotifier.value.length + 1).toString().padLeft(3, '0');
    final numeroPadrao = 'ATS-$dataFormatada-$sequencial';
    
    // Geração de UUID v4 válido conforme o tipo UUID das colunas no Postgres
    final token = const Uuid().v4();
    final novoUuid = const Uuid().v4();

    Chamado novo = Chamado(
      id: novoUuid,
      numeroAts: numeroPadrao,
      razaoSocial: (razaoSocial != null && razaoSocial.trim().isNotEmpty) ? razaoSocial.trim() : contato,
      contato: contato,
      telefone: telFinal,
      emailCliente: emailCliente ?? clienteEmail,
      endereco: endereco,
      fabricante: fabricante,
      modeloMaquina: modeloMaquina,
      defeitoRelatado: defeitoRelatado,
      tokenUrl: token,
      status: ChamadoStatus.orcamentoPendenteEnvio,
      createdAt: agora,
      pendingSync: false,
    );

    bool salvoRemoto = false;
    Object? ultimoErro;
    try {
      final insertMap = novo.toDatabaseMap();
      dynamic res;
      try {
        // O Trigger do PostgreSQL gera o numero_ats oficial caso configurado
        res = await Supabase.instance.client
            .from('chamados')
            .insert(insertMap)
            .select(Chamado.selectColumnsMinimas)
            .maybeSingle();
        salvoRemoto = true;
      } catch (insertErr) {
        if (kDebugMode) {
          debugPrint('[ChamadosService] Tentativa 1 de insert com selectColumnsMinimas falhou: $insertErr. Tentando sem pdf_url...');
        }
        try {
          final fallbackMap = Map<String, dynamic>.from(insertMap)..remove('pdf_url');
          res = await Supabase.instance.client
              .from('chamados')
              .insert(fallbackMap)
              .select()
              .maybeSingle();
          salvoRemoto = true;
        } catch (innerErr) {
          ultimoErro = innerErr;
          salvoRemoto = false;
          if (kDebugMode) {
            debugPrint('[ChamadosService] Tentativa 2 de insert falhou: $innerErr');
          }
        }
      }

      if (salvoRemoto) {
        if (res != null) {
          novo = novo.copyWith(
            id: res['id']?.toString() ?? novo.id,
            numeroAts: res['numero_ats']?.toString() ?? novo.numeroAts,
            pendingSync: false,
          );
        }
        syncErrorNotifier.value = null;
      } else {
        novo = novo.copyWith(pendingSync: true);
        syncErrorNotifier.value =
            'Proposta NÃO salva no Supabase ($ultimoErro). Execute a migração SQL no Supabase antes de enviar o link.';
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ChamadosService] Erro ao persistir novo chamado no Supabase: $e');
        debugPrint(stack.toString());
      }
      syncErrorNotifier.value =
          'Proposta NÃO salva no Supabase ($e). Execute a migração SQL no Supabase antes de enviar o link.';
      novo = novo.copyWith(pendingSync: true);
    }

    try {
      final lista = List<Chamado>.from(chamadosNotifier.value);
      lista.insert(0, novo);
      chamadosNotifier.value = lista;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ChamadosService] Erro ao atualizar lista reativa local: $e\n$stack');
      }
    }

    return novo;
  }

  /// Finaliza o chamado no Supabase e no estado reativo, atualizando o status para 'finalizado' e salvando a assinatura
  Future<bool> finalizarChamado({
    required String numeroAts,
    String? chamadoId,
    String assinaturaUrl = '',
    String? responsavelNome,
    String? defeitoRelatado,
    String? razaoSocial,
    String? endereco,
    String? modeloMaquina,
    String? numeroSerie,
  }) async {
    final agora = DateTime.now();

    final updateData = <String, dynamic>{
      'status': ChamadoStatus.finalizado,
      'assinatura_url': assinaturaUrl,
      'termos_aceitos': true,
      'aceite_data': agora.toIso8601String(),
      'updated_at': agora.toIso8601String(),
    };

    if (responsavelNome != null && responsavelNome.trim().isNotEmpty) {
      updateData['responsavel_aceite_nome'] = responsavelNome.trim();
    }
    if (defeitoRelatado != null && defeitoRelatado.trim().isNotEmpty) {
      updateData['defeito_relatado'] = defeitoRelatado.trim();
    }
    if (razaoSocial != null && razaoSocial.trim().isNotEmpty) {
      updateData['razao_social'] = razaoSocial.trim();
    }
    if (endereco != null && endereco.trim().isNotEmpty) {
      updateData['endereco'] = endereco.trim();
    }
    if (modeloMaquina != null && modeloMaquina.trim().isNotEmpty) {
      updateData['modelo_maquina'] = modeloMaquina.trim();
    }
    if (numeroSerie != null && numeroSerie.trim().isNotEmpty) {
      updateData['numero_serie'] = numeroSerie.trim();
    }

    bool remotoSucesso = false;
    try {
      if (chamadoId != null && chamadoId.isNotEmpty) {
        await Supabase.instance.client
            .from('chamados')
            .update(updateData)
            .eq('id', chamadoId);
      } else {
        await Supabase.instance.client
            .from('chamados')
            .update(updateData)
            .eq('numero_ats', numeroAts.replaceAll('ATS-', '').trim());
      }
      remotoSucesso = true;
      syncErrorNotifier.value = null;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ChamadosService] Aviso ao sincronizar finalização no Supabase: $e\n$stack');
      }
      syncErrorNotifier.value = 'Falha ao sincronizar finalização remota: $e';
    }

    try {
      // Atualiza estado local reativo
      final cleanAts = numeroAts.replaceAll('ATS-', '').trim();
      final listaAtual = List<Chamado>.from(chamadosNotifier.value);
      final index = listaAtual.indexWhere((c) =>
          (chamadoId != null && c.id == chamadoId) ||
          c.numeroAts == cleanAts ||
          c.numeroAts == numeroAts);

      if (index != -1) {
        listaAtual[index] = listaAtual[index].copyWith(
          status: ChamadoStatus.finalizado,
          assinaturaUrl: assinaturaUrl,
          responsavelAceiteNome: responsavelNome ?? listaAtual[index].responsavelAceiteNome,
          defeitoRelatado: defeitoRelatado ?? listaAtual[index].defeitoRelatado,
          razaoSocial: razaoSocial ?? listaAtual[index].razaoSocial,
          endereco: endereco ?? listaAtual[index].endereco,
          modeloMaquina: modeloMaquina ?? listaAtual[index].modeloMaquina,
          numeroSerie: numeroSerie ?? listaAtual[index].numeroSerie,
          termosAceitos: true,
          aceiteData: agora,
          pendingSync: !remotoSucesso,
          updatedAt: agora,
        );
        chamadosNotifier.value = listaAtual;
        return true;
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ChamadosService] Erro ao atualizar memória em finalizarChamado: $e\n$stack');
      }
    }

    return false;
  }
}
