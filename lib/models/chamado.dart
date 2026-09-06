import 'dart:convert';

/// Status possíveis do chamado no fluxo operacional
class ChamadoStatus {
  static const String novo = 'novo';
  static const String orcamentoEnviado = 'orcamento_enviado';
  static const String aprovadoPendente = 'aprovado_pendente';
  static const String atribuido = 'atribuido';
  static const String emAtendimento = 'em_atendimento';
  static const String finalizado = 'finalizado';

  static String getLabel(String status) {
    switch (status) {
      case orcamentoEnviado:
        return 'Orçamento Enviado';
      case aprovadoPendente:
        return 'Aprovado (Aguardando Técnico)';
      case atribuido:
        return 'Técnico Atribuído';
      case emAtendimento:
        return 'Em Atendimento';
      case finalizado:
        return 'Finalizado';
      case novo:
      default:
        return 'Novo Chamado';
    }
  }
}

/// Modelo de dados completo para o Chamado / Orçamento Pmach ATS
class Chamado {
  final String id;
  final String numeroAts;
  final String razaoSocial;
  final String? cnpj;
  final String? inscricaoEstadual;
  final String? telefone;
  final String? clienteEmail;
  final String? endereco;
  final String? cidade;

  // Equipamento
  final String? fabricante;
  final String? modeloMaquina;
  final String? numeroSerie;
  final String? defeitoRelatado;

  // Segurança e Rota Pública
  final String tokenUrl;
  final String status;

  // Condições Comerciais do Orçamento
  final double taxaHorariaComercial; // Padrão: R$ 306,00/h
  final double taxaHorariaExtra;     // Padrão: R$ 459,00/h
  final double taxaHorariaEspecial;  // Padrão: R$ 612,00/h
  final double taxaKm;               // Padrão: R$ 3,20/km
  final double? kmEstimado;
  final double? horaViagemEstimada;
  final double? valorEstimadoTotal;

  // Aceite do Cliente
  final bool termosAceitos;
  final DateTime? aceiteData;
  final String? responsavelAceiteNome;
  final String? responsavelAceiteCargo;
  final String? assinaturaUrl;
  final String? orcamentoPdfUrl;

  // Técnico Atribuído
  final String? tecnicoId;
  final String? tecnicoNome;

  // Auditoria
  final DateTime createdAt;
  final DateTime? updatedAt;

  Chamado({
    required this.id,
    required this.numeroAts,
    required this.razaoSocial,
    this.cnpj,
    this.inscricaoEstadual,
    this.telefone,
    this.clienteEmail,
    this.endereco,
    this.cidade,
    this.fabricante,
    this.modeloMaquina,
    this.numeroSerie,
    this.defeitoRelatado,
    required this.tokenUrl,
    this.status = ChamadoStatus.novo,
    this.taxaHorariaComercial = 306.00,
    this.taxaHorariaExtra = 459.00,
    this.taxaHorariaEspecial = 612.00,
    this.taxaKm = 3.20,
    this.kmEstimado,
    this.horaViagemEstimada,
    this.valorEstimadoTotal,
    this.termosAceitos = false,
    this.aceiteData,
    this.responsavelAceiteNome,
    this.responsavelAceiteCargo,
    this.assinaturaUrl,
    this.orcamentoPdfUrl,
    this.tecnicoId,
    this.tecnicoNome,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Chamado copyWith({
    String? id,
    String? numeroAts,
    String? razaoSocial,
    String? cnpj,
    String? inscricaoEstadual,
    String? telefone,
    String? clienteEmail,
    String? endereco,
    String? cidade,
    String? fabricante,
    String? modeloMaquina,
    String? numeroSerie,
    String? defeitoRelatado,
    String? tokenUrl,
    String? status,
    double? taxaHorariaComercial,
    double? taxaHorariaExtra,
    double? taxaHorariaEspecial,
    double? taxaKm,
    double? kmEstimado,
    double? horaViagemEstimada,
    double? valorEstimadoTotal,
    bool? termosAceitos,
    DateTime? aceiteData,
    String? responsavelAceiteNome,
    String? responsavelAceiteCargo,
    String? assinaturaUrl,
    String? orcamentoPdfUrl,
    String? tecnicoId,
    String? tecnicoNome,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Chamado(
      id: id ?? this.id,
      numeroAts: numeroAts ?? this.numeroAts,
      razaoSocial: razaoSocial ?? this.razaoSocial,
      cnpj: cnpj ?? this.cnpj,
      inscricaoEstadual: inscricaoEstadual ?? this.inscricaoEstadual,
      telefone: telefone ?? this.telefone,
      clienteEmail: clienteEmail ?? this.clienteEmail,
      endereco: endereco ?? this.endereco,
      cidade: cidade ?? this.cidade,
      fabricante: fabricante ?? this.fabricante,
      modeloMaquina: modeloMaquina ?? this.modeloMaquina,
      numeroSerie: numeroSerie ?? this.numeroSerie,
      defeitoRelatado: defeitoRelatado ?? this.defeitoRelatado,
      tokenUrl: tokenUrl ?? this.tokenUrl,
      status: status ?? this.status,
      taxaHorariaComercial: taxaHorariaComercial ?? this.taxaHorariaComercial,
      taxaHorariaExtra: taxaHorariaExtra ?? this.taxaHorariaExtra,
      taxaHorariaEspecial: taxaHorariaEspecial ?? this.taxaHorariaEspecial,
      taxaKm: taxaKm ?? this.taxaKm,
      kmEstimado: kmEstimado ?? this.kmEstimado,
      horaViagemEstimada: horaViagemEstimada ?? this.horaViagemEstimada,
      valorEstimadoTotal: valorEstimadoTotal ?? this.valorEstimadoTotal,
      termosAceitos: termosAceitos ?? this.termosAceitos,
      aceiteData: aceiteData ?? this.aceiteData,
      responsavelAceiteNome: responsavelAceiteNome ?? this.responsavelAceiteNome,
      responsavelAceiteCargo: responsavelAceiteCargo ?? this.responsavelAceiteCargo,
      assinaturaUrl: assinaturaUrl ?? this.assinaturaUrl,
      orcamentoPdfUrl: orcamentoPdfUrl ?? this.orcamentoPdfUrl,
      tecnicoId: tecnicoId ?? this.tecnicoId,
      tecnicoNome: tecnicoNome ?? this.tecnicoNome,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero_ats': numeroAts,
      'razao_social': razaoSocial,
      'cnpj': cnpj,
      'inscricao_estadual': inscricaoEstadual,
      'telefone': telefone,
      'cliente_email': clienteEmail,
      'endereco': endereco,
      'cidade': cidade,
      'fabricante': fabricante,
      'modelo_maquina': modeloMaquina,
      'numero_serie': numeroSerie,
      'defeito_relatado': defeitoRelatado,
      'token_url': tokenUrl,
      'status': status,
      'taxa_horaria_comercial': taxaHorariaComercial,
      'taxa_horaria_extra': taxaHorariaExtra,
      'taxa_horaria_especial': taxaHorariaEspecial,
      'taxa_km': taxaKm,
      'km_estimado': kmEstimado,
      'hora_viagem_estimada': horaViagemEstimada,
      'valor_estimado_total': valorEstimadoTotal,
      'termos_aceitos': termosAceitos,
      'aceite_data': aceiteData?.toIso8601String(),
      'responsavel_aceite_nome': responsavelAceiteNome,
      'responsavel_aceite_cargo': responsavelAceiteCargo,
      'assinatura_url': assinaturaUrl,
      'orcamento_pdf_url': orcamentoPdfUrl,
      'tecnico_id': tecnicoId,
      'tecnico_nome': tecnicoNome,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Chamado.fromMap(Map<String, dynamic> map) {
    return Chamado(
      id: map['id'] ?? '',
      numeroAts: map['numero_ats'] ?? '',
      razaoSocial: map['razao_social'] ?? '',
      cnpj: map['cnpj'],
      inscricaoEstadual: map['inscricao_estadual'],
      telefone: map['telefone'],
      clienteEmail: map['cliente_email'],
      endereco: map['endereco'],
      cidade: map['cidade'],
      fabricante: map['fabricante'],
      modeloMaquina: map['modelo_maquina'],
      numeroSerie: map['numero_serie'],
      defeitoRelatado: map['defeito_relatado'],
      tokenUrl: map['token_url'] ?? '',
      status: map['status'] ?? ChamadoStatus.novo,
      taxaHorariaComercial: (map['taxa_horaria_comercial'] as num?)?.toDouble() ?? 306.00,
      taxaHorariaExtra: (map['taxa_horaria_extra'] as num?)?.toDouble() ?? 459.00,
      taxaHorariaEspecial: (map['taxa_horaria_especial'] as num?)?.toDouble() ?? 612.00,
      taxaKm: (map['taxa_km'] as num?)?.toDouble() ?? 3.20,
      kmEstimado: (map['km_estimado'] as num?)?.toDouble(),
      horaViagemEstimada: (map['hora_viagem_estimada'] as num?)?.toDouble(),
      valorEstimadoTotal: (map['valor_estimado_total'] as num?)?.toDouble(),
      termosAceitos: map['termos_aceitos'] == true,
      aceiteData: map['aceite_data'] != null ? DateTime.tryParse(map['aceite_data']) : null,
      responsavelAceiteNome: map['responsavel_aceite_nome'],
      responsavelAceiteCargo: map['responsavel_aceite_cargo'],
      assinaturaUrl: map['assinatura_url'],
      orcamentoPdfUrl: map['orcamento_pdf_url'],
      tecnicoId: map['tecnico_id'],
      tecnicoNome: map['tecnico_nome'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }

  String toJson() => json.encode(toMap());
  factory Chamado.fromJson(String source) => Chamado.fromMap(json.decode(source));
}
