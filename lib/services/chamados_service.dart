import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/chamado.dart';
import 'offline_storage_service.dart';

/// Serviço compartilhado para gerenciamento de chamados e sincronização entre Gerente e Técnico
class ChamadosService {
  static final ChamadosService instance = ChamadosService._internal();
  ChamadosService._internal() {
    _inicializarDados();
  }

  /// Notifier com a lista reativa de chamados em memória
  final ValueNotifier<List<Chamado>> chamadosNotifier = ValueNotifier<List<Chamado>>([]);

  /// Notifier para propagar avisos de falhas de sincronização/rede para a interface
  final ValueNotifier<String?> syncErrorNotifier = ValueNotifier<String?>(null);

  void _inicializarDados() {
    chamadosNotifier.value = [];
    _sincronizarComSupabase();
  }

  /// Limpa todos os chamados em memória e esvazia o cache do dispositivo
  Future<void> limparTudo({bool limparRemoto = false}) async {
    chamadosNotifier.value = [];
    await OfflineStorageService.instance.limparTudo();
    if (limparRemoto) {
      try {
        await Supabase.instance.client
            .from('chamados')
            .delete()
            .neq('id', '00000000-0000-0000-0000-000000000000');
        debugPrint('[ChamadosService] Registros remotos de chamados limpos no Supabase.');
      } catch (e) {
        debugPrint('[ChamadosService] Aviso ao limpar remoto no Supabase: $e');
      }
    }
    syncErrorNotifier.value = null;
    debugPrint('[ChamadosService] Memória e armazenamento limpos com sucesso.');
  }

  /// Busca os chamados atualizados no Supabase
  Future<void> _sincronizarComSupabase() async {
    try {
      final response = await Supabase.instance.client
          .from('chamados')
          .select(Chamado.selectColumnsCompletas)
          .order('created_at', ascending: false);

      if ((response as List).isNotEmpty) {
        final lista = response.map((item) => Chamado.fromMap(item)).toList();
        chamadosNotifier.value = lista;
      }
      syncErrorNotifier.value = null;
    } catch (e, stack) {
      debugPrint('[ChamadosService] Aviso ao sincronizar com Supabase: $e');
      debugPrint(stack.toString());
      syncErrorNotifier.value = 'Falha ao sincronizar dados remotos.';
    }
  }

  /// Recupera chamado por número ATS ou ID a partir da memória
  Chamado? obterChamadoPorNumeroAts(String numeroAts) {
    try {
      return chamadosNotifier.value.firstWhere(
        (c) => c.numeroAts == numeroAts || c.id == numeroAts,
      );
    } catch (_) {
      return null;
    }
  }

  /// Recupera chamado por ID a partir da memória
  Chamado? obterChamadoPorId(String id) {
    try {
      return chamadosNotifier.value.firstWhere(
        (c) => c.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  /// Atribui o técnico ao chamado, alterando o status para 'atribuido'
  Future<bool> atribuirTecnico({
    required String chamadoId,
    required String tecnicoNome,
    String? tecnicoId,
  }) async {
    bool remotoAtualizado = false;
    try {
      // 1. Atualiza no Supabase remoto
      await Supabase.instance.client.from('chamados').update({
        'status': ChamadoStatus.atribuido,
        'tecnico_nome': tecnicoNome,
        'tecnico_id': tecnicoId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', chamadoId);
      remotoAtualizado = true;
      syncErrorNotifier.value = null;
    } catch (e) {
      debugPrint('[ChamadosService] Erro ao atribuir técnico no Supabase: $e');
      syncErrorNotifier.value = 'Erro ao atribuir técnico no servidor: $e';
    }

    // 2. Atualiza no estado reativo local
    final listaAtual = List<Chamado>.from(chamadosNotifier.value);
    final index = listaAtual.indexWhere((c) => c.id == chamadoId || c.numeroAts == chamadoId);

    if (index != -1) {
      listaAtual[index] = listaAtual[index].copyWith(
        status: ChamadoStatus.atribuido,
        tecnicoNome: tecnicoNome,
        tecnicoId: tecnicoId ?? listaAtual[index].tecnicoId,
        pendingSync: !remotoAtualizado,
        updatedAt: DateTime.now(),
      );
      chamadosNotifier.value = listaAtual;
      return true;
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
    } catch (e) {
      debugPrint('[ChamadosService] Erro ao atualizar chamado no Supabase: $e');
      syncErrorNotifier.value = 'Falha ao sincronizar alteração: $e';
    }

    final listaAtual = List<Chamado>.from(chamadosNotifier.value);
    final index = listaAtual.indexWhere((c) => c.id == chamadoAtualizado.id || c.tokenUrl == chamadoAtualizado.tokenUrl);

    if (index != -1) {
      listaAtual[index] = chamadoAtualizado.copyWith(
        pendingSync: !remotoAtualizado,
      );
      chamadosNotifier.value = listaAtual;
      return true;
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
    } catch (e) {
      debugPrint('[ChamadosService] Erro ao registrar envio do link no Supabase: $e');
      syncErrorNotifier.value = 'Falha ao registrar envio no servidor: $e';
    }

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

    return false;
  }

  /// Cria uma nova proposta simplificada aberta pelo Gerente (com IDs em formato UUID v4 homologado)
  Future<Chamado> criarNovoChamado({
    required String contato,
    String telefone = '',
    String? emailCliente,
    String? clienteEmail,
    String fabricante = '',
    String modeloMaquina = '',
    String defeitoRelatado = '',
    String? razaoSocial,
    String? endereco,
  }) async {
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
      telefone: telefone,
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

    try {
      final insertMap = novo.toDatabaseMap();
      // O Trigger do PostgreSQL gera o numero_ats oficial caso configurado
      final res = await Supabase.instance.client
          .from('chamados')
          .insert(insertMap)
          .select(Chamado.selectColumnsMinimas)
          .maybeSingle();

      if (res != null) {
        novo = novo.copyWith(
          id: res['id']?.toString() ?? novo.id,
          numeroAts: res['numero_ats']?.toString() ?? novo.numeroAts,
          pendingSync: false,
        );
      }
      syncErrorNotifier.value = null;
    } catch (e, stack) {
      debugPrint('[ChamadosService] Erro ao persistir novo chamado no Supabase: $e');
      debugPrint(stack.toString());
      syncErrorNotifier.value = 'Chamado salvo localmente. Falha ao gravar no servidor: $e';
      novo = novo.copyWith(pendingSync: true);
    }

    final lista = List<Chamado>.from(chamadosNotifier.value);
    lista.insert(0, novo);
    chamadosNotifier.value = lista;

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
    } catch (e) {
      debugPrint('[ChamadosService] Aviso ao sincronizar finalização no Supabase: $e');
      syncErrorNotifier.value = 'Falha ao sincronizar finalização remota: $e';
    }

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

    return false;
  }
}
