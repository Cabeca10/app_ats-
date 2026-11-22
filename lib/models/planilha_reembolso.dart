import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

/// Tipos de atendimento idênticos às colunas da planilha mensal de reembolso
class TipoAtendimentoPlanilha {
  static const String foraGarantia = 'Fora de garantia';
  static const String contrato = 'Contrato';
  static const String garantiaPmach = 'Garantia Pmach';
  static const String citzen = 'Citzen';
  static const String pmachInterno = 'Pmach Interno';
  static const String visitaComercial = 'Visita Comercial';

  static const List<String> todos = [
    foraGarantia,
    contrato,
    garantiaPmach,
    citzen,
    pmachInterno,
    visitaComercial,
  ];

  static String normalizar(String? raw) {
    final texto = (raw ?? '').trim().toLowerCase();
    if (texto.isEmpty) return foraGarantia;
    if (texto.contains('fora') && texto.contains('garant')) return foraGarantia;
    if (texto.contains('contrato')) return contrato;
    if (texto.contains('interno')) return pmachInterno;
    if (texto.contains('citzen') || texto.contains('citizen')) return citzen;
    if (texto.contains('visita') || texto.contains('comercial')) return visitaComercial;
    if (texto.contains('garantia') || texto.contains('pmach')) return garantiaPmach;
    return foraGarantia;
  }
}

/// Status do ciclo mensal da planilha de reembolso entre Técnico e Gerente
class StatusPlanilha {
  static const String rascunho = 'rascunho';
  static const String enviada = 'enviada';
  static const String aprovada = 'aprovada';
  static const String ajusteSolicitado = 'ajuste_solicitado';

  static String getLabel(String status) {
    switch (status) {
      case enviada:
        return 'Enviada ao Gerente';
      case aprovada:
        return 'Aprovada';
      case ajusteSolicitado:
        return 'Ajuste Solicitado';
      case rascunho:
      default:
        return 'Em Preenchimento';
    }
  }
}

const List<String> mesesPtBr = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

final NumberFormat _moedaBrFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final NumberFormat _numeroBrFormat = NumberFormat('#,##0.00', 'pt_BR');

/// Converte texto de horário ("08:30", "08:30:00", "1;00") para minutos inteiros
int parseHoraParaMinutos(String? hhmm) {
  if (hhmm == null) return 0;
  final clean = hhmm.trim().replaceAll(';', ':');
  if (clean.isEmpty) return 0;
  final parts = clean.split(':');
  final h = int.tryParse(parts[0].trim()) ?? 0;
  final m = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
  if (h < 0 || m < 0) return 0;
  return (h * 60) + m;
}

/// Formata minutos inteiros como "HH:mm" sem limite de 24h (ex.: 44:20)
String formatarMinutosHHMM(int totalMinutos) {
  if (totalMinutos <= 0) return '00:00';
  final h = totalMinutos ~/ 60;
  final m = totalMinutos % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Calcula horas líquidas trabalhadas no formato planilha: Final - Inicial - Pausa Almoço
int calcularMinutosTrabalhados(String inicio, String pausa, String fim) {
  if (inicio.trim().isEmpty || fim.trim().isEmpty) return 0;
  final minInicio = parseHoraParaMinutos(inicio);
  final minPausa = parseHoraParaMinutos(pausa);
  final minFim = parseHoraParaMinutos(fim);
  return (minFim - minInicio - minPausa).clamp(0, 1440);
}

String formatarMoedaBr(double valor) => _moedaBrFormat.format(valor);

String formatarNumeroBr(double valor) => _numeroBrFormat.format(valor);

/// Linha individual diária da planilha mensal de reembolso
class PlanilhaReembolsoItem {
  final String id;
  final String planilhaId;
  final String tecnicoId;
  final String? chamadoId;
  final DateTime dia;
  final String cliente;
  final String numeroOs;
  final String tipoAtendimento;
  final String horarioInicial;
  final String pausaAlmoco;
  final String horarioFinal;
  final int totalHorasTrabalhadasMin;
  final int horaViagemMin;
  final double km;
  final double pedagio;
  final double refeicao;
  final double pecas;
  final double outros;
  final String motivoOutros;
  final int ordem;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PlanilhaReembolsoItem({
    String? id,
    required this.planilhaId,
    required this.tecnicoId,
    this.chamadoId,
    required this.dia,
    this.cliente = '',
    this.numeroOs = '',
    this.tipoAtendimento = TipoAtendimentoPlanilha.foraGarantia,
    this.horarioInicial = '',
    this.pausaAlmoco = '01:00',
    this.horarioFinal = '',
    int? totalHorasTrabalhadasMin,
    this.horaViagemMin = 0,
    this.km = 0.0,
    this.pedagio = 0.0,
    this.refeicao = 0.0,
    this.pecas = 0.0,
    this.outros = 0.0,
    this.motivoOutros = '',
    this.ordem = 0,
    this.createdAt,
    this.updatedAt,
  })  : id = (id != null && id.isNotEmpty) ? id : const Uuid().v4(),
        totalHorasTrabalhadasMin = totalHorasTrabalhadasMin ??
            calcularMinutosTrabalhados(horarioInicial, pausaAlmoco, horarioFinal);

  PlanilhaReembolsoItem copyWith({
    String? id,
    String? planilhaId,
    String? tecnicoId,
    String? chamadoId,
    DateTime? dia,
    String? cliente,
    String? numeroOs,
    String? tipoAtendimento,
    String? horarioInicial,
    String? pausaAlmoco,
    String? horarioFinal,
    int? totalHorasTrabalhadasMin,
    int? horaViagemMin,
    double? km,
    double? pedagio,
    double? refeicao,
    double? pecas,
    double? outros,
    String? motivoOutros,
    int? ordem,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final nextInicio = horarioInicial ?? this.horarioInicial;
    final nextPausa = pausaAlmoco ?? this.pausaAlmoco;
    final nextFim = horarioFinal ?? this.horarioFinal;
    return PlanilhaReembolsoItem(
      id: id ?? this.id,
      planilhaId: planilhaId ?? this.planilhaId,
      tecnicoId: tecnicoId ?? this.tecnicoId,
      chamadoId: chamadoId ?? this.chamadoId,
      dia: dia ?? this.dia,
      cliente: cliente ?? this.cliente,
      numeroOs: numeroOs ?? this.numeroOs,
      tipoAtendimento: tipoAtendimento ?? this.tipoAtendimento,
      horarioInicial: nextInicio,
      pausaAlmoco: nextPausa,
      horarioFinal: nextFim,
      totalHorasTrabalhadasMin: totalHorasTrabalhadasMin ??
          calcularMinutosTrabalhados(nextInicio, nextPausa, nextFim),
      horaViagemMin: horaViagemMin ?? this.horaViagemMin,
      km: km ?? this.km,
      pedagio: pedagio ?? this.pedagio,
      refeicao: refeicao ?? this.refeicao,
      pecas: pecas ?? this.pecas,
      outros: outros ?? this.outros,
      motivoOutros: motivoOutros ?? this.motivoOutros,
      ordem: ordem ?? this.ordem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get diaIso =>
      '${dia.year.toString().padLeft(4, '0')}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'planilha_id': planilhaId,
      'tecnico_id': tecnicoId,
      'chamado_id': (chamadoId != null && chamadoId!.trim().isNotEmpty) ? chamadoId : null,
      'dia': diaIso,
      'cliente': cliente,
      'numero_os': numeroOs,
      'tipo_atendimento': TipoAtendimentoPlanilha.normalizar(tipoAtendimento),
      'horario_inicial': horarioInicial,
      'pausa_almoco': pausaAlmoco,
      'horario_final': horarioFinal,
      'total_horas_trabalhadas_min': totalHorasTrabalhadasMin,
      'hora_viagem_min': horaViagemMin,
      'km': km,
      'pedagio': pedagio,
      'refeicao': refeicao,
      'pecas': pecas,
      'outros': outros,
      'motivo_outros': motivoOutros,
      'ordem': ordem,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory PlanilhaReembolsoItem.fromMap(Map<String, dynamic> map) {
    final parsedDia = map['dia'] != null
        ? (DateTime.tryParse(map['dia'].toString()) ?? DateTime.now())
        : DateTime.now();
    final inicio = map['horario_inicial']?.toString() ?? '';
    final pausa = map['pausa_almoco']?.toString() ?? '01:00';
    final fim = map['horario_final']?.toString() ?? '';
    final minBanco = (map['total_horas_trabalhadas_min'] as num?)?.toInt();

    return PlanilhaReembolsoItem(
      id: map['id']?.toString(),
      planilhaId: map['planilha_id']?.toString() ?? '',
      tecnicoId: map['tecnico_id']?.toString() ?? '',
      chamadoId: map['chamado_id']?.toString(),
      dia: DateTime(parsedDia.year, parsedDia.month, parsedDia.day),
      cliente: map['cliente']?.toString() ?? '',
      numeroOs: map['numero_os']?.toString() ?? '',
      tipoAtendimento: TipoAtendimentoPlanilha.normalizar(map['tipo_atendimento']?.toString()),
      horarioInicial: inicio,
      pausaAlmoco: pausa,
      horarioFinal: fim,
      totalHorasTrabalhadasMin: minBanco ?? calcularMinutosTrabalhados(inicio, pausa, fim),
      horaViagemMin: (map['hora_viagem_min'] as num?)?.toInt() ?? 0,
      km: (map['km'] as num?)?.toDouble() ?? 0.0,
      pedagio: (map['pedagio'] as num?)?.toDouble() ?? 0.0,
      refeicao: (map['refeicao'] as num?)?.toDouble() ?? 0.0,
      pecas: (map['pecas'] as num?)?.toDouble() ?? 0.0,
      outros: (map['outros'] as num?)?.toDouble() ?? 0.0,
      motivoOutros: map['motivo_outros']?.toString() ?? '',
      ordem: (map['ordem'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }
}

/// Resumo calculado de uma coluna/categoria no quadro inferior da planilha
class ResumoCategoriaPlanilha {
  final String tipo;
  final int horasTrabalhadasMin;
  final double valorHorasTrabalhadas;
  final int horasViagemMin;
  final double valorHorasViagem;
  final double totalKm;
  final double valorKm;
  final double pedagios;
  final double refeicao;
  final double pecas;
  final double outros;
  final double totalReceber;

  const ResumoCategoriaPlanilha({
    required this.tipo,
    this.horasTrabalhadasMin = 0,
    this.valorHorasTrabalhadas = 0.0,
    this.horasViagemMin = 0,
    this.valorHorasViagem = 0.0,
    this.totalKm = 0.0,
    this.valorKm = 0.0,
    this.pedagios = 0.0,
    this.refeicao = 0.0,
    this.pecas = 0.0,
    this.outros = 0.0,
    this.totalReceber = 0.0,
  });
}

/// Planilha mensal completa de um técnico com taxas, itens diários e cálculos idênticos ao Excel
class PlanilhaReembolso {
  final String id;
  final String tecnicoId;
  final String tecnicoNome;
  final int ano;
  final int mes;
  final double valorKm;
  final double valorKmInterno;
  final double valorHoraTecnica;
  final double valorHoraViagem;
  final String status;
  final DateTime? enviadaEm;
  final DateTime? aprovadaEm;
  final String observacaoGerente;
  final List<PlanilhaReembolsoItem> itens;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PlanilhaReembolso({
    String? id,
    required this.tecnicoId,
    required this.tecnicoNome,
    required this.ano,
    required this.mes,
    this.valorKm = 1.50,
    this.valorKmInterno = 0.74,
    this.valorHoraTecnica = 0.00,
    this.valorHoraViagem = 0.00,
    this.status = StatusPlanilha.rascunho,
    this.enviadaEm,
    this.aprovadaEm,
    this.observacaoGerente = '',
    this.itens = const [],
    this.createdAt,
    this.updatedAt,
  }) : id = (id != null && id.isNotEmpty) ? id : const Uuid().v4();

  PlanilhaReembolso copyWith({
    String? id,
    String? tecnicoId,
    String? tecnicoNome,
    int? ano,
    int? mes,
    double? valorKm,
    double? valorKmInterno,
    double? valorHoraTecnica,
    double? valorHoraViagem,
    String? status,
    DateTime? enviadaEm,
    DateTime? aprovadaEm,
    String? observacaoGerente,
    List<PlanilhaReembolsoItem>? itens,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlanilhaReembolso(
      id: id ?? this.id,
      tecnicoId: tecnicoId ?? this.tecnicoId,
      tecnicoNome: tecnicoNome ?? this.tecnicoNome,
      ano: ano ?? this.ano,
      mes: mes ?? this.mes,
      valorKm: valorKm ?? this.valorKm,
      valorKmInterno: valorKmInterno ?? this.valorKmInterno,
      valorHoraTecnica: valorHoraTecnica ?? this.valorHoraTecnica,
      valorHoraViagem: valorHoraViagem ?? this.valorHoraViagem,
      status: status ?? this.status,
      enviadaEm: enviadaEm ?? this.enviadaEm,
      aprovadaEm: aprovadaEm ?? this.aprovadaEm,
      observacaoGerente: observacaoGerente ?? this.observacaoGerente,
      itens: itens ?? this.itens,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get nomeMesAno => '${mesesPtBr[(mes - 1).clamp(0, 11)]} / $ano';

  /// Calcula o quadro resumo idêntico ao rodapé da planilha Excel
  Map<String, ResumoCategoriaPlanilha> calcularResumoPorCategoria() {
    final mapa = <String, ResumoCategoriaPlanilha>{};

    for (final tipo in TipoAtendimentoPlanilha.todos) {
      int minTrab = 0;
      int minViag = 0;
      double totalKm = 0.0;
      double pedagios = 0.0;
      double refeicao = 0.0;
      double pecas = 0.0;
      double outros = 0.0;

      for (final item in itens) {
        if (TipoAtendimentoPlanilha.normalizar(item.tipoAtendimento) == tipo) {
          minTrab += item.totalHorasTrabalhadasMin;
          minViag += item.horaViagemMin;
          totalKm += item.km;
          pedagios += item.pedagio;
          refeicao += item.refeicao;
          pecas += item.pecas;
          outros += item.outros;
        }
      }

      final valorHorasTrab = (minTrab / 60.0) * valorHoraTecnica;
      final valorHorasViag = (minViag / 60.0) * valorHoraViagem;
      final taxaKm = (tipo == TipoAtendimentoPlanilha.pmachInterno)
          ? valorKmInterno
          : valorKm;
      final valorKmTotal = totalKm * taxaKm;
      final totalReceber = valorHorasTrab +
          valorHorasViag +
          valorKmTotal +
          pedagios +
          refeicao +
          pecas +
          outros;

      mapa[tipo] = ResumoCategoriaPlanilha(
        tipo: tipo,
        horasTrabalhadasMin: minTrab,
        valorHorasTrabalhadas: valorHorasTrab,
        horasViagemMin: minViag,
        valorHorasViagem: valorHorasViag,
        totalKm: totalKm,
        valorKm: valorKmTotal,
        pedagios: pedagios,
        refeicao: refeicao,
        pecas: pecas,
        outros: outros,
        totalReceber: totalReceber,
      );
    }

    return mapa;
  }

  double get totalGeralKm => itens.fold<double>(0.0, (s, i) => s + i.km);

  int get totalGeralHorasTrabalhadasMin =>
      itens.fold<int>(0, (s, i) => s + i.totalHorasTrabalhadasMin);

  int get totalGeralHorasViagemMin =>
      itens.fold<int>(0, (s, i) => s + i.horaViagemMin);

  double get totalGeralPedagios => itens.fold<double>(0.0, (s, i) => s + i.pedagio);

  double get totalGeralRefeicao => itens.fold<double>(0.0, (s, i) => s + i.refeicao);

  double get totalGeralPecas => itens.fold<double>(0.0, (s, i) => s + i.pecas);

  double get totalGeralOutros => itens.fold<double>(0.0, (s, i) => s + i.outros);

  double get totalGeralPagarKm => calcularResumoPorCategoria()
      .values
      .fold<double>(0.0, (s, r) => s + r.valorKm);

  double get totalGeralPagarHorasTrabalhadas => calcularResumoPorCategoria()
      .values
      .fold<double>(0.0, (s, r) => s + r.valorHorasTrabalhadas);

  double get totalGeralPagarHorasViagem => calcularResumoPorCategoria()
      .values
      .fold<double>(0.0, (s, r) => s + r.valorHorasViagem);

  double get totalGeralReceber => calcularResumoPorCategoria()
      .values
      .fold<double>(0.0, (s, r) => s + r.totalReceber);

  double get totalDespesasExtras =>
      totalGeralPedagios + totalGeralRefeicao + totalGeralPecas + totalGeralOutros;

  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'tecnico_id': tecnicoId,
      'tecnico_nome': tecnicoNome,
      'ano': ano,
      'mes': mes,
      'valor_km': valorKm,
      'valor_km_interno': valorKmInterno,
      'valor_hora_tecnica': valorHoraTecnica,
      'valor_hora_viagem': valorHoraViagem,
      'status': status,
      if (enviadaEm != null) 'enviada_em': enviadaEm!.toIso8601String(),
      if (aprovadaEm != null) 'aprovada_em': aprovadaEm!.toIso8601String(),
      'observacao_gerente': observacaoGerente,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory PlanilhaReembolso.fromMap(
    Map<String, dynamic> map, {
    List<PlanilhaReembolsoItem> itens = const [],
  }) {
    return PlanilhaReembolso(
      id: map['id']?.toString(),
      tecnicoId: map['tecnico_id']?.toString() ?? '',
      tecnicoNome: map['tecnico_nome']?.toString() ?? '',
      ano: (map['ano'] as num?)?.toInt() ?? DateTime.now().year,
      mes: (map['mes'] as num?)?.toInt() ?? DateTime.now().month,
      valorKm: (map['valor_km'] as num?)?.toDouble() ?? 1.50,
      valorKmInterno: (map['valor_km_interno'] as num?)?.toDouble() ?? 0.74,
      valorHoraTecnica: (map['valor_hora_tecnica'] as num?)?.toDouble() ?? 0.0,
      valorHoraViagem: (map['valor_hora_viagem'] as num?)?.toDouble() ?? 0.0,
      status: map['status']?.toString() ?? StatusPlanilha.rascunho,
      enviadaEm: map['enviada_em'] != null ? DateTime.tryParse(map['enviada_em'].toString()) : null,
      aprovadaEm: map['aprovada_em'] != null ? DateTime.tryParse(map['aprovada_em'].toString()) : null,
      observacaoGerente: map['observacao_gerente']?.toString() ?? '',
      itens: itens,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  /// Gera CSV compatível com Excel PT-BR (separador ';') espelhando todas as seções da planilha
  String gerarCsvExcel() {
    String fmtNum(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
    String escapeCsv(String v) {
      final clean = v.replaceAll('\r', ' ').replaceAll('\n', ' ');
      if (clean.contains(';') || clean.contains('"')) {
        return '"${clean.replaceAll('"', '""')}"';
      }
      return clean;
    }

    final sb = StringBuffer();
    sb.writeln(
      'Técnico:;${escapeCsv(tecnicoNome)};;Valor do km;${fmtNum(valorKm)};;Valor Hora técnica;${fmtNum(valorHoraTecnica)};;Valor hora viagem;${fmtNum(valorHoraViagem)};;Período;${escapeCsv(nomeMesAno)}',
    );
    sb.writeln(';;;Valor do km interno;${fmtNum(valorKmInterno)};;Status;${escapeCsv(StatusPlanilha.getLabel(status))}');
    sb.writeln('');
    sb.writeln(
      'Dia;Cliente;No.OS;Tipo de atendimento;Horário Inicial;Pausa para almoço;Horário Final;Total horas trabalhadas;Hora viagem;Km;Pedágio;Refeição;Peças;Outros;Motivo de outros',
    );

    final diasNoMes = DateTime(ano, mes + 1, 0).day;
    for (int d = 1; d <= diasNoMes; d++) {
      final diaAtual = DateTime(ano, mes, d);
      final itensDia = itens
          .where((i) => i.dia.year == ano && i.dia.month == mes && i.dia.day == d)
          .toList();
      final diaStr = '${diaAtual.year}-${mes.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

      if (itensDia.isEmpty) {
        sb.writeln('$diaStr;;;;;;;;;;;;;;');
      } else {
        for (int idx = 0; idx < itensDia.length; idx++) {
          final item = itensDia[idx];
          sb.writeln([
            idx == 0 ? diaStr : '',
            escapeCsv(item.cliente),
            escapeCsv(item.numeroOs),
            escapeCsv(item.tipoAtendimento),
            item.horarioInicial,
            item.pausaAlmoco,
            item.horarioFinal,
            formatarMinutosHHMM(item.totalHorasTrabalhadasMin),
            formatarMinutosHHMM(item.horaViagemMin),
            fmtNum(item.km),
            fmtNum(item.pedagio),
            fmtNum(item.refeicao),
            fmtNum(item.pecas),
            fmtNum(item.outros),
            escapeCsv(item.motivoOutros),
          ].join(';'));
        }
      }
    }

    sb.writeln(';;;;;;;;;${fmtNum(totalGeralKm)};;;;;');
    sb.writeln('');

    final resumo = calcularResumoPorCategoria();
    sb.writeln('Indicador;${TipoAtendimentoPlanilha.todos.join(';')};Total Geral');
    sb.writeln([
      'Horas trabalhadas',
      ...TipoAtendimentoPlanilha.todos.map((t) => formatarMinutosHHMM(resumo[t]!.horasTrabalhadasMin)),
      formatarMinutosHHMM(totalGeralHorasTrabalhadasMin),
    ].join(';'));
    sb.writeln([
      'Total a pagar horas trabalhadas',
      ...TipoAtendimentoPlanilha.todos.map((t) => fmtNum(resumo[t]!.valorHorasTrabalhadas)),
      fmtNum(totalGeralPagarHorasTrabalhadas),
    ].join(';'));
    sb.writeln([
      'Horas viagens',
      ...TipoAtendimentoPlanilha.todos.map((t) => formatarMinutosHHMM(resumo[t]!.horasViagemMin)),
      formatarMinutosHHMM(totalGeralHorasViagemMin),
    ].join(';'));
    sb.writeln([
      'Total a pagar horas viagens',
      ...TipoAtendimentoPlanilha.todos.map((t) => fmtNum(resumo[t]!.valorHorasViagem)),
      fmtNum(totalGeralPagarHorasViagem),
    ].join(';'));
    sb.writeln([
      'Total Km',
      ...TipoAtendimentoPlanilha.todos.map((t) => fmtNum(resumo[t]!.totalKm)),
      fmtNum(totalGeralKm),
    ].join(';'));
    sb.writeln([
      'Total a pagar KM',
      ...TipoAtendimentoPlanilha.todos.map((t) => fmtNum(resumo[t]!.valorKm)),
      fmtNum(totalGeralPagarKm),
    ].join(';'));
    sb.writeln([
      'Pedágios',
      ...TipoAtendimentoPlanilha.todos.map((t) => fmtNum(resumo[t]!.pedagios)),
      fmtNum(totalGeralPedagios),
    ].join(';'));
    sb.writeln([
      'Refeição',
      ...TipoAtendimentoPlanilha.todos.map((t) => fmtNum(resumo[t]!.refeicao)),
      fmtNum(totalGeralRefeicao),
    ].join(';'));
    sb.writeln([
      'Peças',
      ...TipoAtendimentoPlanilha.todos.map((t) => fmtNum(resumo[t]!.pecas)),
      fmtNum(totalGeralPecas),
    ].join(';'));
    sb.writeln([
      'Outros',
      ...TipoAtendimentoPlanilha.todos.map((t) => fmtNum(resumo[t]!.outros)),
      fmtNum(totalGeralOutros),
    ].join(';'));
    sb.writeln([
      'Total a receber',
      ...TipoAtendimentoPlanilha.todos.map((t) => fmtNum(resumo[t]!.totalReceber)),
      fmtNum(totalGeralReceber),
    ].join(';'));
    sb.writeln('');
    sb.writeln('Total Geral;${fmtNum(totalGeralReceber)}');

    return sb.toString();
  }
}
