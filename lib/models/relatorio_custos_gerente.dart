/// Estrutura consolidada do fechamento financeiro e operacional enviado
/// pelo técnico ao gerente após concluir o atendimento ("Relatório p/ Gerente").
class RelatorioCustosGerente {
  final double horasNormais;
  final double taxaHoraNormal;
  final double horasExtras;
  final double taxaHoraExtra;
  final double horasEspeciais;
  final double taxaHoraEspecial;
  final double horasViagem;
  final double taxaHoraViagem;
  final double kmRodado;
  final double taxaKm;
  final double pedagio;
  final double refeicao;
  final double hospedagem;
  final double pecasOutros;
  final String? observacoes;
  final DateTime? enviadoEm;

  const RelatorioCustosGerente({
    this.horasNormais = 0.0,
    this.taxaHoraNormal = 306.0,
    this.horasExtras = 0.0,
    this.taxaHoraExtra = 459.0,
    this.horasEspeciais = 0.0,
    this.taxaHoraEspecial = 612.0,
    this.horasViagem = 0.0,
    this.taxaHoraViagem = 306.0,
    this.kmRodado = 0.0,
    this.taxaKm = 3.20,
    this.pedagio = 0.0,
    this.refeicao = 0.0,
    this.hospedagem = 0.0,
    this.pecasOutros = 0.0,
    this.observacoes,
    this.enviadoEm,
  });

  double get subtotalHorasNormais => horasNormais * taxaHoraNormal;
  double get subtotalHorasExtras => horasExtras * taxaHoraExtra;
  double get subtotalHorasEspeciais => horasEspeciais * taxaHoraEspecial;
  double get subtotalHorasViagem => horasViagem * taxaHoraViagem;

  double get subtotalHorasTotal =>
      subtotalHorasNormais +
      subtotalHorasExtras +
      subtotalHorasEspeciais +
      subtotalHorasViagem;

  double get subtotalKm => kmRodado * taxaKm;

  double get subtotalDespesasExtras =>
      pedagio + refeicao + hospedagem + pecasOutros;

  double get custoTotalGerado =>
      subtotalHorasTotal + subtotalKm + subtotalDespesasExtras;

  static double _parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val is num) return val.toDouble();
    if (val == null) return fallback;
    return double.tryParse(val.toString().replaceAll(',', '.').trim()) ??
        fallback;
  }

  Map<String, dynamic> toMap() {
    return {
      'horas_normais': horasNormais,
      'taxa_hora_normal': taxaHoraNormal,
      'horas_extras': horasExtras,
      'taxa_hora_extra': taxaHoraExtra,
      'horas_especiais': horasEspeciais,
      'taxa_hora_especial': taxaHoraEspecial,
      'horas_viagem': horasViagem,
      'taxa_hora_viagem': taxaHoraViagem,
      'km_rodado': kmRodado,
      'taxa_km': taxaKm,
      'pedagio': pedagio,
      'refeicao': refeicao,
      'hospedagem': hospedagem,
      'pecas_outros': pecasOutros,
      'observacoes': observacoes,
      'enviado_em': enviadoEm?.toIso8601String(),
      'custo_total_gerado': custoTotalGerado,
    };
  }

  factory RelatorioCustosGerente.fromMap(Map<String, dynamic> map) {
    return RelatorioCustosGerente(
      horasNormais: _parseDouble(map['horas_normais']),
      taxaHoraNormal: _parseDouble(map['taxa_hora_normal'], 306.0),
      horasExtras: _parseDouble(map['horas_extras']),
      taxaHoraExtra: _parseDouble(map['taxa_hora_extra'], 459.0),
      horasEspeciais: _parseDouble(map['horas_especiais']),
      taxaHoraEspecial: _parseDouble(map['taxa_hora_especial'], 612.0),
      horasViagem: _parseDouble(map['horas_viagem']),
      taxaHoraViagem: _parseDouble(map['taxa_hora_viagem'], 306.0),
      kmRodado: _parseDouble(map['km_rodado']),
      taxaKm: _parseDouble(map['taxa_km'], 3.20),
      pedagio: _parseDouble(map['pedagio']),
      refeicao: _parseDouble(map['refeicao']),
      hospedagem: _parseDouble(map['hospedagem']),
      pecasOutros: _parseDouble(map['pecas_outros']),
      observacoes: map['observacoes']?.toString(),
      enviadoEm: map['enviado_em'] != null
          ? DateTime.tryParse(map['enviado_em'].toString())
          : null,
    );
  }
}
