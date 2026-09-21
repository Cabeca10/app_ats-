import 'package:intl/intl.dart';

/// Modelo que representa um dia de atendimento técnico no ATS (`ats_dias_trabalho`),
/// suportando múltiplos dias intercalados com horários específicos e equipe alocada.
class DiaTrabalho {
  final String? id;
  final String? chamadoId;
  final DateTime data;
  final String horaInicio;
  final String? horaFim;
  final String horaAlmoco;
  final String horaViagem;
  final int numeroTecnicos;
  final String nomesTecnicos;
  final DateTime? createdAt;

  /// Projeção estrita de colunas para consultas otimizadas
  static const String selectColumns =
      'id, chamado_id, data, hora_inicio, hora_fim, hora_almoco, hora_viagem, numero_tecnicos, nomes_tecnicos, created_at';

  DiaTrabalho({
    this.id,
    this.chamadoId,
    required this.data,
    this.horaInicio = '08:00',
    this.horaFim = '17:00',
    this.horaAlmoco = '01:00',
    this.horaViagem = '00:00',
    this.numeroTecnicos = 1,
    this.nomesTecnicos = '',
    this.createdAt,
  });

  /// Utilitário para converter string "HH:mm" ou "HH:mm:ss" em minutos inteiros
  static int _converterHoraParaMinutos(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return 0;
    try {
      final partes = timeStr.trim().split(':');
      final horas = int.tryParse(partes[0]) ?? 0;
      final minutos = partes.length > 1 ? (int.tryParse(partes[1]) ?? 0) : 0;
      return (horas * 60) + minutos;
    } catch (_) {
      return 0;
    }
  }

  /// Utilitário para formatar minutos em string legível (ex: "8h 30min" ou "8h")
  static String formatarMinutos(int totalMinutos) {
    if (totalMinutos <= 0) return '0h 00m';
    final h = totalMinutos ~/ 60;
    final m = totalMinutos % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  /// Minutos líquidos trabalhados no dia: (horaFim - horaInicio - horaAlmoco)
  int get horasLiquidasMinutos {
    if (horaFim == null || horaFim!.trim().isEmpty) return 0;
    final minInicio = _converterHoraParaMinutos(horaInicio);
    final minFim = _converterHoraParaMinutos(horaFim);
    final minAlmoco = _converterHoraParaMinutos(horaAlmoco);

    final liquido = minFim - minInicio - minAlmoco;
    return liquido > 0 ? liquido : 0;
  }

  /// Horas líquidas em formato decimal (ex: 8.5 para 8h30)
  double get horasLiquidasDecimal {
    return horasLiquidasMinutos / 60.0;
  }

  /// Horas líquidas formatadas (ex: "8h 00m")
  String get horasLiquidasFormatadas {
    return formatarMinutos(horasLiquidasMinutos);
  }

  /// Horas de viagem em minutos
  int get horasViagemMinutos => _converterHoraParaMinutos(horaViagem);

  /// Horas de viagem formatadas (ex: "1h 30m")
  String get horasViagemFormatadas => formatarMinutos(horasViagemMinutos);

  /// Data formatada (ex: "20/09/2026")
  String get dataFormatada => DateFormat('dd/MM/yyyy').format(data);

  DiaTrabalho copyWith({
    String? id,
    String? chamadoId,
    DateTime? data,
    String? horaInicio,
    String? horaFim,
    String? horaAlmoco,
    String? horaViagem,
    int? numeroTecnicos,
    String? nomesTecnicos,
    DateTime? createdAt,
  }) {
    return DiaTrabalho(
      id: id ?? this.id,
      chamadoId: chamadoId ?? this.chamadoId,
      data: data ?? this.data,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFim: horaFim ?? this.horaFim,
      horaAlmoco: horaAlmoco ?? this.horaAlmoco,
      horaViagem: horaViagem ?? this.horaViagem,
      numeroTecnicos: numeroTecnicos ?? this.numeroTecnicos,
      nomesTecnicos: nomesTecnicos ?? this.nomesTecnicos,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (chamadoId != null) 'chamado_id': chamadoId,
      'data': '${data.year.toString().padLeft(4, '0')}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}',
      'hora_inicio': horaInicio,
      if (horaFim != null) 'hora_fim': horaFim,
      'hora_almoco': horaAlmoco,
      'hora_viagem': horaViagem,
      'numero_tecnicos': numeroTecnicos,
      'nomes_tecnicos': nomesTecnicos,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  factory DiaTrabalho.fromMap(Map<String, dynamic> map) {
    DateTime dataParsed = DateTime.now();
    if (map['data'] != null) {
      dataParsed = DateTime.tryParse(map['data'].toString()) ?? DateTime.now();
    }

    // Normaliza formato HH:mm se vier com segundos do Postgres TIME (ex: "08:00:00")
    String formatarTimeStr(dynamic val, String def) {
      if (val == null) return def;
      final str = val.toString().trim();
      if (str.isEmpty) return def;
      final parts = str.split(':');
      if (parts.length >= 2) {
        return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
      }
      return str;
    }

    return DiaTrabalho(
      id: map['id']?.toString(),
      chamadoId: map['chamado_id']?.toString(),
      data: dataParsed,
      horaInicio: formatarTimeStr(map['hora_inicio'], '08:00'),
      horaFim: map['hora_fim'] != null ? formatarTimeStr(map['hora_fim'], '17:00') : null,
      horaAlmoco: formatarTimeStr(map['hora_almoco'], '01:00'),
      horaViagem: formatarTimeStr(map['hora_viagem'], '00:00'),
      numeroTecnicos: (map['numero_tecnicos'] as num?)?.toInt() ?? 1,
      nomesTecnicos: map['nomes_tecnicos']?.toString() ?? '',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }
}
