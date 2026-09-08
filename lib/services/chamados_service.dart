import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chamado.dart';

/// Serviço compartilhado para gerenciamento de chamados e sincronização entre Gerente e Técnico
class ChamadosService {
  static final ChamadosService instance = ChamadosService._internal();
  ChamadosService._internal() {
    _inicializarDados();
  }

  final ValueNotifier<List<Chamado>> chamadosNotifier = ValueNotifier<List<Chamado>>([]);

  void _inicializarDados() {
    // Lista inicial de demonstração com os diferentes estados operacionais
    chamadosNotifier.value = [
      Chamado(
        id: 'c-01',
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
        id: 'c-02',
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
        id: 'c-03',
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
        tecnicoId: 'tech-01',
        tecnicoNome: 'Carlos Silva',
        taxaHorariaComercial: 306.00,
        taxaKm: 3.20,
        termosAceitos: true,
        aceiteData: DateTime.now().subtract(const Duration(days: 1)),
        responsavelAceiteNome: 'Marcos Vinicius',
        responsavelAceiteCargo: 'Supervisor de Produção',
      ),
    ];

    _sincronizarComSupabase();
  }

  Future<void> _sincronizarComSupabase() async {
    try {
      final response = await Supabase.instance.client
          .from('chamados')
          .select()
          .order('created_at', ascending: false);

      if ((response as List).isNotEmpty) {
        final lista = response.map((item) => Chamado.fromMap(item)).toList();
        chamadosNotifier.value = lista;
      }
    } catch (_) {
      // Mantém os dados da lista local caso sem conexão remota
    }
  }

  /// Atribui o técnico ao chamado, alterando o status para 'atribuido'
  Future<bool> atribuirTecnico({
    required String chamadoId,
    required String tecnicoNome,
    String? tecnicoId,
  }) async {
    try {
      // 1. Atualiza no Supabase remoto
      await Supabase.instance.client.from('chamados').update({
        'status': ChamadoStatus.atribuido,
        'tecnico_nome': tecnicoNome,
        'tecnico_id': tecnicoId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', chamadoId);
    } catch (_) {
      // Ignora se for ambiente mock
    }

    // 2. Atualiza no estado reativo local
    final listaAtual = List<Chamado>.from(chamadosNotifier.value);
    final index = listaAtual.indexWhere((c) => c.id == chamadoId || c.numeroAts == chamadoId);

    if (index != -1) {
      listaAtual[index] = listaAtual[index].copyWith(
        status: ChamadoStatus.atribuido,
        tecnicoNome: tecnicoNome,
        tecnicoId: tecnicoId ?? 'tech-${tecnicoNome.hashCode}',
        updatedAt: DateTime.now(),
      );
      chamadosNotifier.value = listaAtual;
      return true;
    }

    return false;
  }

  /// Atualiza os dados de um chamado existente no estado local e no Supabase
  Future<bool> atualizarChamado(Chamado chamadoAtualizado) async {
    try {
      await Supabase.instance.client
          .from('chamados')
          .update(chamadoAtualizado.toMap())
          .eq('id', chamadoAtualizado.id);
    } catch (_) {}

    final listaAtual = List<Chamado>.from(chamadosNotifier.value);
    final index = listaAtual.indexWhere((c) => c.id == chamadoAtualizado.id || c.tokenUrl == chamadoAtualizado.tokenUrl);

    if (index != -1) {
      listaAtual[index] = chamadoAtualizado;
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

    try {
      await Supabase.instance.client.from('chamados').update({
        'status': ChamadoStatus.orcamentoEnviado,
        'anotacao_envio': anotacao,
        'data_envio_link': agora.toIso8601String(),
        'updated_at': agora.toIso8601String(),
      }).eq('id', chamadoId);
    } catch (_) {}

    final listaAtual = List<Chamado>.from(chamadosNotifier.value);
    final index = listaAtual.indexWhere((c) => c.id == chamadoId || c.numeroAts == chamadoId);

    if (index != -1) {
      listaAtual[index] = listaAtual[index].copyWith(
        status: ChamadoStatus.orcamentoEnviado,
        anotacaoEnvio: anotacao,
        dataEnvioLink: agora,
        updatedAt: agora,
      );
      chamadosNotifier.value = listaAtual;
      return true;
    }

    return false;
  }

  /// Cria um novo orçamento simplificado aberto pelo Gerente (sem endereço nem CNPJ)
  Future<Chamado> criarNovoChamado({
    required String contato,
    required String telefone,
    required String fabricante,
    required String modeloMaquina,
    required String defeitoRelatado,
    String? razaoSocial,
  }) async {
    final novoNumero = '0147${44 + chamadosNotifier.value.length}';
    final token = 'tok-${DateTime.now().millisecondsSinceEpoch}';
    final agora = DateTime.now();

    final novo = Chamado(
      id: 'chamado-${agora.millisecondsSinceEpoch}',
      numeroAts: novoNumero,
      razaoSocial: (razaoSocial != null && razaoSocial.trim().isNotEmpty) ? razaoSocial.trim() : contato,
      contato: contato,
      telefone: telefone,
      fabricante: fabricante,
      modeloMaquina: modeloMaquina,
      defeitoRelatado: defeitoRelatado,
      tokenUrl: token,
      status: ChamadoStatus.orcamentoPendenteEnvio,
      createdAt: agora,
    );

    try {
      await Supabase.instance.client.from('chamados').insert(novo.toMap());
    } catch (_) {}

    final lista = List<Chamado>.from(chamadosNotifier.value);
    lista.insert(0, novo);
    chamadosNotifier.value = lista;

    return novo;
  }

  /// Finaliza o chamado no Supabase e no estado reativo, atualizando o status para 'finalizado' e salvando a assinatura
  Future<bool> finalizarChamado({
    required String numeroAts,
    String? chamadoId,
    required String assinaturaUrl,
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

    try {
      if (chamadoId != null && chamadoId.isNotEmpty && !chamadoId.startsWith('c-')) {
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
    } catch (e) {
      debugPrint('Aviso ao sincronizar finalização no Supabase: $e');
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
        updatedAt: agora,
      );
      chamadosNotifier.value = listaAtual;
      return true;
    }

    return false;
  }
}
