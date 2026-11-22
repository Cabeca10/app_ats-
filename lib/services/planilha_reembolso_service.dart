import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dia_trabalho.dart';
import '../models/planilha_reembolso.dart';

/// Serviço para gerenciar planilhas mensais de reembolso e importação das ATS do mês
class PlanilhaReembolsoService {
  PlanilhaReembolsoService._internal();
  static final PlanilhaReembolsoService instance = PlanilhaReembolsoService._internal();

  /// Busca a planilha do técnico no mês/ano informado ou cria automaticamente caso não exista
  Future<PlanilhaReembolso> obterOuCriarPlanilha({
    required String tecnicoId,
    required String tecnicoNome,
    required int ano,
    required int mes,
  }) async {
    final client = Supabase.instance.client;

    Map<String, dynamic>? row = await client
        .from('planilhas_reembolso')
        .select()
        .eq('tecnico_id', tecnicoId)
        .eq('ano', ano)
        .eq('mes', mes)
        .maybeSingle();

    if (row == null) {
      final nova = PlanilhaReembolso(
        tecnicoId: tecnicoId,
        tecnicoNome: tecnicoNome.trim().isNotEmpty ? tecnicoNome.trim() : 'Técnico',
        ano: ano,
        mes: mes,
      );
      row = await client
          .from('planilhas_reembolso')
          .upsert(
            nova.toDatabaseMap(),
            onConflict: 'tecnico_id,ano,mes',
          )
          .select()
          .single();
    }

    final planilhaId = row['id'].toString();
    final itensRes = await client
        .from('planilhas_reembolso_itens')
        .select()
        .eq('planilha_id', planilhaId)
        .order('dia', ascending: true)
        .order('ordem', ascending: true)
        .order('created_at', ascending: true);

    final itens = (itensRes as List)
        .map((e) => PlanilhaReembolsoItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return PlanilhaReembolso.fromMap(Map<String, dynamic>.from(row), itens: itens);
  }

  /// Lista todas as planilhas e itens do mês para o painel consolidado do Gerente
  Future<Map<String, PlanilhaReembolso>> listarPlanilhasDoMes({
    required int ano,
    required int mes,
  }) async {
    final client = Supabase.instance.client;
    final planilhasRes = await client
        .from('planilhas_reembolso')
        .select()
        .eq('ano', ano)
        .eq('mes', mes);

    final planilhasRows = (planilhasRes as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (planilhasRows.isEmpty) return {};

    final ids = planilhasRows.map((r) => r['id'].toString()).toList();
    final itensRes = await client
        .from('planilhas_reembolso_itens')
        .select()
        .inFilter('planilha_id', ids)
        .order('dia', ascending: true)
        .order('ordem', ascending: true)
        .order('created_at', ascending: true);

    final itensPorPlanilha = <String, List<PlanilhaReembolsoItem>>{};
    for (final raw in (itensRes as List)) {
      final item = PlanilhaReembolsoItem.fromMap(Map<String, dynamic>.from(raw as Map));
      itensPorPlanilha.putIfAbsent(item.planilhaId, () => []).add(item);
    }

    final mapaPorTecnico = <String, PlanilhaReembolso>{};
    for (final row in planilhasRows) {
      final pId = row['id'].toString();
      final p = PlanilhaReembolso.fromMap(
        row,
        itens: itensPorPlanilha[pId] ?? const [],
      );
      if (p.tecnicoId.isNotEmpty) {
        mapaPorTecnico[p.tecnicoId] = p;
      }
    }
    return mapaPorTecnico;
  }

  /// Atualiza as taxas configuradas no cabeçalho da planilha (Km, Km interno, Hora técnica, Hora viagem)
  Future<PlanilhaReembolso> atualizarParametrosPlanilha(PlanilhaReembolso planilha) async {
    final res = await Supabase.instance.client
        .from('planilhas_reembolso')
        .update({
          'tecnico_nome': planilha.tecnicoNome,
          'valor_km': planilha.valorKm,
          'valor_km_interno': planilha.valorKmInterno,
          'valor_hora_tecnica': planilha.valorHoraTecnica,
          'valor_hora_viagem': planilha.valorHoraViagem,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', planilha.id)
        .select()
        .single();

    return PlanilhaReembolso.fromMap(
      Map<String, dynamic>.from(res),
      itens: planilha.itens,
    );
  }

  /// Insere ou atualiza um lançamento diário na planilha
  Future<PlanilhaReembolsoItem> salvarItem(PlanilhaReembolsoItem item) async {
    final res = await Supabase.instance.client
        .from('planilhas_reembolso_itens')
        .upsert(item.toDatabaseMap(), onConflict: 'id')
        .select()
        .single();

    return PlanilhaReembolsoItem.fromMap(Map<String, dynamic>.from(res));
  }

  /// Remove uma linha diária da planilha
  Future<void> excluirItem(String itemId) async {
    await Supabase.instance.client
        .from('planilhas_reembolso_itens')
        .delete()
        .eq('id', itemId);
  }

  /// Técnico envia a planilha fechada do mês para conferência e pagamento pelo Gerente
  Future<PlanilhaReembolso> enviarParaGerente(PlanilhaReembolso planilha) async {
    final agora = DateTime.now().toIso8601String();
    final res = await Supabase.instance.client
        .from('planilhas_reembolso')
        .update({
          'status': StatusPlanilha.enviada,
          'enviada_em': agora,
          'updated_at': agora,
        })
        .eq('id', planilha.id)
        .select()
        .single();

    return PlanilhaReembolso.fromMap(
      Map<String, dynamic>.from(res),
      itens: planilha.itens,
    );
  }

  /// Gerente aprova ou devolve a planilha para ajustes
  Future<PlanilhaReembolso> atualizarStatusGerente({
    required PlanilhaReembolso planilha,
    required String status,
    String observacao = '',
  }) async {
    final agora = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'status': status,
      'observacao_gerente': observacao.trim(),
      'updated_at': agora,
    };
    if (status == StatusPlanilha.aprovada) {
      payload['aprovada_em'] = agora;
    }

    final res = await Supabase.instance.client
        .from('planilhas_reembolso')
        .update(payload)
        .eq('id', planilha.id)
        .select()
        .single();

    return PlanilhaReembolso.fromMap(
      Map<String, dynamic>.from(res),
      itens: planilha.itens,
    );
  }

  /// Importa dias trabalhados (`ats_dias_trabalho`) e custos (`log_horas_custos`) das ATS do mês
  Future<int> importarAtendimentosAtsDoMes({
    required PlanilhaReembolso planilha,
  }) async {
    final client = Supabase.instance.client;
    final inicioMes = DateTime(planilha.ano, planilha.mes, 1);
    final fimMes = DateTime(planilha.ano, planilha.mes + 1, 0);
    final inicioIso =
        '${inicioMes.year.toString().padLeft(4, '0')}-${inicioMes.month.toString().padLeft(2, '0')}-01';
    final fimIso =
        '${fimMes.year.toString().padLeft(4, '0')}-${fimMes.month.toString().padLeft(2, '0')}-${fimMes.day.toString().padLeft(2, '0')}';

    // 1. Busca chamados atribuídos ao técnico (por ID ou nome como fallback legado)
    final chamadosRes = await client
        .from('chamados')
        .select('id, numero_ats, razao_social, tipo_atendimento, tecnico_id, tecnico2_id, id_tecnico, tecnico_nome, tecnico2_nome')
        .or('tecnico_id.eq.${planilha.tecnicoId},tecnico2_id.eq.${planilha.tecnicoId},id_tecnico.eq.${planilha.tecnicoId}');

    final chamadosPorId = <String, Map<String, dynamic>>{};
    for (final raw in (chamadosRes as List)) {
      final map = Map<String, dynamic>.from(raw as Map);
      chamadosPorId[map['id'].toString()] = map;
    }

    // Fallback por nome caso haja chamados antigos sem tecnico_id preenchido
    if (planilha.tecnicoNome.trim().isNotEmpty) {
      try {
        final partesNome = planilha.tecnicoNome
            .trim()
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .toList();
        final patternNome = partesNome.length >= 2
            ? '%${partesNome.first}%${partesNome.last}%'
            : '%${planilha.tecnicoNome.trim()}%';
        final porNomeRes = await client
            .from('chamados')
            .select('id, numero_ats, razao_social, tipo_atendimento, tecnico_id, tecnico2_id, id_tecnico, tecnico_nome, tecnico2_nome')
            .or('tecnico_nome.ilike.$patternNome,tecnico2_nome.ilike.$patternNome');
        for (final raw in (porNomeRes as List)) {
          final map = Map<String, dynamic>.from(raw as Map);
          final tId = map['tecnico_id']?.toString() ?? '';
          final t2Id = map['tecnico2_id']?.toString() ?? '';
          final pertencePorId = tId == planilha.tecnicoId || t2Id == planilha.tecnicoId;
          final semIdVinculado = tId.isEmpty && t2Id.isEmpty;
          if (pertencePorId || semIdVinculado) {
            chamadosPorId.putIfAbsent(map['id'].toString(), () => map);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[PlanilhaService] Aviso fallback busca por nome: $e');
        }
      }
    }

    if (chamadosPorId.isEmpty) return 0;

    final chamadoIds = chamadosPorId.keys.toList();

    // 2. Busca dias de trabalho no mês selecionado
    final diasRes = await client
        .from('ats_dias_trabalho')
        .select(DiaTrabalho.selectColumns)
        .inFilter('chamado_id', chamadoIds)
        .gte('data', inicioIso)
        .lte('data', fimIso)
        .order('data', ascending: true);

    final dias = (diasRes as List)
        .map((e) => DiaTrabalho.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    if (dias.isEmpty) return 0;

    // 3. Busca despesas extras / KM registradas em log_horas_custos no mês
    final logsRes = await client
        .from('log_horas_custos')
        .select('id, id_chamado, data, km_rodado, pedagio, refeicao')
        .inFilter('id_chamado', chamadoIds)
        .gte('data', inicioIso)
        .lte('data', fimIso);

    final logsPorChamadoData = <String, List<Map<String, dynamic>>>{};
    for (final raw in (logsRes as List)) {
      final map = Map<String, dynamic>.from(raw as Map);
      final cId = map['id_chamado']?.toString() ?? '';
      final dStr = map['data']?.toString().split('T').first ?? '';
      if (cId.isNotEmpty && dStr.isNotEmpty) {
        logsPorChamadoData.putIfAbsent('${cId}_$dStr', () => []).add(map);
      }
    }

    // 4. Deduplica contra lançamentos já existentes na planilha por (chamado_id + diaIso)
    final chavesExistentes = <String>{};
    for (final item in planilha.itens) {
      if (item.chamadoId != null && item.chamadoId!.isNotEmpty) {
        chavesExistentes.add('${item.chamadoId}_${item.diaIso}');
      }
    }

    final novosItens = <PlanilhaReembolsoItem>[];
    int ordemBase = planilha.itens.length;

    for (final dia in dias) {
      final cId = dia.chamadoId ?? '';
      if (cId.isEmpty) continue;
      final chamado = chamadosPorId[cId];
      if (chamado == null) continue;

      // Quando tecnicos_ids está preenchido explicitamente no dia, filtra por este técnico
      if (dia.tecnicosIds.isNotEmpty && !dia.tecnicosIds.contains(planilha.tecnicoId)) {
        continue;
      }

      final diaIso =
          '${dia.data.year.toString().padLeft(4, '0')}-${dia.data.month.toString().padLeft(2, '0')}-${dia.data.day.toString().padLeft(2, '0')}';
      final chave = '${cId}_$diaIso';
      if (!chavesExistentes.add(chave)) continue;

      final logsDia = logsPorChamadoData[chave];
      double km = 0.0;
      double pedagio = 0.0;
      double refeicao = 0.0;
      if (logsDia != null && logsDia.isNotEmpty) {
        for (final log in logsDia) {
          km += (log['km_rodado'] as num?)?.toDouble() ?? 0.0;
          pedagio += (log['pedagio'] as num?)?.toDouble() ?? 0.0;
          refeicao += (log['refeicao'] as num?)?.toDouble() ?? 0.0;
        }
      }

      final rawAts = chamado['numero_ats']?.toString() ?? '';
      final numeroOsLimpo = rawAts
          .replaceFirst(RegExp(r'^ATS-?', caseSensitive: false), '')
          .trim();

      novosItens.add(
        PlanilhaReembolsoItem(
          planilhaId: planilha.id,
          tecnicoId: planilha.tecnicoId,
          chamadoId: cId,
          dia: DateTime(dia.data.year, dia.data.month, dia.data.day),
          cliente: chamado['razao_social']?.toString() ?? '',
          numeroOs: numeroOsLimpo.isNotEmpty ? numeroOsLimpo : rawAts,
          tipoAtendimento: TipoAtendimentoPlanilha.normalizar(
            chamado['tipo_atendimento']?.toString(),
          ),
          horarioInicial: dia.horaInicio,
          pausaAlmoco: dia.horaAlmoco,
          horarioFinal: dia.horaFim ?? '17:00',
          totalHorasTrabalhadasMin: dia.horasLiquidasMinutos,
          horaViagemMin: dia.horasViagemMinutos,
          km: km,
          pedagio: pedagio,
          refeicao: refeicao,
          ordem: ordemBase++,
        ),
      );
    }

    if (novosItens.isNotEmpty) {
      await client
          .from('planilhas_reembolso_itens')
          .insert(novosItens.map((e) => e.toDatabaseMap()).toList());
    }

    return novosItens.length;
  }
}
