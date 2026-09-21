/// Modelo de Log de Horas e Custos espelhando a tabela 'log_horas_custos'
/// do Supabase com validações e projeção de colunas otimizada para AppSec.
class LogHorasCustos {
  final String id;
  final String idChamado;
  final DateTime data;
  final String horaInicio;
  final String horaFim;
  final double kmRodado;
  final double pedagio;
  final double refeicao;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Projeção de colunas estrita para queries otimizadas
  static const String selectColumns = 
      'id, id_chamado, data, hora_inicio, hora_fim, km_rodado, pedagio, refeicao, created_at, updated_at';

  LogHorasCustos({
    required this.id,
    required this.idChamado,
    required this.data,
    required this.horaInicio,
    required this.horaFim,
    this.kmRodado = 0.0,
    this.pedagio = 0.0,
    this.refeicao = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  /// Total dos custos extras (pedágio + refeição)
  double get totalDespesasExtras => pedagio + refeicao;

  factory LogHorasCustos.fromJson(Map<String, dynamic> json) {
    return LogHorasCustos(
      id: json['id']?.toString() ?? '',
      idChamado: json['id_chamado']?.toString() ?? '',
      data: json['data'] != null ? DateTime.parse(json['data'].toString()) : DateTime.now(),
      horaInicio: json['hora_inicio']?.toString() ?? '08:00',
      horaFim: json['hora_fim']?.toString() ?? '17:00',
      kmRodado: (json['km_rodado'] as num?)?.toDouble() ?? 0.0,
      pedagio: (json['pedagio'] as num?)?.toDouble() ?? 0.0,
      refeicao: (json['refeicao'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_chamado': idChamado,
      'data': '${data.year.toString().padLeft(4, '0')}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}',
      'hora_inicio': horaInicio,
      'hora_fim': horaFim,
      'km_rodado': kmRodado,
      'pedagio': pedagio,
      'refeicao': refeicao,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}
