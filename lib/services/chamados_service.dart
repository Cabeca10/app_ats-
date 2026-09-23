import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/chamado.dart';

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
    // Isolamento de dados mockados sob a flag kDebugMode
    if (kDebugMode) {
      chamadosNotifier.value = _criarChamadosDemonstracao();
    } else {
      chamadosNotifier.value = [];
    }

    _sincronizarComSupabase();
  }

  List<Chamado> _criarChamadosDemonstracao() {
    return [
      Chamado(
        id: '11111111-1111-4111-8111-111111111111',
        numeroAts: '014742',
        razaoSocial: 'Metalúrgica Haas Joinville Ltda',
        cnpj: '84.123.456/0001-99',
        inscricaoEstadual: '254.987.123',
        telefone: '(47) 3456-7890',
        clienteEmail: 'manutencao@haasjoinville.com.br',
        endereco: 'Rua das Indústrias, 1500 - Joinville/SC',
        cidade: 'Joinville - SC',
        fabricante: 'Pmach',
        modeloMaquina: 'Centro de Usinagem CNC V-400',
        numeroSerie: 'PM-2024-8841',
        defeitoRelatado: 'Alarme 1042 no fuso principal. Vibração anormal em rotações superiores a 6000 RPM.',
        tokenUrl: '8f7d9a12-4c3e-4e8b-a2f1-0987654321ab',
        status: ChamadoStatus.aprovadoPendente,
        taxaHorariaComercial: 306.00,
        taxaHorariaExtra: 459.00,
        taxaHorariaEspecial: 612.00,
        taxaKm: 3.20,
        kmEstimado: 35.0,
        horaViagemEstimada: 1.0,
        valorEstimadoTotal: 1980.00,
        termosAceitos: true,
        aceiteData: DateTime.now().subtract(const Duration(minutes: 42)),
        responsavelAceiteNome: 'Eng. Roberto Mendes',
        responsavelAceiteCargo: 'Gerente Industrial',
        orcamentoPdfUrl: 'https://storage.supabase.co/orcamentos/pdfs/014742_aprovado.pdf',
      ),
      Chamado(
        id: '22222222-2222-4222-8222-222222222222',
        numeroAts: '014743',
        razaoSocial: 'Indústria Têxtil Catarinense S.A.',
        cnpj: '12.987.654/0001-33',
        telefone: '(47) 3322-1100',
        clienteEmail: 'compras@textilcatarinense.com.br',
        endereco: 'Av. Brasil, 450 - Blumenau/SC',
        fabricante: 'Pmach',
        modeloMaquina: 'Torno Mecânico Universal TM-500',
        numeroSerie: 'TM-2022-1049',
        defeitoRelatado: 'Folga excessiva no barramento e ruído no cabeçote engrenado.',
        tokenUrl: '3b2a1c09-8d7e-6f5a-4b3c-2a1b0c9d8e7f',
        status: ChamadoStatus.orcamentoEnviado,
        taxaHorariaComercial: 306.00,
        taxaHorariaExtra: 459.00,
        taxaHorariaEspecial: 612.00,
        taxaKm: 3.20,
        kmEstimado: 120.0,
        horaViagemEstimada: 2.0,
      ),
      Chamado(
        id: '33333333-3333-4333-8333-333333333333',
        numeroAts: '014740',
        razaoSocial: 'Metalúrgica Alfa S.A.',
        cnpj: '45.678.901/0001-22',
        telefone: '(47) 3433-2211',
        clienteEmail: 'operacoes@metalurgicaalfa.com.br',
        endereco: 'Av. Industrial, 1024 - Joinville/SC',
        fabricante: 'Pmach',
        modeloMaquina: 'Torno CNC Haas ST-20',
        numeroSerie: 'ST-2023-5591',
        defeitoRelatado: 'Vazamento de fluido refrigerante pela gaxeta do castelo.',
        tokenUrl: '1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d',
        status: ChamadoStatus.atribuido,
        tecnicoId: '00000000-0000-4000-8000-000000000101',
        tecnicoNome: 'Carlos Silva',
        taxaHorariaComercial: 306.00,
        taxaKm: 3.20,
        termosAceitos: true,
        aceiteData: DateTime.now().subtract(const Duration(days: 1)),
        responsavelAceiteNome: 'Marcos Vinicius',
        responsavelAceiteCargo: 'Supervisor de Produção',
      ),
    ];
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
