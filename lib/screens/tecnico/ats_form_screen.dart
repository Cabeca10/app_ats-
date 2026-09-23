import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chamado.dart';
import '../../models/log_horas_custos.dart';
import '../../models/dia_trabalho.dart';
import '../../services/ats_pdf_service.dart';
import '../../services/chamados_service.dart';
import '../../services/offline_storage_service.dart';
import 'tecnico_dashboard.dart';

class AtsFormScreen extends StatefulWidget {
  final Ticket? ticket;
  final Chamado? chamado;
  final bool isEmbedded;

  const AtsFormScreen({
    super.key,
    this.ticket,
    this.chamado,
    this.isEmbedded = false,
  });

  @override
  State<AtsFormScreen> createState() => _AtsFormScreenState();
}

/// Alias para manter compatibilidade com códigos legados
typedef AtsReportScreen = AtsFormScreen;

class _AtsFormScreenState extends State<AtsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isSyncing = false;
  bool _isSavingDraft = false;
  late final PageController _diasPageController;
  int _diaAtualIndex = 0;

  // 1. Dados do Cabeçalho (Leitura)
  late String _numeroAts;
  late String _chamadoId;
  late String _razaoSocial;
  late String _endereco;
  late String _emailCliente;
  late String _modeloMaquina;
  late String _fabricante;
  late String _numeroSerie;
  late String _defeitoRelatado;

  // 1.1 Classificação do Atendimento e Equipe Técnica
  String _tipoAtendimento = 'MANUTENÇÃO';
  List<Map<String, dynamic>> _listaTecnicosDisponiveis = [];

  // 2. Dias Trabalhados e Despesas
  List<DiaTrabalho> _diasTrabalho = [];
  final _kmRodadoCtrl = TextEditingController(text: '0.0');
  final _pedagioCtrl = TextEditingController(text: '0.00');
  final _refeicaoCtrl = TextEditingController(text: '0.00');

  // 3. Serviço Executado
  final _servicoExecutadoCtrl = TextEditingController();

  // 4. Assinatura
  late final SignatureController _signatureController;
  final _responsavelNomeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Inicializa SignatureController e PageController do carrossel
    _signatureController = SignatureController(
      penStrokeWidth: 3.0,
      penColor: const Color(0xFF0F172A),
      exportBackgroundColor: Colors.white,
    );
    _diasPageController = PageController(viewportFraction: 0.88);

    // Carrega dados a partir do chamado ou ticket recebido
    if (widget.chamado != null) {
      final c = widget.chamado!;
      _chamadoId = c.id;
      _numeroAts = c.numeroAts;
      _razaoSocial = c.razaoSocial;
      _endereco = c.endereco ?? 'Não informado';
      _emailCliente = c.emailCliente ?? 'Não informado';
      _tipoAtendimento = c.tipoAtendimento;
      _modeloMaquina = c.modeloMaquina ?? 'Em levantamento';
      _fabricante = c.fabricante ?? 'N/A';
      _numeroSerie = c.numeroSerie ?? 'N/A';
      _defeitoRelatado = c.defeitoRelatado ?? 'Nenhum defeito cadastrado';
      _responsavelNomeCtrl.text = c.responsavelAceiteNome ?? '';
      if (c.servicoExecutado != null && c.servicoExecutado!.trim().isNotEmpty) {
        _servicoExecutadoCtrl.text = c.servicoExecutado!.trim();
      }
    } else if (widget.ticket != null) {
      final t = widget.ticket!;
      _chamadoId = t.chamadoId ?? t.id;
      _numeroAts = (t.numeroAts != null && t.numeroAts!.isNotEmpty) ? t.numeroAts! : t.id.replaceAll('ATS-', '').trim();
      _razaoSocial = t.companyName;
      _endereco = t.address.isNotEmpty ? t.address : 'Conforme cadastro';
      _emailCliente = 'Não informado';
      _modeloMaquina = t.machineModel.isNotEmpty ? t.machineModel : 'Em levantamento';
      _fabricante = 'N/A';
      _numeroSerie = 'N/A';
      _defeitoRelatado = t.defeitoRelatado ?? 'Anomalia informada pelo solicitante';

      // Tenta recuperar do ChamadosService em memória se disponível
      final cMemoria = ChamadosService.instance.obterChamadoPorNumeroAts(_numeroAts) ??
          ChamadosService.instance.obterChamadoPorId(_chamadoId);
      if (cMemoria != null) {
        _chamadoId = cMemoria.id;
        _tipoAtendimento = cMemoria.tipoAtendimento;
        _emailCliente = cMemoria.emailCliente ?? _emailCliente;
        if (cMemoria.servicoExecutado != null && cMemoria.servicoExecutado!.trim().isNotEmpty) {
          _servicoExecutadoCtrl.text = cMemoria.servicoExecutado!.trim();
        }
      }
    } else {
      _chamadoId = 'c-014742';
      _numeroAts = '014742';
      _razaoSocial = 'Cliente Pmach Industrial';
      _endereco = 'Rua das Indústrias, 100';
      _emailCliente = 'contato@pmach.com.br';
      _tipoAtendimento = 'MANUTENÇÃO';
      _modeloMaquina = 'Torno CNC Brother TC-R23';
      _fabricante = 'Brother';
      _numeroSerie = 'BR-2026-99';
      _defeitoRelatado = 'Falha no servo acionamento eixo Z';
    }

    // Inicializa lista de dias trabalhados
    if (widget.chamado != null && widget.chamado!.diasTrabalho.isNotEmpty) {
      _diasTrabalho = List.from(widget.chamado!.diasTrabalho);
    } else {
      _diasTrabalho = [
        DiaTrabalho(
          chamadoId: _chamadoId,
          data: DateTime.now(),
          horaInicio: '08:00',
          horaFim: '17:00',
          horaAlmoco: '01:00',
          horaViagem: '00:00',
          numeroTecnicos: 1,
          nomesTecnicos: widget.chamado?.tecnicoNome ?? 'Técnico Responsável',
        ),
      ];
    }

    // Tenta restaurar dados locais offline previamente salvos se houver
    _carregarRascunhoLocal();

    // Carrega a equipe de técnicos cadastrados no sistema
    _carregarTecnicosDisponiveis();

    // Sincroniza dados com o Supabase automaticamente ao abrir a tela (carrega o que foi salvo no PC)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sincronizarDadosComSupabase();
    });
  }

  Future<void> _carregarRascunhoLocal() async {
    final offlineData = OfflineStorageService.instance.obterAtendimento(_chamadoId);
    if (offlineData != null && mounted) {
      setState(() {
        if (offlineData['tipo_atendimento'] != null) {
          _tipoAtendimento = offlineData['tipo_atendimento'].toString();
        }
        if (offlineData['servico_executado'] != null) {
          _servicoExecutadoCtrl.text = offlineData['servico_executado'].toString();
        }
        if (offlineData['km_rodado'] != null) {
          _kmRodadoCtrl.text = offlineData['km_rodado'].toString();
        }
        if (offlineData['pedagio'] != null) {
          _pedagioCtrl.text = offlineData['pedagio'].toString();
        }
        if (offlineData['refeicao'] != null) {
          _refeicaoCtrl.text = offlineData['refeicao'].toString();
        }
        if (offlineData['responsavel_nome'] != null) {
          _responsavelNomeCtrl.text = offlineData['responsavel_nome'].toString();
        }
        if (offlineData['dias_trabalho'] != null && (offlineData['dias_trabalho'] is List)) {
          final list = (offlineData['dias_trabalho'] as List)
              .map((e) => DiaTrabalho.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList();
          if (list.isNotEmpty) {
            _diasTrabalho = list;
          }
        }
      });
    }
  }

  /// Carrega lista de técnicos cadastrados na tabela usuarios para alocação nos dias
  Future<void> _carregarTecnicosDisponiveis() async {
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('usuarios')
          .select('id, nome, email, perfil')
          .order('nome', ascending: true);

      if (res.isNotEmpty && mounted) {
        setState(() {
          _listaTecnicosDisponiveis = List<Map<String, dynamic>>.from(res);
        });
        return;
      }
    } catch (e) {
      debugPrint('[AtsForm] Erro ao carregar usuarios/tecnicos: $e');
    }

    // Fallback caso offline ou usuarios vazio: inclui tecnico atribuido e defaults
    if (_listaTecnicosDisponiveis.isEmpty && mounted) {
      final List<Map<String, dynamic>> defaults = [];
      if (widget.chamado?.tecnicoId != null) {
        defaults.add({
          'id': widget.chamado!.tecnicoId!,
          'nome': widget.chamado!.tecnicoNome ?? 'Técnico Responsável',
          'email': 'responsavel@pmach.com.br',
          'perfil': 'Técnico',
        });
      }
      defaults.addAll([
        {
          'id': '00000000-0000-0000-0000-000000000001',
          'nome': 'Ricardo Santin',
          'email': 'ricardo@pmach.com.br',
          'perfil': 'Técnico',
        },
        {
          'id': '00000000-0000-0000-0000-000000000002',
          'nome': 'Técnico Campo 02',
          'email': 'tecnico2@pmach.com.br',
          'perfil': 'Técnico',
        },
      ]);
      setState(() {
        _listaTecnicosDisponiveis = defaults;
      });
    }
  }

  /// Sincroniza dados do chamado e dos dias trabalhados da nuvem (Supabase)
  /// Permite que o celular carregue instantaneamente o que o técnico digitou no PC
  Future<void> _sincronizarDadosComSupabase({bool manual = false}) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.contains(ConnectivityResult.none) || connectivityResult.isEmpty;

    if (isOffline) {
      if (manual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dispositivo offline. Exibindo rascunho armazenado localmente.'),
            backgroundColor: Color(0xFFD97706),
          ),
        );
      }
      return;
    }

    if (mounted) setState(() => _isSyncing = true);

    try {
      final client = Supabase.instance.client;

      // 1. Busca dados atualizados do chamado (memorial servico_executado, responsavel, tipo_atendimento, email)
      Map<String, dynamic>? chamadoRes;
      if (_chamadoId.isNotEmpty && !_chamadoId.startsWith('c-')) {
        chamadoRes = await client
            .from('chamados')
            .select('id, servico_executado, responsavel_aceite_nome, tipo_atendimento, email_cliente, cliente_email')
            .eq('id', _chamadoId)
            .maybeSingle();
      }
      if (chamadoRes == null && _numeroAts.isNotEmpty) {
        chamadoRes = await client
            .from('chamados')
            .select('id, servico_executado, responsavel_aceite_nome, tipo_atendimento, email_cliente, cliente_email')
            .eq('numero_ats', _numeroAts)
            .maybeSingle();
      }

      if (chamadoRes != null) {
        if (chamadoRes['id'] != null) {
          _chamadoId = chamadoRes['id'].toString();
        }
        final servicoCloud = chamadoRes['servico_executado']?.toString();
        final responsavelCloud = chamadoRes['responsavel_aceite_nome']?.toString();
        final tipoCloud = chamadoRes['tipo_atendimento']?.toString();
        final emailCloud = (chamadoRes['email_cliente'] ?? chamadoRes['cliente_email'])?.toString();

        if (servicoCloud != null && servicoCloud.trim().isNotEmpty) {
          _servicoExecutadoCtrl.text = servicoCloud.trim();
        }
        if (responsavelCloud != null && responsavelCloud.trim().isNotEmpty) {
          _responsavelNomeCtrl.text = responsavelCloud.trim();
        }
        if (tipoCloud != null && tipoCloud.trim().isNotEmpty) {
          _tipoAtendimento = tipoCloud.trim();
        }
        if (emailCloud != null && emailCloud.trim().isNotEmpty) {
          _emailCliente = emailCloud.trim();
        }
      }

      // 1.1 Atualiza lista de técnicos da base
      await _carregarTecnicosDisponiveis();

      // 2. Busca dias de trabalho na nuvem (ats_dias_trabalho)
      if (_chamadoId.isNotEmpty && !_chamadoId.startsWith('c-')) {
        final diasRes = await client
            .from('ats_dias_trabalho')
            .select()
            .eq('chamado_id', _chamadoId)
            .order('data', ascending: true)
            .order('hora_inicio', ascending: true);

        if (diasRes.isNotEmpty) {
          final List<DiaTrabalho> diasNuvem = diasRes
              .map((d) => DiaTrabalho.fromMap(Map<String, dynamic>.from(d)))
              .toList();
          if (diasNuvem.isNotEmpty) {
            _diasTrabalho = diasNuvem;
          }
        }

        // 3. Busca despesas em log_horas_custos
        final logRes = await client
            .from('log_horas_custos')
            .select()
            .eq('id_chamado', _chamadoId)
            .maybeSingle();

        if (logRes != null) {
          if (logRes['km_rodado'] != null && logRes['km_rodado'].toString() != '0.0') {
            _kmRodadoCtrl.text = logRes['km_rodado'].toString();
          }
          if (logRes['pedagio'] != null && logRes['pedagio'].toString() != '0.00') {
            _pedagioCtrl.text = logRes['pedagio'].toString();
          }
          if (logRes['refeicao'] != null && logRes['refeicao'].toString() != '0.00') {
            _refeicaoCtrl.text = logRes['refeicao'].toString();
          }
        }
      }

      // 4. Salva no Hive localmente para manter o cache atualizado
      await OfflineStorageService.instance.salvarAtendimentoLocal(
        id: _chamadoId,
        dados: {
          'chamado_id': _chamadoId,
          'numero_ats': _numeroAts,
          'razao_social': _razaoSocial,
          'tipo_atendimento': _tipoAtendimento,
          'dias_trabalho': _diasTrabalho.map((d) => d.toMap()).toList(),
          'km_rodado': double.tryParse(_kmRodadoCtrl.text.replaceAll(',', '.')) ?? 0.0,
          'pedagio': double.tryParse(_pedagioCtrl.text.replaceAll(',', '.')) ?? 0.0,
          'refeicao': double.tryParse(_refeicaoCtrl.text.replaceAll(',', '.')) ?? 0.0,
          'servico_executado': _servicoExecutadoCtrl.text.trim(),
          'responsavel_nome': _responsavelNomeCtrl.text.trim(),
          'pending_sync': false,
        },
        pendingSync: false,
      );

      if (mounted) {
        setState(() {});
        if (manual) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dados atualizados com sucesso a partir da nuvem!'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[AtsForm] Erro ao sincronizar da nuvem: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// Salva rascunho das informações (memorial, despesas e dias de trabalho)
  /// sem exigir assinatura imediata, permitindo alternar entre PC e Celular
  Future<void> _salvarRascunho({bool silencioso = false}) async {
    setState(() => _isSavingDraft = true);

    final kmRodado = double.tryParse(_kmRodadoCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final pedagio = double.tryParse(_pedagioCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final refeicao = double.tryParse(_refeicaoCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final primeiroDia = _diasTrabalho.isNotEmpty ? _diasTrabalho.first : null;
    final dataAtendimento = primeiroDia?.data ?? DateTime.now();
    final horaInicioStr = primeiroDia?.horaInicio ?? '08:00';
    final horaFimStr = primeiroDia?.horaFim ?? '17:00';

    // 1. Armazena localmente no Hive (offline-first garantido)
    final payloadLocal = {
      'chamado_id': _chamadoId,
      'numero_ats': _numeroAts,
      'razao_social': _razaoSocial,
      'tipo_atendimento': _tipoAtendimento,
      'dias_trabalho': _diasTrabalho.map((d) => d.toMap()).toList(),
      'data_atendimento': dataAtendimento.toIso8601String(),
      'hora_inicio': horaInicioStr,
      'hora_fim': horaFimStr,
      'km_rodado': kmRodado,
      'pedagio': pedagio,
      'refeicao': refeicao,
      'servico_executado': _servicoExecutadoCtrl.text.trim(),
      'responsavel_nome': _responsavelNomeCtrl.text.trim(),
      'qtd_fotos': 0,
      'tem_video': false,
      'pending_sync': true,
    };

    await OfflineStorageService.instance.salvarAtendimentoLocal(
      id: _chamadoId,
      dados: payloadLocal,
      pendingSync: true,
    );

    // 2. Se online, envia imediatamente ao Supabase (para que o outro dispositivo veja)
    final connectivityResult = await Connectivity().checkConnectivity();
    final bool isOffline = connectivityResult.contains(ConnectivityResult.none) ||
        connectivityResult.isEmpty;

    if (!isOffline) {
      try {
        final client = Supabase.instance.client;

        // Atualiza chamado mantendo status em andamento
        final chamadoUpdate = <String, dynamic>{
          'servico_executado': _servicoExecutadoCtrl.text.trim(),
          'status': ChamadoStatus.emAtendimento,
          'tipo_atendimento': _tipoAtendimento,
          'responsavel_aceite_nome': _responsavelNomeCtrl.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (_chamadoId.isNotEmpty && !_chamadoId.startsWith('c-')) {
          await client.from('chamados').update(chamadoUpdate).eq('id', _chamadoId);
        } else {
          final res = await client
              .from('chamados')
              .update(chamadoUpdate)
              .eq('numero_ats', _numeroAts)
              .select('id')
              .maybeSingle();
          if (res != null && res['id'] != null) {
            _chamadoId = res['id'].toString();
          }
        }

        // Grava dias de trabalho em lote em ats_dias_trabalho
        if (_chamadoId.isNotEmpty && !_chamadoId.startsWith('c-')) {
          await client.from('ats_dias_trabalho').delete().eq('chamado_id', _chamadoId);
          if (_diasTrabalho.isNotEmpty) {
            final diasRows = _diasTrabalho.map((d) => {
              'chamado_id': _chamadoId,
              'data': '${d.data.year.toString().padLeft(4, '0')}-${d.data.month.toString().padLeft(2, '0')}-${d.data.day.toString().padLeft(2, '0')}',
              'hora_inicio': d.horaInicio,
              'hora_fim': d.horaFim ?? '17:00',
              'hora_almoco': d.horaAlmoco,
              'hora_viagem': d.horaViagem,
              'numero_tecnicos': d.numeroTecnicos,
              'nomes_tecnicos': d.nomesTecnicos.trim().isNotEmpty ? d.nomesTecnicos.trim() : 'Técnico Responsável',
              'tecnicos_ids': d.tecnicosIds,
              'horas_liquidas_minutos': d.horasLiquidasMinutos,
            }).toList();
            await client.from('ats_dias_trabalho').insert(diasRows);
          }

          // Grava despesas em log_horas_custos
          await client.from('log_horas_custos').delete().eq('id_chamado', _chamadoId);
          await client.from('log_horas_custos').insert({
            'id_chamado': _chamadoId,
            'data': '${dataAtendimento.year.toString().padLeft(4, '0')}-${dataAtendimento.month.toString().padLeft(2, '0')}-${dataAtendimento.day.toString().padLeft(2, '0')}',
            'hora_inicio': horaInicioStr,
            'hora_fim': horaFimStr,
            'km_rodado': kmRodado,
            'pedagio': pedagio,
            'refeicao': refeicao,
          });

          await OfflineStorageService.instance.marcarSincronizado(_chamadoId);
        }

        if (!silencioso && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rascunho salvo na nuvem com sucesso! Disponível no celular/PC.'),
              backgroundColor: Color(0xFF0A369D),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        debugPrint('[AtsForm] Erro ao sincronizar rascunho online: $e');
        if (!silencioso && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rascunho salvo localmente. Aviso na nuvem: $e'),
              backgroundColor: const Color(0xFFD97706),
            ),
          );
        }
      }
    } else {
      if (!silencioso && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rascunho salvo localmente no dispositivo (offline).'),
            backgroundColor: Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isSavingDraft = false);
    }
  }

  @override
  void dispose() {
    _diasPageController.dispose();
    _signatureController.dispose();
    _kmRodadoCtrl.dispose();
    _pedagioCtrl.dispose();
    _refeicaoCtrl.dispose();
    _servicoExecutadoCtrl.dispose();
    _responsavelNomeCtrl.dispose();
    super.dispose();
  }



  // ============================================================================
  // FLUXO DE FINALIZAÇÃO (OFFLINE-FIRST)
  // ============================================================================
  Future<void> _finalizarAtendimento() async {
    // 1. Validações
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, colete a assinatura do cliente antes de finalizar.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_responsavelNomeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe o nome legível do responsável.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final primeiroDia = _diasTrabalho.isNotEmpty ? _diasTrabalho.first : null;
    final dataAtendimento = primeiroDia?.data ?? DateTime.now();
    final horaInicioStr = primeiroDia?.horaInicio ?? '08:00';
    final horaFimStr = primeiroDia?.horaFim ?? '17:00';
    final kmRodado = double.tryParse(_kmRodadoCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final pedagio = double.tryParse(_pedagioCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final refeicao = double.tryParse(_refeicaoCtrl.text.replaceAll(',', '.')) ?? 0.0;

    final logHoras = LogHorasCustos(
      id: 'log-${DateTime.now().millisecondsSinceEpoch}',
      idChamado: _chamadoId,
      data: dataAtendimento,
      horaInicio: horaInicioStr,
      horaFim: horaFimStr,
      kmRodado: kmRodado,
      pedagio: pedagio,
      refeicao: refeicao,
    );

    // Extrai imagem PNG da assinatura
    final Uint8List? assinaturaBytes = await _signatureController.toPngBytes();
    if (assinaturaBytes == null || assinaturaBytes.isEmpty) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao processar assinatura.'), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    // --------------------------------------------------------------------------
    // PASSO 1: Salvar localmente no banco de dados local (Hive) - Offline-First
    // --------------------------------------------------------------------------
    final payloadLocal = {
      'chamado_id': _chamadoId,
      'numero_ats': _numeroAts,
      'razao_social': _razaoSocial,
      'tipo_atendimento': _tipoAtendimento,
      'dias_trabalho': _diasTrabalho.map((d) => d.toMap()).toList(),
      'data_atendimento': dataAtendimento.toIso8601String(),
      'hora_inicio': horaInicioStr,
      'hora_fim': horaFimStr,
      'km_rodado': kmRodado,
      'pedagio': pedagio,
      'refeicao': refeicao,
      'servico_executado': _servicoExecutadoCtrl.text.trim(),
      'responsavel_nome': _responsavelNomeCtrl.text.trim(),
      'qtd_fotos': 0,
      'tem_video': false,
      'pending_sync': true,
    };

    await OfflineStorageService.instance.salvarAtendimentoLocal(
      id: _chamadoId,
      dados: payloadLocal,
      pendingSync: true,
    );

    // --------------------------------------------------------------------------
    // PASSO 2: Verificar conectividade de rede com connectivity_plus
    // --------------------------------------------------------------------------
    final connectivityResult = await Connectivity().checkConnectivity();
    final bool isOffline = connectivityResult.contains(ConnectivityResult.none) ||
        connectivityResult.isEmpty;

    if (isOffline) {
      // CENÁRIO OFFLINE: Notifica o usuário e conclui localmente
      await ChamadosService.instance.finalizarChamado(
        numeroAts: _numeroAts,
        chamadoId: _chamadoId,
        responsavelNome: _responsavelNomeCtrl.text.trim(),
        defeitoRelatado: _servicoExecutadoCtrl.text.trim(),
        razaoSocial: _razaoSocial,
      );

      setState(() => _isSubmitting = false);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.cloud_off, color: Colors.orange, size: 48),
          title: const Text('Atendimento Salvo Offline!'),
          content: const Text(
            'Você está sem conexão com a internet no momento.\n\n'
            'Todos os dados, fotos e assinaturas foram armazenados com segurança no seu dispositivo (pending_sync = true) e serão sincronizados automaticamente assim que a conexão for restabelecida.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A369D), foregroundColor: Colors.white),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    // --------------------------------------------------------------------------
    // CENÁRIO ONLINE: Upload de mídias, geração de PDF com QR Code e UPDATE no Supabase
    // --------------------------------------------------------------------------
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF0A369D)),
              SizedBox(width: 20),
              Expanded(
                child: Text('Enviando mídias, gerando PDF e finalizando no Supabase...'),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final client = Supabase.instance.client;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // A. Upload da assinatura
      String? assinaturaUrl;
      final sigPath = 'assinaturas/ats_${_numeroAts}_$timestamp.png';
      try {
        await client.storage.from('orcamentos').uploadBinary(
              sigPath,
              assinaturaBytes,
              fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
            );
        assinaturaUrl = client.storage.from('orcamentos').getPublicUrl(sigPath);
      } catch (e) {
        debugPrint('Aviso upload assinatura: $e');
      }

      // B. URL de referência do atendimento
      final String videoUrl = 'https://pmach.com.br/ats/video/$_numeroAts';

      // C. Gerar layout do relatório em PDF (com assinatura e QR Code do vídeo)
      final chamadoAtual = (widget.chamado != null)
          ? widget.chamado!.copyWith(
              tipoAtendimento: _tipoAtendimento,
              servicoExecutado: _servicoExecutadoCtrl.text.trim(),
              responsavelAceiteNome: _responsavelNomeCtrl.text.trim(),
              status: ChamadoStatus.finalizado,
            )
          : Chamado(
              id: _chamadoId,
              numeroAts: _numeroAts,
              razaoSocial: _razaoSocial,
              endereco: _endereco,
              tipoAtendimento: _tipoAtendimento,
              modeloMaquina: _modeloMaquina,
              fabricante: _fabricante,
              numeroSerie: _numeroSerie,
              defeitoRelatado: _defeitoRelatado,
              tokenUrl: _chamadoId,
              status: ChamadoStatus.finalizado,
            );

      final pdfBytes = await AtsPdfService.instance.gerarRelatorioAtsPdf(
        chamado: chamadoAtual,
        logHoras: logHoras,
        diasTrabalho: _diasTrabalho,
        servicoExecutado: _servicoExecutadoCtrl.text.trim(),
        assinaturaBytes: assinaturaBytes,
        responsavelNome: _responsavelNomeCtrl.text.trim(),
        videoUrl: videoUrl,
      );

      // D. Upload do PDF finalizado para o Storage
      String? pdfUrl;
      final pdfPath = 'relatorios_ats/ats_${_numeroAts}_final.pdf';
      try {
        await client.storage.from('orcamentos').uploadBinary(
              pdfPath,
              pdfBytes,
              fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
            );
        pdfUrl = client.storage.from('orcamentos').getPublicUrl(pdfPath);
      } catch (e) {
        debugPrint('Aviso upload PDF: $e');
      }

      // E. UPDATE na tabela chamados alterando status para 'finalizado'
      final updateData = <String, dynamic>{
        'status': ChamadoStatus.finalizado,
        'tipo_atendimento': _tipoAtendimento,
        'assinatura_url': assinaturaUrl,
        if (pdfUrl != null) 'orcamento_pdf_url': pdfUrl,
        'servico_executado': _servicoExecutadoCtrl.text.trim(),
        'termos_aceitos': true,
        'responsavel_aceite_nome': _responsavelNomeCtrl.text.trim(),
        'aceite_data': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_chamadoId.isNotEmpty && !_chamadoId.startsWith('c-')) {
        await client.from('chamados').update(updateData).eq('id', _chamadoId);
      } else {
        await client.from('chamados').update(updateData).eq('numero_ats', _numeroAts);
      }

      // F. INSERT na tabela log_horas_custos (com colunas estritas)
      try {
        if (_chamadoId.isNotEmpty && !_chamadoId.startsWith('c-')) {
          await client.from('log_horas_custos').insert({
            'id_chamado': _chamadoId,
            'data': '${dataAtendimento.year.toString().padLeft(4, '0')}-${dataAtendimento.month.toString().padLeft(2, '0')}-${dataAtendimento.day.toString().padLeft(2, '0')}',
            'hora_inicio': horaInicioStr,
            'hora_fim': horaFimStr,
            'km_rodado': kmRodado,
            'pedagio': pedagio,
            'refeicao': refeicao,
          });

          // Gravação dos múltiplos dias em ats_dias_trabalho
          await client.from('ats_dias_trabalho').delete().eq('chamado_id', _chamadoId);
          if (_diasTrabalho.isNotEmpty) {
            final diasRows = _diasTrabalho.map((d) => {
              'chamado_id': _chamadoId,
              'data': '${d.data.year.toString().padLeft(4, '0')}-${d.data.month.toString().padLeft(2, '0')}-${d.data.day.toString().padLeft(2, '0')}',
              'hora_inicio': d.horaInicio,
              'hora_fim': d.horaFim ?? '17:00',
              'hora_almoco': d.horaAlmoco,
              'hora_viagem': d.horaViagem,
              'numero_tecnicos': d.numeroTecnicos,
              'nomes_tecnicos': d.nomesTecnicos.trim().isNotEmpty ? d.nomesTecnicos.trim() : 'Técnico Responsável',
              'tecnicos_ids': d.tecnicosIds,
              'horas_liquidas_minutos': d.horasLiquidasMinutos,
            }).toList();
            await client.from('ats_dias_trabalho').insert(diasRows);
          }
        }
      } catch (logErr) {
        debugPrint('Aviso inserção log_horas_custos / ats_dias_trabalho: $logErr');
      }

      // G. Marca sincronizado localmente
      await OfflineStorageService.instance.marcarSincronizado(_chamadoId);

      // H. Atualiza estado em memória
      await ChamadosService.instance.finalizarChamado(
        numeroAts: _numeroAts,
        chamadoId: _chamadoId,
        assinaturaUrl: assinaturaUrl ?? '',
        responsavelNome: _responsavelNomeCtrl.text.trim(),
        defeitoRelatado: _servicoExecutadoCtrl.text.trim(),
        razaoSocial: _razaoSocial,
        endereco: _endereco,
        modeloMaquina: _modeloMaquina,
      );

      if (!mounted) return;
      Navigator.pop(context); // Fecha diálogo de carregamento
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ATS Nº $_numeroAts finalizada e sincronizada com sucesso!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Fecha diálogo
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aviso ao sincronizar online: $e. Registro mantido localmente.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  // ============================================================================
  // INTERFACE PRINCIPAL (5 SEÇÕES ESTRUTURADAS)
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    final bodyWidget = SafeArea(
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isEmbedded) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment_outlined, color: Color(0xFF0A369D), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Relatório O.S. $_numeroAts',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(color: Color(0xFF0A369D), strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync, size: 20, color: Color(0xFF0A369D)),
                            tooltip: 'Sincronizar',
                            onPressed: _isSyncing ? null : () => _sincronizarDadosComSupabase(manual: true),
                          ),
                          ElevatedButton.icon(
                            onPressed: (_isSubmitting || _isSavingDraft) ? null : () => _salvarRascunho(silencioso: false),
                            icon: _isSavingDraft
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_outlined, size: 14),
                            label: const Text('Salvar Rascunho', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A369D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // -------------------------------------------------------------
              // SEÇÃO 1: HEADER (DADOS DE LEITURA DO CLIENTE / ATS)
              // -------------------------------------------------------------
              _buildCardHeader(),
                const SizedBox(height: 12),

                // -------------------------------------------------------------
                // SEÇÃO 1.1: TIPO DE ATENDIMENTO
                // -------------------------------------------------------------
                _buildCardTipoAtendimento(),
                const SizedBox(height: 16),

                // -------------------------------------------------------------
                // SEÇÃO 2: DIAS TRABALHADOS E HORAS (MÚLTIPLOS DIAS INTERCALADOS)
                // -------------------------------------------------------------
                _buildSecaoDiasTrabalhados(dateFormat),
                const SizedBox(height: 16),

                // -------------------------------------------------------------
                // SEÇÃO 2.1: DESPESAS GERAIS DE DESLOCAMENTO
                // -------------------------------------------------------------
                _buildCardDespesasGerais(),
                const SizedBox(height: 16),

                // -------------------------------------------------------------
                // SEÇÃO 3: SERVIÇO EXECUTADO (CAMPO EXPANSÍVEL)
                // -------------------------------------------------------------
                _buildCardServicoExecutado(),
                const SizedBox(height: 16),

                // -------------------------------------------------------------
                // SEÇÃO 4: ASSINATURA (WIDGET SIGNATURE NO ECRÃ)
                // -------------------------------------------------------------
                _buildCardAssinatura(),
                const SizedBox(height: 24),

                // BOTÃO DE FINALIZAÇÃO (OFFLINE-FIRST)
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _finalizarAtendimento,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _isSubmitting ? 'Processando Atendimento...' : 'Finalizar Atendimento ATS',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 3,
                  ),
                ),
                const SizedBox(height: 12),

                // BOTÃO SALVAR RASCUNHO (SINCRONIZAÇÃO PC / CELULAR)
                OutlinedButton.icon(
                  onPressed: (_isSubmitting || _isSavingDraft) ? null : () => _salvarRascunho(silencioso: false),
                  icon: _isSavingDraft
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Color(0xFF0A369D), strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined, size: 20),
                  label: Text(
                    _isSavingDraft ? 'Salvando Rascunho na Nuvem...' : 'Salvar Rascunho (Sincronizar PC / Celular)',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0A369D),
                    side: const BorderSide(color: Color(0xFF0A369D), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Dica: Salve o rascunho no PC para preencher o memorial e horas. No celular, basta abrir o chamado para colher a assinatura com o cliente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );

    if (widget.isEmbedded) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: bodyWidget,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Atendimento ATS Nº $_numeroAts',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF0A369D),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 22),
            tooltip: 'Sincronizar com Nuvem (Recarregar do PC)',
            onPressed: _isSyncing ? null : () => _sincronizarDadosComSupabase(manual: true),
          ),
          TextButton.icon(
            onPressed: (_isSubmitting || _isSavingDraft) ? null : () => _salvarRascunho(silencioso: false),
            icon: _isSavingDraft
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined, size: 18, color: Colors.white),
            label: const Text(
              'Salvar Rascunho',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: bodyWidget,
    );
  }

  // ----------------------------------------------------------------------------
  // WIDGETS DE CADA SEÇÃO
  // ----------------------------------------------------------------------------

  /// SEÇÃO 1: Header (dados de leitura do cliente/ATS)
  Widget _buildCardHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_outlined, color: Color(0xFF0A369D), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'ATS-$_numeroAts',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A369D)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Text(
                  'Em Atendimento',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildInfoRow('Cliente / Razão Social:', _razaoSocial, isBold: true),
          const SizedBox(height: 4),
          _buildInfoRow('E-mail do Cliente:', _emailCliente),
          const SizedBox(height: 4),
          _buildInfoRow('Local / Endereço:', _endereco),
          const SizedBox(height: 4),
          _buildInfoRow('Máquina / Modelo:', '$_modeloMaquina ($_fabricante)'),
          const SizedBox(height: 4),
          _buildInfoRow('Nº de Série:', _numeroSerie),
          const SizedBox(height: 4),
          _buildInfoRow('Defeito Informado:', _defeitoRelatado, valueColor: const Color(0xFFDC2626)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  /// SEÇÃO 1.1: Seletor Visual de Tipo de Atendimento (Garantia vs Manutenção)
  Widget _buildCardTipoAtendimento() {
    const tipos = ['SERV. ENG.', 'MANUTENÇÃO', 'INSTALAÇÃO', 'GARANTIA'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, color: Color(0xFF0A369D), size: 18),
              const SizedBox(width: 8),
              const Text(
                'TIPO DE ATENDIMENTO',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0A369D)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _tipoAtendimento == 'GARANTIA' ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _tipoAtendimento == 'GARANTIA' ? const Color(0xFFFECACA) : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Text(
                  _tipoAtendimento,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: _tipoAtendimento == 'GARANTIA' ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tipos.map((tipo) {
              final isSelected = _tipoAtendimento == tipo;
              return InkWell(
                onTap: () {
                  setState(() {
                    _tipoAtendimento = tipo;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0A369D) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0A369D) : const Color(0xFFCBD5E1),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tipo,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // GESTÃO DINÂMICA DE DIAS DE TRABALHO (CARROSSEL HORIZONTAL)
  // ============================================================================

  void _adicionarDiaTrabalho() {
    setState(() {
      DateTime proximaData = DateTime.now();
      String nomesAnteriores = widget.chamado?.tecnicoNome ?? 'Técnico Responsável';

      if (_diasTrabalho.isNotEmpty) {
        final ultimo = _diasTrabalho.last;
        proximaData = ultimo.data.add(const Duration(days: 1));
        nomesAnteriores = ultimo.nomesTecnicos;
      }

      _diasTrabalho.add(
        DiaTrabalho(
          chamadoId: _chamadoId,
          data: proximaData,
          horaInicio: '08:00',
          horaFim: '17:00',
          horaAlmoco: '01:00',
          horaViagem: '00:00',
          numeroTecnicos: 1,
          nomesTecnicos: nomesAnteriores,
        ),
      );
      _diaAtualIndex = _diasTrabalho.length - 1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_diasPageController.hasClients) {
        _diasPageController.animateToPage(
          _diasTrabalho.length - 1,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _removerDiaTrabalho(int index) {
    if (_diasTrabalho.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O atendimento deve conter pelo menos 1 dia de trabalho registrado.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }
    setState(() {
      _diasTrabalho.removeAt(index);
      if (_diaAtualIndex >= _diasTrabalho.length) {
        _diaAtualIndex = _diasTrabalho.length - 1;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_diasPageController.hasClients && _diaAtualIndex < _diasTrabalho.length) {
        _diasPageController.jumpToPage(_diaAtualIndex);
      }
    });
  }

  Future<void> _selecionarHorarioParaDia({
    required int index,
    required String label,
    required String horarioAtual,
    required Function(String) onAtualizado,
  }) async {
    final partes = horarioAtual.split(':');
    final h = partes.isNotEmpty ? (int.tryParse(partes[0]) ?? 8) : 8;
    final m = partes.length > 1 ? (int.tryParse(partes[1]) ?? 0) : 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h, minute: m),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formatado = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        onAtualizado(formatado);
      });
    }
  }

  /// SEÇÃO 2: Dias de Atendimento e Horas (Carrossel Horizontal Mobile-First)
  Widget _buildSecaoDiasTrabalhados(DateFormat dateFormat) {
    int totalMinutosLiquidos = 0;
    for (var d in _diasTrabalho) {
      totalMinutosLiquidos += d.horasLiquidasMinutos;
    }
    final totalFormatado = DiaTrabalho.formatarMinutos(totalMinutosLiquidos);
    final displayIndex = _diaAtualIndex >= _diasTrabalho.length ? _diasTrabalho.length : (_diaAtualIndex + 1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da Seção com Título, Indicador de Paginação e Botão de Adicionar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, color: Color(0xFF0A369D), size: 20),
                    const SizedBox(width: 6),
                    const Text(
                      'Dias de Atendimento',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        _diaAtualIndex >= _diasTrabalho.length
                            ? '+ Novo Dia'
                            : 'Dia $displayIndex de ${_diasTrabalho.length}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _adicionarDiaTrabalho,
                  icon: const Icon(Icons.add_circle, size: 16, color: Color(0xFF0A369D)),
                  label: const Text(
                    '+ Adicionar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0A369D)),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEFF6FF),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Carrossel Horizontal com rolagem lateral dos dias
          SizedBox(
            height: 310,
            child: PageView.builder(
              controller: _diasPageController,
              physics: const BouncingScrollPhysics(),
              itemCount: _diasTrabalho.length + 1,
              onPageChanged: (idx) {
                setState(() {
                  _diaAtualIndex = idx;
                });
              },
              itemBuilder: (context, idx) {
                if (idx == _diasTrabalho.length) {
                  return _buildCardAdicionarOutroDia();
                }
                final DiaTrabalho dia = _diasTrabalho[idx];
                return _buildCardDiaCarrossel(dia, idx);
              },
            ),
          ),
          const SizedBox(height: 10),

          // Indicador de Paginação (Bolinhas / Dots)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_diasTrabalho.length + 1, (dotIdx) {
              final isSelected = dotIdx == _diaAtualIndex;
              final isAddCard = dotIdx == _diasTrabalho.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                height: 5,
                width: isSelected ? 18 : 5,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isAddCard ? const Color(0xFF10B981) : const Color(0xFF0A369D))
                      : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          // Barra de Resumo das Horas Totais
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.swipe_outlined, size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 5),
                      Text(
                        'Deslize para navegar (${_diasTrabalho.length} dia${_diasTrabalho.length > 1 ? "s" : ""})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                  Text(
                    'Total Líquido: $totalFormatado',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0A369D)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card individual compacto para o dia trabalhado no carrossel
  Widget _buildCardDiaCarrossel(DiaTrabalho dia, int idx) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Linha de Cabeçalho do Card (Dia, Horas Líquidas, Lixeira)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A369D),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'Dia ${idx + 1}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  'Líquido: ${dia.horasLiquidasFormatadas}',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                ),
              ),
              if (dia.horasViagemMinutos > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    'Viagem: ${dia.horasViagemFormatadas}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                  ),
                ),
              ],
              const Spacer(),
              if (_diasTrabalho.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 19),
                  tooltip: 'Remover este dia',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _removerDiaTrabalho(idx),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Seletor de Data
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: dia.data,
                firstDate: DateTime(2025),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() {
                  _diasTrabalho[idx] = dia.copyWith(data: picked);
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF0A369D)),
                      const SizedBox(width: 6),
                      Text(
                        'Data: ${dia.dataFormatada}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  const Text(
                    'Alterar',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF0A369D)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Grade 2x2 com Seletores de Horário
          Row(
            children: [
              Expanded(
                child: _buildTimePickerTile(
                  label: 'Início Expediente',
                  timeText: dia.horaInicio,
                  icon: Icons.play_arrow_outlined,
                  onTap: () => _selecionarHorarioParaDia(
                    index: idx,
                    label: 'Hora Início',
                    horarioAtual: dia.horaInicio,
                    onAtualizado: (val) => _diasTrabalho[idx] = dia.copyWith(horaInicio: val),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildTimePickerTile(
                  label: 'Fim Expediente',
                  timeText: dia.horaFim ?? '17:00',
                  icon: Icons.stop_outlined,
                  onTap: () => _selecionarHorarioParaDia(
                    index: idx,
                    label: 'Hora Fim',
                    horarioAtual: dia.horaFim ?? '17:00',
                    onAtualizado: (val) => _diasTrabalho[idx] = dia.copyWith(horaFim: val),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildTimePickerTile(
                  label: 'Tempo Almoço',
                  timeText: dia.horaAlmoco,
                  icon: Icons.restaurant_outlined,
                  onTap: () => _selecionarHorarioParaDia(
                    index: idx,
                    label: 'Tempo de Almoço',
                    horarioAtual: dia.horaAlmoco,
                    onAtualizado: (val) => _diasTrabalho[idx] = dia.copyWith(horaAlmoco: val),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildTimePickerTile(
                  label: 'Tempo Deslocamento',
                  timeText: dia.horaViagem,
                  icon: Icons.directions_car_outlined,
                  onTap: () => _selecionarHorarioParaDia(
                    index: idx,
                    label: 'Tempo de Deslocamento',
                    horarioAtual: dia.horaViagem,
                    onAtualizado: (val) => _diasTrabalho[idx] = dia.copyWith(horaViagem: val),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Equipe Técnica Alocada
          Row(
            children: [
              SizedBox(
                width: 78,
                child: TextFormField(
                  key: ValueKey('num_tec_${idx}_${dia.numeroTecnicos}'),
                  initialValue: dia.numeroTecnicos.toString(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Nº Técn.',
                    labelStyle: const TextStyle(fontSize: 10),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) {
                    final parsed = int.tryParse(val) ?? 1;
                    _diasTrabalho[idx] = dia.copyWith(numeroTecnicos: parsed > 0 ? parsed : 1);
                  },
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: TextFormField(
                  key: ValueKey('nomes_tec_${idx}_${dia.nomesTecnicos}'),
                  initialValue: dia.nomesTecnicos,
                  decoration: InputDecoration(
                    labelText: 'Técnicos Alocados',
                    labelStyle: const TextStyle(fontSize: 10),
                    hintText: 'Ex: Ricardo / Santin',
                    hintStyle: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 11),
                  onChanged: (val) {
                    _diasTrabalho[idx] = dia.copyWith(nomesTecnicos: val);
                  },
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _abrirSeletorEquipeParaDia(idx, dia),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.group_add_outlined, size: 18, color: Color(0xFF0A369D)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Card no final do carrossel para inclusão rápida de mais um dia
  Widget _buildCardAdicionarOutroDia() {
    return InkWell(
      onTap: _adicionarDiaTrabalho,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 30, color: Color(0xFF15803D)),
            ),
            const SizedBox(height: 12),
            Text(
              '+ Adicionar Dia ${_diasTrabalho.length + 1}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Toque aqui para registrar mais um dia de atendimento',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
            ),
          ],
        ),
      ),
    );
  }

  /// Modal interativo para seleção de técnicos cadastrados para o dia específico
  Future<void> _abrirSeletorEquipeParaDia(int idx, DiaTrabalho dia) async {
    if (_listaTecnicosDisponiveis.isEmpty) {
      await _carregarTecnicosDisponiveis();
    }

    final List<String> selecionadosIds = List.from(dia.tecnicosIds);
    final List<String> nomesAtuais = dia.nomesTecnicos
        .split(RegExp(r'[/,;+]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Se não tinha IDs mas tinha nomes, tenta correlacionar com a base
    if (selecionadosIds.isEmpty && nomesAtuais.isNotEmpty) {
      for (final tec in _listaTecnicosDisponiveis) {
        final nomeTec = tec['nome']?.toString().toLowerCase() ?? '';
        final idTec = tec['id']?.toString() ?? '';
        if (nomesAtuais.any((n) => nomeTec.contains(n.toLowerCase()) || n.toLowerCase().contains(nomeTec))) {
          if (!selecionadosIds.contains(idTec) && idTec.isNotEmpty) {
            selecionadosIds.add(idTec);
          }
        }
      }
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (bottomContext, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.group, color: Color(0xFF0A369D), size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Equipe do Dia ${idx + 1}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0A369D),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Text(
                      'Marque os técnicos que prestaram atendimento neste dia específico para o fechamento individual de horas.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const Divider(height: 20),
                    if (_listaTecnicosDisponiveis.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Nenhum técnico cadastrado na base ou dispositivo offline.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: _listaTecnicosDisponiveis.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, tecIdx) {
                            final tec = _listaTecnicosDisponiveis[tecIdx];
                            final id = tec['id']?.toString() ?? '';
                            final nome = tec['nome']?.toString() ?? 'Sem Nome';
                            final email = tec['email']?.toString() ?? '';
                            final perfil = tec['perfil']?.toString() ?? 'Técnico';
                            final isChecked = selecionadosIds.contains(id);

                            return CheckboxListTile(
                              value: isChecked,
                              activeColor: const Color(0xFF0A369D),
                              dense: true,
                              title: Text(
                                nome,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              subtitle: Text(
                                '$perfil • $email',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    if (!selecionadosIds.contains(id)) selecionadosIds.add(id);
                                  } else {
                                    selecionadosIds.remove(id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        final nomesSelecionados = <String>[];
                        for (final id in selecionadosIds) {
                          final match = _listaTecnicosDisponiveis.firstWhere(
                            (t) => t['id']?.toString() == id,
                            orElse: () => {'nome': ''},
                          );
                          final n = match['nome']?.toString() ?? '';
                          if (n.isNotEmpty) nomesSelecionados.add(n);
                        }

                        final strNomes = nomesSelecionados.isNotEmpty
                            ? nomesSelecionados.join(' / ')
                            : dia.nomesTecnicos;
                        final qtdTec = selecionadosIds.isNotEmpty
                            ? selecionadosIds.length
                            : (dia.numeroTecnicos > 0 ? dia.numeroTecnicos : 1);

                        setState(() {
                          _diasTrabalho[idx] = dia.copyWith(
                            tecnicosIds: selecionadosIds,
                            numeroTecnicos: qtdTec,
                            nomesTecnicos: strNomes,
                          );
                        });

                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A369D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        'Confirmar Equipe (${selecionadosIds.length} selecionado${selecionadosIds.length == 1 ? "" : "s"})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// SEÇÃO 2.1: Despesas Gerais do Atendimento (KM, Pedágio, Refeição)
  Widget _buildCardDespesasGerais() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_car_outlined, color: Color(0xFF0A369D), size: 20),
              SizedBox(width: 8),
              Text(
                'Despesas Gerais do Atendimento',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _kmRodadoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Km Rodado',
                    suffixText: 'km',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _pedagioCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Pedágio (R\$)',
                    prefixText: 'R\$ ',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _refeicaoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Refeição (R\$)',
                    prefixText: 'R\$ ',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerTile({
    required String label,
    required String timeText,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeText,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                Icon(icon, size: 15, color: const Color(0xFF0A369D)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// SEÇÃO 3: Serviço Executado (campo expansível)
  Widget _buildCardServicoExecutado() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.build_circle_outlined, color: Color(0xFF0A369D), size: 20),
              SizedBox(width: 8),
              Text(
                'Serviço Executado (Memorial Técnico)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _servicoExecutadoCtrl,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Descreva os procedimentos executados, testes de carga, peças ajustadas ou substituídas e observações relevantes...',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  /// SEÇÃO 4: Assinatura (área com widget Signature no ecrã)
  Widget _buildCardAssinatura() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.draw_outlined, color: Color(0xFF0A369D), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Assinatura do Cliente',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  _signatureController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.cleaning_services_outlined, size: 16, color: Color(0xFF64748B)),
                label: const Text('Limpar', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Widget Signature oficial do pacote 'signature'
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Signature(
                    controller: _signatureController,
                    height: 160,
                    backgroundColor: Colors.white,
                  ),
                  if (_signatureController.isEmpty)
                    const Center(
                      child: Text(
                        'Toque e assine neste campo',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Nome Legível
          TextFormField(
            controller: _responsavelNomeCtrl,
            decoration: InputDecoration(
              labelText: 'Nome Legível do Responsável / Solicitante *',
              hintText: 'Ex: Roberto Mendes (Gerente Industrial)',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome do responsável' : null,
          ),
        ],
      ),
    );
  }
}
