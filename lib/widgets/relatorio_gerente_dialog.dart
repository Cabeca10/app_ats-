import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chamado.dart';
import '../models/dia_trabalho.dart';
import '../models/log_horas_custos.dart';
import '../models/relatorio_custos_gerente.dart';
import '../services/ats_pdf_service.dart';
import '../services/chamados_service.dart';
import '../services/offline_storage_service.dart';

/// Modal de fechamento de custos do atendimento preenchido pelo técnico após
/// concluir o serviço ("Relatório p/ Gerente"). Ao enviar, atualiza KM/despesas,
/// calcula o custo total gerado, regenera o PDF final e muda a barra do gerente
/// de Laranja para Verde.
class RelatorioGerenteDialog extends StatefulWidget {
  final Chamado chamado;

  const RelatorioGerenteDialog({super.key, required this.chamado});

  @override
  State<RelatorioGerenteDialog> createState() => _RelatorioGerenteDialogState();
}

class _RelatorioGerenteDialogState extends State<RelatorioGerenteDialog> {
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  bool _carregando = true;
  bool _salvando = false;

  late Chamado _chamadoAtual;
  List<DiaTrabalho> _diasTrabalho = [];
  DateTime _dataReferencia = DateTime.now();
  String _horaInicioRef = '08:00';
  String _horaFimRef = '17:00';

  // Auxiliar opcional para cálculo de KM (Saída / Chegada)
  final _kmSaidaCtrl = TextEditingController();
  final _kmChegadaCtrl = TextEditingController();

  // Controladores principais de custos e horas
  final _kmTotalCtrl = TextEditingController(text: '0.0');
  final _taxaKmCtrl = TextEditingController(text: '3.20');
  final _pedagioCtrl = TextEditingController(text: '0.00');
  final _refeicaoCtrl = TextEditingController(text: '0.00');
  final _hospedagemCtrl = TextEditingController(text: '0.00');
  final _pecasOutrosCtrl = TextEditingController(text: '0.00');

  final _horasNormaisCtrl = TextEditingController(text: '0.00');
  final _taxaNormalCtrl = TextEditingController(text: '306.00');
  final _horasExtrasCtrl = TextEditingController(text: '0.00');
  final _taxaExtraCtrl = TextEditingController(text: '459.00');
  final _horasEspeciaisCtrl = TextEditingController(text: '0.00');
  final _taxaEspecialCtrl = TextEditingController(text: '612.00');
  final _horasViagemCtrl = TextEditingController(text: '0.00');
  final _taxaViagemCtrl = TextEditingController(text: '306.00');

  final _observacoesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chamadoAtual = widget.chamado;
    for (final ctrl in [
      _kmTotalCtrl,
      _taxaKmCtrl,
      _pedagioCtrl,
      _refeicaoCtrl,
      _hospedagemCtrl,
      _pecasOutrosCtrl,
      _horasNormaisCtrl,
      _taxaNormalCtrl,
      _horasExtrasCtrl,
      _taxaExtraCtrl,
      _horasEspeciaisCtrl,
      _taxaEspecialCtrl,
      _horasViagemCtrl,
      _taxaViagemCtrl,
    ]) {
      ctrl.addListener(_recalcular);
    }
    _kmSaidaCtrl.addListener(_onKmSaidaChegadaChanged);
    _kmChegadaCtrl.addListener(_onKmSaidaChegadaChanged);

    _carregarDadosCompletos();
  }

  void _recalcular() {
    if (mounted) setState(() {});
  }

  void _onKmSaidaChegadaChanged() {
    final saida = _parseDouble(_kmSaidaCtrl.text);
    final chegada = _parseDouble(_kmChegadaCtrl.text);
    if (_kmSaidaCtrl.text.trim().isNotEmpty &&
        _kmChegadaCtrl.text.trim().isNotEmpty &&
        chegada >= saida) {
      final diff = (chegada - saida).toStringAsFixed(1);
      if (_kmTotalCtrl.text != diff) {
        _kmTotalCtrl.text = diff;
      }
    }
  }

  double _parseDouble(String raw, [double fallback = 0.0]) {
    final cleaned = raw.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return fallback;
    return double.tryParse(cleaned) ?? fallback;
  }

  @override
  void dispose() {
    _kmSaidaCtrl.dispose();
    _kmChegadaCtrl.dispose();
    _kmTotalCtrl.dispose();
    _taxaKmCtrl.dispose();
    _pedagioCtrl.dispose();
    _refeicaoCtrl.dispose();
    _hospedagemCtrl.dispose();
    _pecasOutrosCtrl.dispose();
    _horasNormaisCtrl.dispose();
    _taxaNormalCtrl.dispose();
    _horasExtrasCtrl.dispose();
    _taxaExtraCtrl.dispose();
    _horasEspeciaisCtrl.dispose();
    _taxaEspecialCtrl.dispose();
    _horasViagemCtrl.dispose();
    _taxaViagemCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosCompletos() async {
    double km = 0.0;
    double pedagio = 0.0;
    double refeicao = 0.0;
    double hospedagem = 0.0;
    double pecasOutros = 0.0;
    String observacoes = '';

    final local = OfflineStorageService.instance.obterAtendimento(_chamadoAtual.id);
    if (local != null) {
      km = (local['km_rodado'] as num?)?.toDouble() ??
          _parseDouble(local['km_rodado']?.toString() ?? '');
      pedagio = (local['pedagio'] as num?)?.toDouble() ??
          _parseDouble(local['pedagio']?.toString() ?? '');
      refeicao = (local['refeicao'] as num?)?.toDouble() ??
          _parseDouble(local['refeicao']?.toString() ?? '');
      hospedagem = (local['hospedagem'] as num?)?.toDouble() ??
          _parseDouble(local['hospedagem']?.toString() ?? '');
      pecasOutros = (local['outros_custos'] as num?)?.toDouble() ??
          _parseDouble(local['outros_custos']?.toString() ?? '');
      observacoes = local['observacoes']?.toString() ?? '';
      if (_chamadoAtual.diasTrabalho.isEmpty && local['dias_trabalho'] is List) {
        _diasTrabalho = (local['dias_trabalho'] as List)
            .map((e) => DiaTrabalho.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }

    if (_diasTrabalho.isEmpty) {
      _diasTrabalho = List<DiaTrabalho>.from(_chamadoAtual.diasTrabalho);
    }

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final online = !connectivity.contains(ConnectivityResult.none) && connectivity.isNotEmpty;
      if (online && _chamadoAtual.id.isNotEmpty && !_chamadoAtual.id.startsWith('c-')) {
        final client = Supabase.instance.client;
        final cRow = await client
            .from('chamados')
            .select(Chamado.selectColumnsCompletas)
            .eq('id', _chamadoAtual.id)
            .maybeSingle();
        if (cRow != null) {
          _chamadoAtual = Chamado.fromMap(Map<String, dynamic>.from(cRow));
        }

        final diasRes = await client
            .from('ats_dias_trabalho')
            .select()
            .eq('chamado_id', _chamadoAtual.id)
            .order('data', ascending: true)
            .order('hora_inicio', ascending: true);
        if (diasRes.isNotEmpty) {
          _diasTrabalho = (diasRes as List)
              .map((d) => DiaTrabalho.fromMap(Map<String, dynamic>.from(d as Map)))
              .toList();
        }

        final logRes = await client
            .from('log_horas_custos')
            .select()
            .eq('id_chamado', _chamadoAtual.id)
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (logRes != null) {
          km = (logRes['km_rodado'] as num?)?.toDouble() ?? km;
          pedagio = (logRes['pedagio'] as num?)?.toDouble() ?? pedagio;
          refeicao = (logRes['refeicao'] as num?)?.toDouble() ?? refeicao;
          hospedagem = (logRes['hospedagem'] as num?)?.toDouble() ?? hospedagem;
          pecasOutros = (logRes['outros_custos'] as num?)?.toDouble() ?? pecasOutros;
          if (logRes['observacoes'] != null && logRes['observacoes'].toString().trim().isNotEmpty) {
            observacoes = logRes['observacoes'].toString();
          }
          if (logRes['data'] != null) {
            _dataReferencia = DateTime.tryParse(logRes['data'].toString()) ?? _dataReferencia;
          }
          _horaInicioRef = logRes['hora_inicio']?.toString() ?? _horaInicioRef;
          _horaFimRef = logRes['hora_fim']?.toString() ?? _horaFimRef;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RelatorioGerenteDialog] Aviso ao sincronizar dados da nuvem: $e');
      }
    }

    if (_diasTrabalho.isNotEmpty) {
      _dataReferencia = _diasTrabalho.first.data;
      _horaInicioRef = _diasTrabalho.first.horaInicio;
      _horaFimRef = _diasTrabalho.first.horaFim ?? '17:00';
    }

    if (_chamadoAtual.relatorioCustosJson != null) {
      final salvo = RelatorioCustosGerente.fromMap(_chamadoAtual.relatorioCustosJson!);
      _kmTotalCtrl.text = salvo.kmRodado.toStringAsFixed(1);
      _taxaKmCtrl.text = salvo.taxaKm.toStringAsFixed(2);
      _pedagioCtrl.text = salvo.pedagio.toStringAsFixed(2);
      _refeicaoCtrl.text = salvo.refeicao.toStringAsFixed(2);
      _hospedagemCtrl.text = salvo.hospedagem.toStringAsFixed(2);
      _pecasOutrosCtrl.text = salvo.pecasOutros.toStringAsFixed(2);
      _horasNormaisCtrl.text = salvo.horasNormais.toStringAsFixed(2);
      _taxaNormalCtrl.text = salvo.taxaHoraNormal.toStringAsFixed(2);
      _horasExtrasCtrl.text = salvo.horasExtras.toStringAsFixed(2);
      _taxaExtraCtrl.text = salvo.taxaHoraExtra.toStringAsFixed(2);
      _horasEspeciaisCtrl.text = salvo.horasEspeciais.toStringAsFixed(2);
      _taxaEspecialCtrl.text = salvo.taxaHoraEspecial.toStringAsFixed(2);
      _horasViagemCtrl.text = salvo.horasViagem.toStringAsFixed(2);
      _taxaViagemCtrl.text = salvo.taxaHoraViagem.toStringAsFixed(2);
      _observacoesCtrl.text = salvo.observacoes ?? observacoes;
    } else {
      int totalMinutosTrab = 0;
      int totalMinutosViagem = 0;
      for (final d in _diasTrabalho) {
        final mult = d.numeroTecnicos > 0 ? d.numeroTecnicos : 1;
        totalMinutosTrab += d.horasLiquidasMinutos * mult;
        totalMinutosViagem += d.horasViagemMinutos * mult;
      }

      if (km <= 0 && (_chamadoAtual.kmEstimado ?? 0) > 0) {
        km = _chamadoAtual.kmEstimado!;
      }

      _kmTotalCtrl.text = km.toStringAsFixed(1);
      _taxaKmCtrl.text = _chamadoAtual.taxaKm.toStringAsFixed(2);
      _pedagioCtrl.text = pedagio.toStringAsFixed(2);
      _refeicaoCtrl.text = refeicao.toStringAsFixed(2);
      _hospedagemCtrl.text = hospedagem.toStringAsFixed(2);
      _pecasOutrosCtrl.text = pecasOutros.toStringAsFixed(2);

      _horasNormaisCtrl.text = (totalMinutosTrab / 60.0).toStringAsFixed(2);
      _taxaNormalCtrl.text = _chamadoAtual.taxaHorariaComercial.toStringAsFixed(2);
      _horasExtrasCtrl.text = '0.00';
      _taxaExtraCtrl.text = _chamadoAtual.taxaHorariaExtra.toStringAsFixed(2);
      _horasEspeciaisCtrl.text = '0.00';
      _taxaEspecialCtrl.text = _chamadoAtual.taxaHorariaEspecial.toStringAsFixed(2);
      _horasViagemCtrl.text = (totalMinutosViagem / 60.0).toStringAsFixed(2);
      _taxaViagemCtrl.text = _chamadoAtual.taxaHorariaComercial.toStringAsFixed(2);
      _observacoesCtrl.text = observacoes;
    }

    if (mounted) {
      setState(() => _carregando = false);
    }
  }

  RelatorioCustosGerente _construirCustosAtuais() {
    return RelatorioCustosGerente(
      horasNormais: _parseDouble(_horasNormaisCtrl.text),
      taxaHoraNormal: _parseDouble(_taxaNormalCtrl.text, _chamadoAtual.taxaHorariaComercial),
      horasExtras: _parseDouble(_horasExtrasCtrl.text),
      taxaHoraExtra: _parseDouble(_taxaExtraCtrl.text, _chamadoAtual.taxaHorariaExtra),
      horasEspeciais: _parseDouble(_horasEspeciaisCtrl.text),
      taxaHoraEspecial: _parseDouble(_taxaEspecialCtrl.text, _chamadoAtual.taxaHorariaEspecial),
      horasViagem: _parseDouble(_horasViagemCtrl.text),
      taxaHoraViagem: _parseDouble(_taxaViagemCtrl.text),
      kmRodado: _parseDouble(_kmTotalCtrl.text),
      taxaKm: _parseDouble(_taxaKmCtrl.text, _chamadoAtual.taxaKm),
      pedagio: _parseDouble(_pedagioCtrl.text),
      refeicao: _parseDouble(_refeicaoCtrl.text),
      hospedagem: _parseDouble(_hospedagemCtrl.text),
      pecasOutros: _parseDouble(_pecasOutrosCtrl.text),
      observacoes: _observacoesCtrl.text.trim(),
      enviadoEm: DateTime.now(),
    );
  }

  Future<Uint8List> _obterAssinaturaPreservadaBytes() async {
    final local = OfflineStorageService.instance.obterAtendimento(_chamadoAtual.id);
    if (local != null &&
        local['assinatura_png_base64'] != null &&
        local['assinatura_png_base64'].toString().isNotEmpty) {
      try {
        final decoded = base64Decode(local['assinatura_png_base64'].toString());
        if (decoded.length >= 8 &&
            decoded[0] == 0x89 &&
            decoded[1] == 0x50 &&
            decoded[2] == 0x4E &&
            decoded[3] == 0x47) {
          return decoded;
        }
      } catch (_) {}
    }

    final url = _chamadoAtual.assinaturaUrl?.trim();
    if (url != null && url.isNotEmpty && !url.contains('storage.local')) {
      try {
        String path = url;
        if (path.contains('/orcamentos/')) {
          path = path.split('/orcamentos/').last.split('?').first;
          try {
            path = Uri.decodeFull(path);
          } catch (_) {}
          path = path.replaceFirst(RegExp(r'^/+'), '').trim();
        }
        final downloaded = await Supabase.instance.client.storage
            .from('orcamentos')
            .download(path);
        if (downloaded.isNotEmpty) return downloaded;
      } catch (_) {}
    }

    // Fallback mínimo transparente 1x1 PNG
    return Uint8List.fromList([
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
      0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 11, 73, 68, 65, 84,
      120, 1, 99, 96, 0, 0, 0, 2, 0, 1, 244, 113, 100, 166, 0, 0, 0, 0, 73, 69,
      78, 68, 174, 66, 96, 130
    ]);
  }

  Future<void> _enviarRelatorioParaGerente() async {
    setState(() => _salvando = true);

    try {
      final custos = _construirCustosAtuais();
      final custosMap = custos.toMap();
      final totalGerado = custos.custoTotalGerado;
      final versao = _chamadoAtual.relatorioVersao > 0 ? _chamadoAtual.relatorioVersao : 1;

      final logHoras = LogHorasCustos(
        id: 'log-${DateTime.now().millisecondsSinceEpoch}',
        idChamado: _chamadoAtual.id,
        data: _dataReferencia,
        horaInicio: _horaInicioRef,
        horaFim: _horaFimRef,
        kmRodado: custos.kmRodado,
        pedagio: custos.pedagio,
        refeicao: custos.refeicao,
        hospedagem: custos.hospedagem,
        outrosCustos: custos.pecasOutros,
        observacoes: custos.observacoes,
      );

      // 1. Atualiza cache local no Hive
      final existingLocal = OfflineStorageService.instance.obterAtendimento(_chamadoAtual.id) ?? {};
      await OfflineStorageService.instance.salvarAtendimentoLocal(
        id: _chamadoAtual.id,
        dados: {
          ...existingLocal,
          'chamado_id': _chamadoAtual.id,
          'numero_ats': _chamadoAtual.numeroAts,
          'km_rodado': custos.kmRodado,
          'pedagio': custos.pedagio,
          'refeicao': custos.refeicao,
          'hospedagem': custos.hospedagem,
          'outros_custos': custos.pecasOutros,
          if (custos.observacoes != null) 'observacoes': custos.observacoes,
        },
        pendingSync: true,
      );

      final connectivity = await Connectivity().checkConnectivity();
      final isOffline = connectivity.contains(ConnectivityResult.none) || connectivity.isEmpty;

      String? pdfUrl = _chamadoAtual.relatorioPdfUrl;

      if (!isOffline) {
        final client = Supabase.instance.client;

        // 2. Atualiza log_horas_custos no Supabase
        if (_chamadoAtual.id.isNotEmpty && !_chamadoAtual.id.startsWith('c-')) {
          await client.from('log_horas_custos').delete().eq('id_chamado', _chamadoAtual.id);
          await client.from('log_horas_custos').insert({
            'id_chamado': _chamadoAtual.id,
            'data': '${_dataReferencia.year.toString().padLeft(4, '0')}-${_dataReferencia.month.toString().padLeft(2, '0')}-${_dataReferencia.day.toString().padLeft(2, '0')}',
            'hora_inicio': _horaInicioRef,
            'hora_fim': _horaFimRef,
            'km_rodado': custos.kmRodado,
            'pedagio': custos.pedagio,
            'refeicao': custos.refeicao,
            'hospedagem': custos.hospedagem,
            'outros_custos': custos.pecasOutros,
            if (custos.observacoes != null && custos.observacoes!.isNotEmpty)
              'observacoes': custos.observacoes,
          });
        }

        // 3. Regenera PDF da versão atual com Demonstrativo de Custos e Assinatura preservada
        try {
          final assinaturaBytes = await _obterAssinaturaPreservadaBytes();
          final pdfBytes = await AtsPdfService.instance.gerarRelatorioAtsPdf(
            chamado: _chamadoAtual,
            logHoras: logHoras,
            diasTrabalho: _diasTrabalho,
            servicoExecutado: (_chamadoAtual.servicoExecutado != null &&
                    _chamadoAtual.servicoExecutado!.trim().isNotEmpty)
                ? _chamadoAtual.servicoExecutado!.trim()
                : 'Atendimento e revisão técnica industrial concluídos.',
            assinaturaBytes: assinaturaBytes,
            responsavelNome: (_chamadoAtual.responsavelAceiteNome != null &&
                    _chamadoAtual.responsavelAceiteNome!.trim().isNotEmpty)
                ? _chamadoAtual.responsavelAceiteNome!.trim()
                : (_chamadoAtual.contato ?? 'Cliente Responsável'),
            videoUrl: _chamadoAtual.videoUrl ?? 'https://pmach.com.br/ats/video/${_chamadoAtual.numeroAts}',
            versao: versao,
            custosGerente: custos,
          );

          final cleanAts = _chamadoAtual.numeroAts.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          final pdfPath = 'relatorios_ats/ats_${cleanAts}_v$versao.pdf';
          final ts = DateTime.now().millisecondsSinceEpoch;
          await client.storage.from('orcamentos').uploadBinary(
                pdfPath,
                pdfBytes,
                fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
              );
          pdfUrl = '${client.storage.from('orcamentos').getPublicUrl(pdfPath)}?t=$ts';
        } catch (pdfErr) {
          if (kDebugMode) {
            debugPrint('[RelatorioGerenteDialog] Aviso ao atualizar PDF com custos: $pdfErr');
          }
        }

        await OfflineStorageService.instance.marcarSincronizado(_chamadoAtual.id);
      }

      // 4. Registra no chamado (relatorio_gerente_enviado = true -> Verde no Gerente)
      await ChamadosService.instance.registrarRelatorioGerente(
        chamadoId: _chamadoAtual.id,
        numeroAts: _chamadoAtual.numeroAts,
        custoTotalGerado: totalGerado,
        relatorioCustosJson: custosMap,
        relatorioPdfUrl: pdfUrl,
        relatorioVersao: versao,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Relatório p/ Gerente enviado! Custo total: ${_currencyFormat.format(totalGerado)}',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar relatório para o gerente: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildCampoNumero({
    required TextEditingController controller,
    required String label,
    String? prefixText,
    String? suffixText,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        prefixText: prefixText,
        suffixText: suffixText,
        helperText: helperText,
        helperStyle: const TextStyle(fontSize: 10),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0A369D)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final custos = _construirCustosAtuais();
    final atsLabel = _chamadoAtual.numeroAts.toUpperCase().startsWith('ATS-')
        ? _chamadoAtual.numeroAts
        : 'ATS-${_chamadoAtual.numeroAts}';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _chamadoAtual.relatorioGerenteEnviado
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.calculate_outlined,
              color: _chamadoAtual.relatorioGerenteEnviado
                  ? const Color(0xFF15803D)
                  : const Color(0xFFEA580C),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Relatório p/ Gerente • $atsLabel',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_chamadoAtual.razaoSocial} • ${_chamadoAtual.tipoAtendimento}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _salvando ? null : () => Navigator.pop(context, false),
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
      content: SizedBox(
        width: 660,
        child: _carregando
            ? const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator(color: Color(0xFF0A369D))),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Text(
                        'Atualize a quilometragem final (ida e volta ao chegar em casa), despesas e horas para enviar o custo total completo ao gerente cobrar o cliente.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // SEÇÃO 1: KM RODADO
                    _buildSectionTitle(Icons.directions_car_outlined, '1. Quilometragem (Ida e Volta)'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCampoNumero(
                            controller: _kmSaidaCtrl,
                            label: 'KM Saída (opcional)',
                            suffixText: 'km',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCampoNumero(
                            controller: _kmChegadaCtrl,
                            label: 'KM Chegada (opcional)',
                            suffixText: 'km',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildCampoNumero(
                            controller: _kmTotalCtrl,
                            label: 'KM Total Rodado *',
                            suffixText: 'km',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _buildCampoNumero(
                            controller: _taxaKmCtrl,
                            label: 'Taxa / KM (R\$)',
                            prefixText: 'R\$ ',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Subtotal KM', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                Text(
                                  _currencyFormat.format(custos.subtotalKm),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0A369D)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // SEÇÃO 2: DESPESAS EXTRAS
                    _buildSectionTitle(Icons.receipt_long_outlined, '2. Despesas do Atendimento'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCampoNumero(
                            controller: _pedagioCtrl,
                            label: 'Pedágio (R\$)',
                            prefixText: 'R\$ ',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCampoNumero(
                            controller: _refeicaoCtrl,
                            label: 'Refeição (R\$)',
                            prefixText: 'R\$ ',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCampoNumero(
                            controller: _hospedagemCtrl,
                            label: 'Hospedagem / Estadia',
                            prefixText: 'R\$ ',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCampoNumero(
                            controller: _pecasOutrosCtrl,
                            label: 'Peças / Outros Custos',
                            prefixText: 'R\$ ',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // SEÇÃO 3: HORAS APONTADAS E TAXAS
                    _buildSectionTitle(Icons.schedule_outlined, '3. Horas Apontadas e Valores Unitários'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCampoNumero(
                            controller: _horasNormaisCtrl,
                            label: 'Horas Comerciais',
                            suffixText: 'h',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCampoNumero(
                            controller: _taxaNormalCtrl,
                            label: 'Valor/h Normal',
                            prefixText: 'R\$ ',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCampoNumero(
                            controller: _horasExtrasCtrl,
                            label: 'Horas Extras (+50%)',
                            suffixText: 'h',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCampoNumero(
                            controller: _taxaExtraCtrl,
                            label: 'Valor/h Extra',
                            prefixText: 'R\$ ',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCampoNumero(
                            controller: _horasEspeciaisCtrl,
                            label: 'Horas Especiais (+100%)',
                            suffixText: 'h',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCampoNumero(
                            controller: _taxaEspecialCtrl,
                            label: 'Valor/h Especial',
                            prefixText: 'R\$ ',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCampoNumero(
                            controller: _horasViagemCtrl,
                            label: 'Horas de Viagem',
                            suffixText: 'h',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCampoNumero(
                            controller: _taxaViagemCtrl,
                            label: 'Valor/h Viagem',
                            prefixText: 'R\$ ',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // SEÇÃO 4: OBSERVAÇÕES
                    TextFormField(
                      controller: _observacoesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Observações de fechamento p/ o Gerente (opcional)',
                        hintText: 'Ex: KM atualizado após retorno; peça substituída conforme OS...',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(10),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 14),

                    // RESUMO EM TEMPO REAL
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Horas (Mão de Obra + Viagem):',
                                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5)),
                              Text(_currencyFormat.format(custos.subtotalHorasTotal),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Deslocamento (${custos.kmRodado.toStringAsFixed(1)} km):',
                                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5)),
                              Text(_currencyFormat.format(custos.subtotalKm),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Despesas Extras + Peças:',
                                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5)),
                              Text(_currencyFormat.format(custos.subtotalDespesasExtras),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                            ],
                          ),
                          const Divider(color: Color(0xFF334155), height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'CUSTO TOTAL GERADO:',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              Text(
                                _currencyFormat.format(custos.custoTotalGerado),
                                style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 17),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: (_carregando || _salvando) ? null : _enviarRelatorioParaGerente,
          icon: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded, size: 17),
          label: Text(_salvando ? 'Enviando...' : 'Enviar Relatório p/ Gerente'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
