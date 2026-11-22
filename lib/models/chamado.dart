import 'dart:convert';
import 'dia_trabalho.dart';

/// Status possíveis do chamado no fluxo operacional
class ChamadoStatus {
  static const String novo = 'novo';
  static const String orcamentoPendenteEnvio = 'orcamento_pendente_envio';
  static const String orcamentoEnviado = 'orcamento_enviado';
  static const String aprovadoPendente = 'aprovado_pendente';
  static const String atribuido = 'atribuido';
  static const String emAtendimento = 'em_atendimento';
  static const String finalizado = 'finalizado';

  static String getLabel(String status) {
    switch (status) {
      case orcamentoPendenteEnvio:
        return 'Pendente de Envio';
      case orcamentoEnviado:
        return 'Orçamento Enviado';
      case aprovadoPendente:
        return 'ORÇAMENTO APROVADO';
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
  /// Projeção mínima para listagens leves (redução estrita de tráfego AppSec)
  static const String selectColumnsMinimas = 
      'id, numero_ats, razao_social, status, token_url, modelo_maquina, fabricante, numero_serie, defeito_relatado, endereco, telefone, orcamento_pdf_url, relatorio_pdf_url, relatorio_versao, created_at';

  /// Projeção completa para detalhes do chamado
  static const String selectColumnsCompletas = 
      'id, numero_ats, razao_social, cnpj, inscricao_estadual, telefone, cliente_email, email_cliente, endereco, cidade, contato, tipo_atendimento, fabricante, modelo_maquina, numero_serie, defeito_relatado, servico_executado, token_url, status, taxa_horaria_comercial, taxa_horaria_extra, taxa_horaria_especial, taxa_km, km_estimado, hora_viagem_estimada, valor_estimado_total, termos_aceitos, aceite_data, responsavel_aceite_nome, responsavel_aceite_cargo, assinatura_url, orcamento_pdf_url, relatorio_pdf_url, relatorio_versao, tecnico_id, tecnico_nome, tecnico2_id, tecnico2_nome, created_at, updated_at';

  final String id;
  final String numeroAts;
  final String razaoSocial;
  final String? cnpj;
  final String? inscricaoEstadual;
  final String? telefone;
  String? get fone => telefone;
  final String? emailCliente;
  String? get clienteEmail => emailCliente;
  final String? endereco;
  final String? cidade;

  final String? contato;
  final String? anotacaoEnvio;
  final DateTime? dataEnvioLink;

  // Tipo de Atendimento Homologado ('SERV. ENG.', 'MANUTENÇÃO', 'INSTALAÇÃO', 'GARANTIA')
  final String tipoAtendimento;

  // Equipamento
  final String? fabricante;
  final String? modeloMaquina;
  final String? numeroSerie;
  final String? defeitoRelatado;
  final String? servicoExecutado;

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
  String? get pdfUrl => orcamentoPdfUrl;
  final String? relatorioPdfUrl;
  final int relatorioVersao;

  // Mídia adicional e sincronização offline-first
  final String? videoUrl;
  final bool pendingSync;

  // Técnico Atribuído
  final String? tecnicoId;
  final String? tecnicoNome;
  final String? tecnico2Id;
  final String? tecnico2Nome;

  // Dias de Trabalho / Apontamentos no ATS
  final List<DiaTrabalho> diasTrabalho;

  // Auditoria
  final DateTime createdAt;
  DateTime get criadoEm => createdAt;
  final DateTime? updatedAt;
  DateTime? get atualizadoEm => updatedAt;

  Chamado({
    required this.id,
    required this.numeroAts,
    required this.razaoSocial,
    this.contato,
    this.anotacaoEnvio,
    this.dataEnvioLink,
    this.cnpj,
    this.inscricaoEstadual,
    String? telefone,
    String? fone,
    String? emailCliente,
    String? clienteEmail,
    this.endereco,
    this.cidade,
    this.tipoAtendimento = 'MANUTENÇÃO',
    this.fabricante,
    this.modeloMaquina,
    this.numeroSerie,
    this.defeitoRelatado,
    this.servicoExecutado,
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
    this.relatorioPdfUrl,
    this.relatorioVersao = 0,
    this.videoUrl,
    this.pendingSync = false,
    this.tecnicoId,
    this.tecnicoNome,
    this.tecnico2Id,
    this.tecnico2Nome,
    this.diasTrabalho = const [],
    DateTime? createdAt,
    DateTime? criadoEm,
    this.updatedAt,
  })  : telefone = (telefone != null && telefone.trim().isNotEmpty)
            ? telefone.trim()
            : ((fone != null && fone.trim().isNotEmpty) ? fone.trim() : null),
        emailCliente = emailCliente ?? clienteEmail,
        createdAt = createdAt ?? criadoEm ?? DateTime.now();

  Chamado copyWith({
    String? id,
    String? numeroAts,
    String? razaoSocial,
    String? contato,
    String? anotacaoEnvio,
    DateTime? dataEnvioLink,
    String? cnpj,
    String? inscricaoEstadual,
    String? telefone,
    String? fone,
    String? emailCliente,
    String? clienteEmail,
    String? endereco,
    String? cidade,
    String? tipoAtendimento,
    String? fabricante,
    String? modeloMaquina,
    String? numeroSerie,
    String? defeitoRelatado,
    String? servicoExecutado,
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
    String? relatorioPdfUrl,
    int? relatorioVersao,
    String? videoUrl,
    bool? pendingSync,
    String? tecnicoId,
    String? tecnicoNome,
    String? tecnico2Id,
    String? tecnico2Nome,
    List<DiaTrabalho>? diasTrabalho,
    DateTime? createdAt,
    DateTime? criadoEm,
    DateTime? updatedAt,
  }) {
    return Chamado(
      id: id ?? this.id,
      numeroAts: numeroAts ?? this.numeroAts,
      razaoSocial: razaoSocial ?? this.razaoSocial,
      contato: contato ?? this.contato,
      anotacaoEnvio: anotacaoEnvio ?? this.anotacaoEnvio,
      dataEnvioLink: dataEnvioLink ?? this.dataEnvioLink,
      cnpj: cnpj ?? this.cnpj,
      inscricaoEstadual: inscricaoEstadual ?? this.inscricaoEstadual,
      telefone: telefone ?? fone ?? this.telefone,
      emailCliente: emailCliente ?? clienteEmail ?? this.emailCliente,
      endereco: endereco ?? this.endereco,
      cidade: cidade ?? this.cidade,
      tipoAtendimento: tipoAtendimento ?? this.tipoAtendimento,
      fabricante: fabricante ?? this.fabricante,
      modeloMaquina: modeloMaquina ?? this.modeloMaquina,
      numeroSerie: numeroSerie ?? this.numeroSerie,
      defeitoRelatado: defeitoRelatado ?? this.defeitoRelatado,
      servicoExecutado: servicoExecutado ?? this.servicoExecutado,
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
      relatorioPdfUrl: relatorioPdfUrl ?? this.relatorioPdfUrl,
      relatorioVersao: relatorioVersao ?? this.relatorioVersao,
      videoUrl: videoUrl ?? this.videoUrl,
      pendingSync: pendingSync ?? this.pendingSync,
      tecnicoId: tecnicoId ?? this.tecnicoId,
      tecnicoNome: tecnicoNome ?? this.tecnicoNome,
      tecnico2Id: tecnico2Id ?? this.tecnico2Id,
      tecnico2Nome: tecnico2Nome ?? this.tecnico2Nome,
      diasTrabalho: diasTrabalho ?? this.diasTrabalho,
      createdAt: createdAt ?? criadoEm ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero_ats': numeroAts,
      'razao_social': razaoSocial,
      'contato': contato,
      'anotacao_envio': anotacaoEnvio,
      'data_envio_link': dataEnvioLink?.toIso8601String(),
      'cnpj': cnpj,
      'inscricao_estadual': inscricaoEstadual,
      'telefone': telefone,
      'fone': telefone,
      'cliente_email': emailCliente,
      'email_cliente': emailCliente,
      'endereco': endereco,
      'cidade': cidade,
      'tipo_atendimento': tipoAtendimento,
      'fabricante': fabricante,
      'modelo_maquina': modeloMaquina,
      'numero_serie': numeroSerie,
      'defeito_relatado': defeitoRelatado,
      'servico_executado': servicoExecutado,
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
      'pdf_url': orcamentoPdfUrl,
      'relatorio_pdf_url': relatorioPdfUrl,
      'relatorio_versao': relatorioVersao,
      'video_url': videoUrl,
      'pending_sync': pendingSync,
      'tecnico_id': tecnicoId,
      'tecnico_nome': tecnicoNome,
      'tecnico2_id': tecnico2Id,
      'tecnico2_nome': tecnico2Nome,
      'dias_trabalho': diasTrabalho.map((d) => d.toMap()).toList(),
      'created_at': createdAt.toIso8601String(),
      'criado_em': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Converte o chamado em Map estritamente com as colunas existentes na tabela 'chamados' do Supabase
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'numero_ats': numeroAts,
      'razao_social': razaoSocial,
      'contato': contato,
      'anotacao_envio': anotacaoEnvio,
      'data_envio_link': dataEnvioLink?.toIso8601String(),
      'cnpj': cnpj,
      'inscricao_estadual': inscricaoEstadual,
      'telefone': telefone,
      'cliente_email': emailCliente,
      'email_cliente': emailCliente,
      'endereco': endereco,
      'cidade': cidade,
      'tipo_atendimento': tipoAtendimento,
      'fabricante': fabricante,
      'modelo_maquina': modeloMaquina,
      'numero_serie': numeroSerie,
      'defeito_relatado': defeitoRelatado,
      'servico_executado': servicoExecutado,
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
      'pdf_url': orcamentoPdfUrl,
      'relatorio_pdf_url': relatorioPdfUrl,
      'relatorio_versao': relatorioVersao,
      'tecnico_id': tecnicoId,
      'tecnico_nome': tecnicoNome,
      'tecnico2_id': tecnico2Id,
      'tecnico2_nome': tecnico2Nome,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Chamado.fromMap(Map<String, dynamic> map) {
    return Chamado(
      id: map['id']?.toString() ?? '',
      numeroAts: map['numero_ats']?.toString() ?? '',
      razaoSocial: map['razao_social']?.toString() ?? '',
      contato: map['contato']?.toString(),
      anotacaoEnvio: map['anotacao_envio']?.toString(),
      dataEnvioLink: map['data_envio_link'] != null ? DateTime.tryParse(map['data_envio_link'].toString()) : null,
      cnpj: map['cnpj']?.toString(),
      inscricaoEstadual: map['inscricao_estadual']?.toString(),
      telefone: (map['telefone'] ?? map['fone'])?.toString(),
      emailCliente: (map['email_cliente'] ?? map['cliente_email'])?.toString(),
      endereco: map['endereco']?.toString(),
      cidade: map['cidade']?.toString(),
      tipoAtendimento: map['tipo_atendimento']?.toString() ?? 'MANUTENÇÃO',
      fabricante: map['fabricante']?.toString(),
      modeloMaquina: map['modelo_maquina']?.toString(),
      numeroSerie: map['numero_serie']?.toString(),
      defeitoRelatado: map['defeito_relatado']?.toString(),
      servicoExecutado: map['servico_executado']?.toString(),
      tokenUrl: map['token_url']?.toString() ?? '',
      status: map['status']?.toString() ?? ChamadoStatus.novo,
      taxaHorariaComercial: (map['taxa_horaria_comercial'] as num?)?.toDouble() ?? 306.00,
      taxaHorariaExtra: (map['taxa_horaria_extra'] as num?)?.toDouble() ?? 459.00,
      taxaHorariaEspecial: (map['taxa_horaria_especial'] as num?)?.toDouble() ?? 612.00,
      taxaKm: (map['taxa_km'] as num?)?.toDouble() ?? 3.20,
      kmEstimado: (map['km_estimado'] as num?)?.toDouble(),
      horaViagemEstimada: (map['hora_viagem_estimada'] as num?)?.toDouble(),
      valorEstimadoTotal: (map['valor_estimado_total'] as num?)?.toDouble(),
      termosAceitos: map['termos_aceitos'] == true,
      aceiteData: map['aceite_data'] != null ? DateTime.tryParse(map['aceite_data'].toString()) : null,
      responsavelAceiteNome: map['responsavel_aceite_nome']?.toString(),
      responsavelAceiteCargo: map['responsavel_aceite_cargo']?.toString(),
      assinaturaUrl: map['assinatura_url']?.toString(),
      orcamentoPdfUrl: (map['orcamento_pdf_url'] ?? map['pdf_url'])?.toString(),
      relatorioPdfUrl: map['relatorio_pdf_url']?.toString(),
      relatorioVersao: (map['relatorio_versao'] as num?)?.toInt() ?? 0,
      videoUrl: map['video_url']?.toString(),
      pendingSync: map['pending_sync'] == true,
      tecnicoId: map['tecnico_id']?.toString(),
      tecnicoNome: map['tecnico_nome']?.toString(),
      tecnico2Id: map['tecnico2_id']?.toString(),
      tecnico2Nome: map['tecnico2_nome']?.toString(),
      diasTrabalho: map['dias_trabalho'] != null
          ? (map['dias_trabalho'] as List)
              .map((item) => DiaTrabalho.fromMap(Map<String, dynamic>.from(item as Map)))
              .toList()
          : const [],
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
          : (map['criado_em'] != null
              ? (DateTime.tryParse(map['criado_em'].toString()) ?? DateTime.now())
              : DateTime.now()),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : (map['atualizado_em'] != null
              ? DateTime.tryParse(map['atualizado_em'].toString())
              : null),
    );
  }

  String toJson() => json.encode(toMap());
  factory Chamado.fromJson(String source) => Chamado.fromMap(json.decode(source));
}
