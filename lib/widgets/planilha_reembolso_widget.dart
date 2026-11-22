import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/planilha_reembolso.dart';
import '../services/planilha_pdf_service.dart';
import '../services/planilha_reembolso_service.dart';

/// Dashboard interativo da Planilha Mensal de Reembolso (Técnico e Gerente),
/// espelhando fielmente colunas diárias, taxas e quadro resumo por categoria.
class PlanilhaReembolsoWidget extends StatefulWidget {
  final String tecnicoId;
  final String tecnicoNome;
  final bool isGerente;
  final int? initialAno;
  final int? initialMes;
  final VoidCallback? onVoltar;
  final ValueChanged<PlanilhaReembolso>? onPlanilhaAtualizada;

  const PlanilhaReembolsoWidget({
    super.key,
    required this.tecnicoId,
    required this.tecnicoNome,
    required this.isGerente,
    this.initialAno,
    this.initialMes,
    this.onVoltar,
    this.onPlanilhaAtualizada,
  });

  @override
  State<PlanilhaReembolsoWidget> createState() => _PlanilhaReembolsoWidgetState();
}

class _PlanilhaReembolsoWidgetState extends State<PlanilhaReembolsoWidget> {
  late int _ano;
  late int _mes;
  PlanilhaReembolso? _planilha;
  bool _carregando = true;
  bool _processando = false;
  bool _mostrarTodosDiasMes = true;
  String? _erroCarregamento;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _ano = widget.initialAno ?? agora.year;
    _mes = widget.initialMes ?? agora.month;
    _carregarPlanilha();
  }

  @override
  void didUpdateWidget(covariant PlanilhaReembolsoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final mudouTecnico = oldWidget.tecnicoId != widget.tecnicoId;
    final mudouPeriodo =
        (widget.initialAno != null && widget.initialAno != oldWidget.initialAno) ||
            (widget.initialMes != null && widget.initialMes != oldWidget.initialMes);

    if (mudouTecnico || mudouPeriodo) {
      if (widget.initialAno != null) _ano = widget.initialAno!;
      if (widget.initialMes != null) _mes = widget.initialMes!;
      _carregarPlanilha();
    }
  }

  Future<void> _carregarPlanilha() async {
    if (widget.tecnicoId.trim().isEmpty) {
      setState(() {
        _carregando = false;
        _erroCarregamento = 'Identificação do técnico indisponível. Faça login novamente.';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _erroCarregamento = null;
    });

    try {
      final p = await PlanilhaReembolsoService.instance.obterOuCriarPlanilha(
        tecnicoId: widget.tecnicoId,
        tecnicoNome: widget.tecnicoNome,
        ano: _ano,
        mes: _mes,
      );
      if (mounted) {
        setState(() {
          _planilha = p;
          _carregando = false;
        });
        widget.onPlanilhaAtualizada?.call(p);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erroCarregamento = 'Erro ao carregar planilha: $e';
        });
      }
    }
  }

  void _alterarMes(int delta) {
    var novoMes = _mes + delta;
    var novoAno = _ano;
    if (novoMes < 1) {
      novoMes = 12;
      novoAno--;
    } else if (novoMes > 12) {
      novoMes = 1;
      novoAno++;
    }
    setState(() {
      _mes = novoMes;
      _ano = novoAno;
    });
    _carregarPlanilha();
  }

  Future<void> _importarDasAts() async {
    final planilha = _planilha;
    if (planilha == null) return;

    setState(() => _processando = true);
    try {
      final importados = await PlanilhaReembolsoService.instance.importarAtendimentosAtsDoMes(
        planilha: planilha,
      );
      await _carregarPlanilha();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              importados > 0
                  ? '$importados atendimento(s) das ATS importado(s) para a planilha!'
                  : 'Nenhum novo atendimento das ATS encontrado para este mês.',
            ),
            backgroundColor: importados > 0 ? const Color(0xFF10B981) : const Color(0xFF0A369D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar atendimentos ATS: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  Future<void> _exportarPdf() async {
    final planilha = _planilha;
    if (planilha == null) return;

    setState(() => _processando = true);
    try {
      final bytes = await PlanilhaPdfService.instance.gerarPdf(planilha);
      final nomeSeguro = planilha.tecnicoNome.trim().replaceAll(RegExp(r'\s+'), '_');
      await Printing.layoutPdf(
        onLayout: (_) => bytes,
        name: 'Planilha_Reembolso_${nomeSeguro}_${planilha.mes.toString().padLeft(2, '0')}_${planilha.ano}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF da planilha: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  Future<void> _copiarCsv() async {
    final planilha = _planilha;
    if (planilha == null) return;
    final csv = planilha.gerarCsvExcel();
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Planilha em formato CSV (Excel) copiada para a área de transferência!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _enviarParaGerente() async {
    final planilha = _planilha;
    if (planilha == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.send_rounded, color: Color(0xFF0A369D)),
            SizedBox(width: 8),
            Expanded(child: Text('Enviar Planilha ao Gerente?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          'Período: ${planilha.nomeMesAno}\n'
          'Lançamentos: ${planilha.itens.length}\n'
          'Total KM: ${formatarNumeroBr(planilha.totalGeralKm)} km\n'
          'Total a Receber: ${formatarMoedaBr(planilha.totalGeralReceber)}\n\n'
          'O gerente receberá o status "Enviada ao Gerente" para conferência e pagamento.',
          style: const TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Confirmar Envio'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _processando = true);
    try {
      final atualizada = await PlanilhaReembolsoService.instance.enviarParaGerente(planilha);
      if (mounted) {
        setState(() => _planilha = atualizada);
        widget.onPlanilhaAtualizada?.call(atualizada);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Planilha enviada para conferência do Gerente com sucesso!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar planilha: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  Future<void> _gerenteAlterarStatus(String novoStatus) async {
    final planilha = _planilha;
    if (planilha == null) return;

    final obsCtrl = TextEditingController(text: planilha.observacaoGerente);
    final isAprovacao = novoStatus == StatusPlanilha.aprovada;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(
              isAprovacao ? Icons.verified_rounded : Icons.edit_note_rounded,
              color: isAprovacao ? const Color(0xFF10B981) : const Color(0xFFD97706),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isAprovacao ? 'Aprovar Reembolso?' : 'Devolver para Ajuste?',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Técnico: ${planilha.tecnicoNome}\nPeríodo: ${planilha.nomeMesAno}\nTotal calculado: ${formatarMoedaBr(planilha.totalGeralReceber)}',
                style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: obsCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: isAprovacao ? 'Observação (opcional)' : 'Motivo / Ajuste solicitado',
                  hintText: isAprovacao
                      ? 'Ex: Conferido e liberado para pagamento dia 15.'
                      : 'Ex: Verificar KM informado no dia 14.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isAprovacao ? const Color(0xFF10B981) : const Color(0xFFD97706),
              foregroundColor: Colors.white,
            ),
            child: Text(isAprovacao ? 'Confirmar Aprovação' : 'Solicitar Ajuste'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) {
      obsCtrl.dispose();
      return;
    }

    final obsText = obsCtrl.text;
    obsCtrl.dispose();

    setState(() => _processando = true);
    try {
      final atualizada = await PlanilhaReembolsoService.instance.atualizarStatusGerente(
        planilha: planilha,
        status: novoStatus,
        observacao: obsText,
      );
      if (mounted) {
        setState(() => _planilha = atualizada);
        widget.onPlanilhaAtualizada?.call(atualizada);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAprovacao
                  ? 'Planilha aprovada para reembolso!'
                  : 'Planilha devolvida para ajuste do técnico.',
            ),
            backgroundColor: isAprovacao ? const Color(0xFF10B981) : const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar status da planilha: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  double _parseDecimal(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0.0;
  }

  Future<void> _abrirModalEditarTaxas() async {
    final planilha = _planilha;
    if (planilha == null) return;

    final kmCtrl = TextEditingController(text: planilha.valorKm.toStringAsFixed(2));
    final kmInternoCtrl = TextEditingController(text: planilha.valorKmInterno.toStringAsFixed(2));
    final horaTecCtrl = TextEditingController(text: planilha.valorHoraTecnica.toStringAsFixed(2));
    final horaViagemCtrl = TextEditingController(text: planilha.valorHoraViagem.toStringAsFixed(2));

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: Color(0xFF0A369D)),
            SizedBox(width: 8),
            Text('Editar Taxas da Planilha', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: kmCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Valor do km (R\$)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: kmInternoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Valor do km interno (Pmach Interno) (R\$)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: horaTecCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Valor Hora técnica (R\$)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: horaViagemCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Valor hora viagem (R\$)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A369D), foregroundColor: Colors.white),
            child: const Text('Salvar Taxas'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) {
      kmCtrl.dispose();
      kmInternoCtrl.dispose();
      horaTecCtrl.dispose();
      horaViagemCtrl.dispose();
      return;
    }

    final atualizadaLocal = planilha.copyWith(
      valorKm: _parseDecimal(kmCtrl.text),
      valorKmInterno: _parseDecimal(kmInternoCtrl.text),
      valorHoraTecnica: _parseDecimal(horaTecCtrl.text),
      valorHoraViagem: _parseDecimal(horaViagemCtrl.text),
    );

    kmCtrl.dispose();
    kmInternoCtrl.dispose();
    horaTecCtrl.dispose();
    horaViagemCtrl.dispose();

    setState(() => _processando = true);
    try {
      final salva = await PlanilhaReembolsoService.instance.atualizarParametrosPlanilha(atualizadaLocal);
      if (mounted) {
        setState(() => _planilha = salva);
        widget.onPlanilhaAtualizada?.call(salva);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Taxas atualizadas e totais recalculados!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar taxas: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  Future<void> _abrirModalLancamento({
    DateTime? diaPadrao,
    PlanilhaReembolsoItem? itemExistente,
  }) async {
    final planilha = _planilha;
    if (planilha == null) return;

    final formKey = GlobalKey<FormState>();
    DateTime diaSelecionado = itemExistente?.dia ?? diaPadrao ?? DateTime(_ano, _mes, DateTime.now().day.clamp(1, DateTime(_ano, _mes + 1, 0).day));
    String tipoSelecionado = itemExistente != null
        ? TipoAtendimentoPlanilha.normalizar(itemExistente.tipoAtendimento)
        : TipoAtendimentoPlanilha.foraGarantia;

    final clienteCtrl = TextEditingController(text: itemExistente?.cliente ?? '');
    final osCtrl = TextEditingController(text: itemExistente?.numeroOs ?? '');
    final inicioCtrl = TextEditingController(text: itemExistente?.horarioInicial ?? '08:00');
    final pausaCtrl = TextEditingController(text: itemExistente?.pausaAlmoco ?? '01:00');
    final fimCtrl = TextEditingController(text: itemExistente?.horarioFinal ?? '17:00');
    final viagemCtrl = TextEditingController(
      text: itemExistente != null ? formatarMinutosHHMM(itemExistente.horaViagemMin) : '00:00',
    );
    final kmCtrl = TextEditingController(
      text: itemExistente != null && itemExistente.km > 0 ? itemExistente.km.toStringAsFixed(2) : '',
    );
    final pedagioCtrl = TextEditingController(
      text: itemExistente != null && itemExistente.pedagio > 0 ? itemExistente.pedagio.toStringAsFixed(2) : '',
    );
    final refeicaoCtrl = TextEditingController(
      text: itemExistente != null && itemExistente.refeicao > 0 ? itemExistente.refeicao.toStringAsFixed(2) : '',
    );
    final pecasCtrl = TextEditingController(
      text: itemExistente != null && itemExistente.pecas > 0 ? itemExistente.pecas.toStringAsFixed(2) : '',
    );
    final outrosCtrl = TextEditingController(
      text: itemExistente != null && itemExistente.outros > 0 ? itemExistente.outros.toStringAsFixed(2) : '',
    );
    final motivoCtrl = TextEditingController(text: itemExistente?.motivoOutros ?? '');

    Future<void> escolherHorario(TextEditingController ctrl, VoidCallback onPicked) async {
      final minAtual = parseHoraParaMinutos(ctrl.text);
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: (minAtual ~/ 60).clamp(0, 23), minute: minAtual % 60),
      );
      if (picked != null) {
        ctrl.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        onPicked();
      }
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final minutosTrab = calcularMinutosTrabalhados(
            inicioCtrl.text,
            pausaCtrl.text,
            fimCtrl.text,
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                Icon(
                  itemExistente != null ? Icons.edit_calendar_rounded : Icons.add_circle_outline_rounded,
                  color: const Color(0xFF0A369D),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    itemExistente != null ? 'Editar Lançamento Diário' : 'Novo Lançamento Diário',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final primeiro = DateTime(_ano, _mes, 1);
                                final ultimo = DateTime(_ano, _mes + 1, 0);
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: diaSelecionado.isBefore(primeiro) || diaSelecionado.isAfter(ultimo)
                                      ? primeiro
                                      : diaSelecionado,
                                  firstDate: primeiro,
                                  lastDate: ultimo,
                                );
                                if (picked != null) {
                                  setDialogState(() => diaSelecionado = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Dia *',
                                  prefixIcon: const Icon(Icons.calendar_today, size: 18),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                                child: Text(_dateFormat.format(diaSelecionado), style: const TextStyle(fontSize: 13.5)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: osCtrl,
                              decoration: InputDecoration(
                                labelText: 'No.OS',
                                hintText: 'Ex: 14865 ou 1',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: clienteCtrl,
                              decoration: InputDecoration(
                                labelText: 'Cliente *',
                                hintText: 'Ex: Mahle / Pmach',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o cliente' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: tipoSelecionado,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Tipo de atendimento',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                              items: TipoAtendimentoPlanilha.todos
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => tipoSelecionado = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: inicioCtrl,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Horário Inicial',
                                hintText: '08:00',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.access_time, size: 17),
                                  onPressed: () => escolherHorario(inicioCtrl, () => setDialogState(() {})),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: pausaCtrl,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Pausa Almoço',
                                hintText: '01:00',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.access_time, size: 17),
                                  onPressed: () => escolherHorario(pausaCtrl, () => setDialogState(() {})),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: fimCtrl,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Horário Final',
                                hintText: '17:00',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.access_time, size: 17),
                                  onPressed: () => escolherHorario(fimCtrl, () => setDialogState(() {})),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total horas trabalhadas (automático):',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                            ),
                            Text(
                              formatarMinutosHHMM(minutosTrab),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0A369D)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: viagemCtrl,
                              decoration: InputDecoration(
                                labelText: 'Hora viagem (HH:mm)',
                                hintText: '04:30',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.directions_car_outlined, size: 17),
                                  onPressed: () => escolherHorario(viagemCtrl, () => setDialogState(() {})),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: kmCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Km',
                                hintText: '320',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: pedagioCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Pedágio (R\$)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: refeicaoCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Refeição (R\$)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: pecasCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Peças (R\$)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: outrosCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Outros (R\$)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: motivoCtrl,
                        decoration: InputDecoration(
                          labelText: 'Motivo de outros',
                          hintText: 'Ex: Estacionamento, celular/internet, material...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton.icon(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, true);
                  }
                },
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('Salvar Lançamento'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A369D), foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );

    if (confirmar == true && mounted) {
      final itemSalvo = PlanilhaReembolsoItem(
        id: itemExistente?.id,
        planilhaId: planilha.id,
        tecnicoId: planilha.tecnicoId,
        chamadoId: itemExistente?.chamadoId,
        dia: diaSelecionado,
        cliente: clienteCtrl.text.trim(),
        numeroOs: osCtrl.text.trim(),
        tipoAtendimento: tipoSelecionado,
        horarioInicial: inicioCtrl.text.trim(),
        pausaAlmoco: pausaCtrl.text.trim(),
        horarioFinal: fimCtrl.text.trim(),
        horaViagemMin: parseHoraParaMinutos(viagemCtrl.text),
        km: _parseDecimal(kmCtrl.text),
        pedagio: _parseDecimal(pedagioCtrl.text),
        refeicao: _parseDecimal(refeicaoCtrl.text),
        pecas: _parseDecimal(pecasCtrl.text),
        outros: _parseDecimal(outrosCtrl.text),
        motivoOutros: motivoCtrl.text.trim(),
        ordem: itemExistente?.ordem ?? planilha.itens.length,
      );

      setState(() => _processando = true);
      try {
        await PlanilhaReembolsoService.instance.salvarItem(itemSalvo);
        await _carregarPlanilha();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lançamento salvo na planilha!'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao salvar lançamento: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _processando = false);
        }
      }
    }

    clienteCtrl.dispose();
    osCtrl.dispose();
    inicioCtrl.dispose();
    pausaCtrl.dispose();
    fimCtrl.dispose();
    viagemCtrl.dispose();
    kmCtrl.dispose();
    pedagioCtrl.dispose();
    refeicaoCtrl.dispose();
    pecasCtrl.dispose();
    outrosCtrl.dispose();
    motivoCtrl.dispose();
  }

  Future<void> _confirmarExcluirItem(PlanilhaReembolsoItem item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Lançamento?'),
        content: Text('Deseja remover o registro de ${_dateFormat.format(item.dia)} (${item.cliente})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;
    setState(() => _processando = true);
    try {
      await PlanilhaReembolsoService.instance.excluirItem(item.id);
      await _carregarPlanilha();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir item: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  Color _corStatusBg(String status) {
    switch (status) {
      case StatusPlanilha.aprovada:
        return const Color(0xFFDCFCE7);
      case StatusPlanilha.enviada:
        return const Color(0xFFDBEAFE);
      case StatusPlanilha.ajusteSolicitado:
        return const Color(0xFFFEF3C7);
      case StatusPlanilha.rascunho:
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _corStatusFg(String status) {
    switch (status) {
      case StatusPlanilha.aprovada:
        return const Color(0xFF15803D);
      case StatusPlanilha.enviada:
        return const Color(0xFF1D4ED8);
      case StatusPlanilha.ajusteSolicitado:
        return const Color(0xFFB45309);
      case StatusPlanilha.rascunho:
      default:
        return const Color(0xFF475569);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Color(0xFF0A369D)),
        ),
      );
    }

    if (_erroCarregamento != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text(_erroCarregamento!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _carregarPlanilha,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final planilha = _planilha!;
    final resumo = planilha.calcularResumoPorCategoria();
    final agora = DateTime.now();
    final ultimoDiaMesAtual = DateTime(agora.year, agora.month + 1, 0).day;
    final mostrarLembreteFechamento = !widget.isGerente &&
        (agora.day >= ultimoDiaMesAtual - 1 || agora.day <= 3) &&
        (planilha.status == StatusPlanilha.rascunho || planilha.status == StatusPlanilha.ajusteSolicitado);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cabeçalho principal (título, seletor de mês, status e ações)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onVoltar != null) ...[
                          IconButton(
                            onPressed: widget.onVoltar,
                            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0A369D)),
                            tooltip: 'Voltar para lista de técnicos',
                          ),
                          const SizedBox(width: 4),
                        ],
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Planilha Mensal — ${planilha.tecnicoNome}',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: _corStatusBg(planilha.status),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                StatusPlanilha.getLabel(planilha.status),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _corStatusFg(planilha.status),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Seletor de Mês/Ano
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _processando ? null : () => _alterarMes(-1),
                            icon: const Icon(Icons.chevron_left_rounded),
                            tooltip: 'Mês anterior',
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              planilha.nomeMesAno,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0A369D)),
                            ),
                          ),
                          IconButton(
                            onPressed: _processando ? null : () => _alterarMes(1),
                            icon: const Icon(Icons.chevron_right_rounded),
                            tooltip: 'Próximo mês',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _processando ? null : _importarDasAts,
                      icon: const Icon(Icons.download_for_offline_outlined, size: 16),
                      label: const Text('Importar das ATS do Mês'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0A369D),
                        side: const BorderSide(color: Color(0xFF93C5FD)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _processando ? null : _exportarPdf,
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: const Text('PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _processando ? null : _copiarCsv,
                      icon: const Icon(Icons.copy_all_outlined, size: 16),
                      label: const Text('Copiar CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    if (!widget.isGerente)
                      ElevatedButton.icon(
                        onPressed: _processando || planilha.status == StatusPlanilha.aprovada
                            ? null
                            : _enviarParaGerente,
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: Text(
                          planilha.status == StatusPlanilha.aprovada
                              ? 'Reembolso Aprovado'
                              : (planilha.status == StatusPlanilha.enviada
                                  ? 'Reenviar para o Gerente'
                                  : 'Enviar para o Gerente'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                      )
                    else ...[
                      ElevatedButton.icon(
                        onPressed: _processando
                            ? null
                            : () => _gerenteAlterarStatus(StatusPlanilha.aprovada),
                        icon: const Icon(Icons.verified_rounded, size: 16),
                        label: const Text('Aprovar Reembolso'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _processando
                            ? null
                            : () => _gerenteAlterarStatus(StatusPlanilha.ajusteSolicitado),
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: const Text('Devolver p/ Ajuste'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD97706),
                          side: const BorderSide(color: Color(0xFFFCD34D)),
                        ),
                      ),
                    ],
                  ],
                ),
                if (mostrarLembreteFechamento) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.event_available_rounded, size: 18, color: Color(0xFFB45309)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Fechamento mensal: revise seus atendimentos e clique em "Enviar para o Gerente" no último dia ou primeiro dia do mês.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (planilha.observacaoGerente.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.comment_outlined, size: 18, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Observação do Gerente: ${planilha.observacaoGerente}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Cards de KPI no topo
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildKpiCard('Total a Receber', formatarMoedaBr(planilha.totalGeralReceber), Icons.payments_outlined, const Color(0xFF10B981)),
              _buildKpiCard('Total KM', '${formatarNumeroBr(planilha.totalGeralKm)} km', Icons.route_outlined, const Color(0xFF0A369D)),
              _buildKpiCard('Horas Trabalhadas', formatarMinutosHHMM(planilha.totalGeralHorasTrabalhadasMin), Icons.schedule_rounded, const Color(0xFF2563EB)),
              _buildKpiCard('Horas Viagem', formatarMinutosHHMM(planilha.totalGeralHorasViagemMin), Icons.directions_car_outlined, const Color(0xFF7C3AED)),
              _buildKpiCard('Despesas Extras', formatarMoedaBr(planilha.totalDespesasExtras), Icons.receipt_long_outlined, const Color(0xFFD97706)),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Painel de Taxas (idêntico às linhas 1 e 2 da planilha)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildTaxaChip('Valor do km', formatarMoedaBr(planilha.valorKm)),
                    _buildTaxaChip('Valor do km interno', formatarMoedaBr(planilha.valorKmInterno)),
                    _buildTaxaChip('Valor Hora técnica', formatarMoedaBr(planilha.valorHoraTecnica)),
                    _buildTaxaChip('Valor hora viagem', formatarMoedaBr(planilha.valorHoraViagem)),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _processando ? null : _abrirModalEditarTaxas,
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Editar Taxas'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Tabela Diária (todas as 15 colunas + Ações)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Lançamentos Diários (${planilha.itens.length} registros)',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilterChip(
                          selected: _mostrarTodosDiasMes,
                          label: Text(
                            _mostrarTodosDiasMes
                                ? 'Mostrando dias 01 a ${DateTime(_ano, _mes + 1, 0).day}'
                                : 'Somente dias preenchidos',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onSelected: (v) => setState(() => _mostrarTodosDiasMes = v),
                        ),
                        ElevatedButton.icon(
                          onPressed: _processando ? null : () => _abrirModalLancamento(),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('+ Novo Lançamento'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A369D),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                    columnSpacing: 16,
                    horizontalMargin: 12,
                    dataRowMinHeight: 40,
                    dataRowMaxHeight: 54,
                    columns: const [
                      DataColumn(label: Text('Dia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('No.OS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Tipo de atendimento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Horário Inicial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Pausa almoço', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Horário Final', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Total horas trab.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Hora viagem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Km', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
                      DataColumn(label: Text('Pedágio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
                      DataColumn(label: Text('Refeição', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
                      DataColumn(label: Text('Peças', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
                      DataColumn(label: Text('Outros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
                      DataColumn(label: Text('Motivo de outros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                    rows: _buildDailyRows(planilha),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. Quadro Resumo de Reembolso (idêntico ao rodapé da planilha)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Quadro Resumo de Reembolso (por Tipo de Atendimento)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(const Color(0xFF0F172A)),
                    columnSpacing: 18,
                    horizontalMargin: 12,
                    columns: [
                      const DataColumn(label: Text('Indicador', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                      ...TipoAtendimentoPlanilha.todos.map(
                        (t) => DataColumn(label: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                      ),
                      const DataColumn(label: Text('Total Geral', style: TextStyle(color: Color(0xFF6EE7B7), fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                    rows: _buildResumoRows(planilha, resumo),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'TOTAL GERAL A RECEBER — ${planilha.nomeMesAno.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      Text(
                        formatarMoedaBr(planilha.totalGeralReceber),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String titulo, String valor, IconData icon, Color cor) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: cor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxaChip(String label, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(text: valor, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A369D))),
          ],
        ),
      ),
    );
  }

  List<DataRow> _buildDailyRows(PlanilhaReembolso planilha) {
    final rows = <DataRow>[];
    final diasNoMes = DateTime(_ano, _mes + 1, 0).day;

    if (!_mostrarTodosDiasMes) {
      if (planilha.itens.isEmpty) {
        return [
          const DataRow(
            cells: [
              DataCell(Text('Nenhum lançamento neste mês.', style: TextStyle(color: Color(0xFF94A3B8)))),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text('')),
              DataCell(Text('')),
            ],
          ),
        ];
      }
      for (final item in planilha.itens) {
        rows.add(_buildFilledItemRow(item, mostrarData: true));
      }
    } else {
      for (int d = 1; d <= diasNoMes; d++) {
        final diaAtual = DateTime(_ano, _mes, d);
        final itensDia = planilha.itens
            .where((i) => i.dia.year == _ano && i.dia.month == _mes && i.dia.day == d)
            .toList();

        if (itensDia.isEmpty) {
          rows.add(
            DataRow(
              cells: [
                DataCell(Text(_dateFormat.format(diaAtual), style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                const DataCell(Text('—', style: TextStyle(color: Color(0xFFCBD5E1)))),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF0A369D)),
                    tooltip: 'Adicionar atendimento em ${_dateFormat.format(diaAtual)}',
                    visualDensity: VisualDensity.compact,
                    onPressed: _processando ? null : () => _abrirModalLancamento(diaPadrao: diaAtual),
                  ),
                ),
              ],
            ),
          );
        } else {
          for (int i = 0; i < itensDia.length; i++) {
            rows.add(_buildFilledItemRow(itensDia[i], mostrarData: i == 0));
          }
        }
      }
    }

    if (planilha.itens.isNotEmpty) {
      rows.add(
        DataRow(
          color: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
          cells: [
            const DataCell(Text('TOTAIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
            const DataCell(Text('')),
            const DataCell(Text('')),
            const DataCell(Text('')),
            const DataCell(Text('')),
            const DataCell(Text('')),
            const DataCell(Text('')),
            DataCell(Text(formatarMinutosHHMM(planilha.totalGeralHorasTrabalhadasMin), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataCell(Text(formatarMinutosHHMM(planilha.totalGeralHorasViagemMin), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataCell(Text(formatarNumeroBr(planilha.totalGeralKm), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataCell(Text(formatarMoedaBr(planilha.totalGeralPedagios), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataCell(Text(formatarMoedaBr(planilha.totalGeralRefeicao), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataCell(Text(formatarMoedaBr(planilha.totalGeralPecas), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataCell(Text(formatarMoedaBr(planilha.totalGeralOutros), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const DataCell(Text('')),
            const DataCell(Text('')),
          ],
        ),
      );
    }

    return rows;
  }

  DataRow _buildFilledItemRow(PlanilhaReembolsoItem item, {required bool mostrarData}) {
    return DataRow(
      color: MaterialStateProperty.all(const Color(0xFFFCFDFF)),
      cells: [
        DataCell(
          Text(
            mostrarData ? _dateFormat.format(item.dia) : '↳ ${_dateFormat.format(item.dia)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: mostrarData ? FontWeight.bold : FontWeight.normal,
              color: mostrarData ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
        ),
        DataCell(Text(item.cliente, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        DataCell(Text(item.numeroOs, style: const TextStyle(fontSize: 12))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item.tipoAtendimento,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
            ),
          ),
        ),
        DataCell(Text(item.horarioInicial, style: const TextStyle(fontSize: 12))),
        DataCell(Text(item.pausaAlmoco, style: const TextStyle(fontSize: 12))),
        DataCell(Text(item.horarioFinal, style: const TextStyle(fontSize: 12))),
        DataCell(
          Text(
            formatarMinutosHHMM(item.totalHorasTrabalhadasMin),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0A369D)),
          ),
        ),
        DataCell(Text(formatarMinutosHHMM(item.horaViagemMin), style: const TextStyle(fontSize: 12))),
        DataCell(Text(formatarNumeroBr(item.km), style: const TextStyle(fontSize: 12))),
        DataCell(Text(formatarMoedaBr(item.pedagio), style: const TextStyle(fontSize: 12))),
        DataCell(Text(formatarMoedaBr(item.refeicao), style: const TextStyle(fontSize: 12))),
        DataCell(Text(formatarMoedaBr(item.pecas), style: const TextStyle(fontSize: 12))),
        DataCell(Text(formatarMoedaBr(item.outros), style: const TextStyle(fontSize: 12))),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(item.motivoOutros, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 17, color: Color(0xFF0A369D)),
                tooltip: 'Adicionar outro registro no mesmo dia',
                visualDensity: VisualDensity.compact,
                onPressed: _processando ? null : () => _abrirModalLancamento(diaPadrao: item.dia),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF334155)),
                tooltip: 'Editar lançamento',
                visualDensity: VisualDensity.compact,
                onPressed: _processando ? null : () => _abrirModalLancamento(itemExistente: item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 17, color: Color(0xFFDC2626)),
                tooltip: 'Excluir lançamento',
                visualDensity: VisualDensity.compact,
                onPressed: _processando ? null : () => _confirmarExcluirItem(item),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<DataRow> _buildResumoRows(
    PlanilhaReembolso planilha,
    Map<String, ResumoCategoriaPlanilha> resumo,
  ) {
    DataRow row(
      String label,
      List<String> valores,
      String totalGeral, {
      bool destaque = false,
    }) {
      final style = TextStyle(
        fontSize: 12,
        fontWeight: destaque ? FontWeight.bold : FontWeight.w500,
        color: destaque ? const Color(0xFF065F46) : const Color(0xFF1E293B),
      );
      return DataRow(
        color: destaque ? MaterialStateProperty.all(const Color(0xFFECFDF5)) : null,
        cells: [
          DataCell(Text(label, style: style.copyWith(fontWeight: FontWeight.bold))),
          ...valores.map((v) => DataCell(Text(v, style: style))),
          DataCell(Text(totalGeral, style: style.copyWith(fontWeight: FontWeight.bold))),
        ],
      );
    }

    return [
      row(
        'Horas trabalhadas',
        TipoAtendimentoPlanilha.todos.map((t) => formatarMinutosHHMM(resumo[t]!.horasTrabalhadasMin)).toList(),
        formatarMinutosHHMM(planilha.totalGeralHorasTrabalhadasMin),
      ),
      row(
        'Total a pagar horas trabalhadas',
        TipoAtendimentoPlanilha.todos.map((t) => formatarMoedaBr(resumo[t]!.valorHorasTrabalhadas)).toList(),
        formatarMoedaBr(planilha.totalGeralPagarHorasTrabalhadas),
      ),
      row(
        'Horas viagens',
        TipoAtendimentoPlanilha.todos.map((t) => formatarMinutosHHMM(resumo[t]!.horasViagemMin)).toList(),
        formatarMinutosHHMM(planilha.totalGeralHorasViagemMin),
      ),
      row(
        'Total a pagar horas viagens',
        TipoAtendimentoPlanilha.todos.map((t) => formatarMoedaBr(resumo[t]!.valorHorasViagem)).toList(),
        formatarMoedaBr(planilha.totalGeralPagarHorasViagem),
      ),
      row(
        'Total Km',
        TipoAtendimentoPlanilha.todos.map((t) => formatarNumeroBr(resumo[t]!.totalKm)).toList(),
        formatarNumeroBr(planilha.totalGeralKm),
      ),
      row(
        'Total a pagar KM',
        TipoAtendimentoPlanilha.todos.map((t) => formatarMoedaBr(resumo[t]!.valorKm)).toList(),
        formatarMoedaBr(planilha.totalGeralPagarKm),
      ),
      row(
        'Pedágios',
        TipoAtendimentoPlanilha.todos.map((t) => formatarMoedaBr(resumo[t]!.pedagios)).toList(),
        formatarMoedaBr(planilha.totalGeralPedagios),
      ),
      row(
        'Refeição',
        TipoAtendimentoPlanilha.todos.map((t) => formatarMoedaBr(resumo[t]!.refeicao)).toList(),
        formatarMoedaBr(planilha.totalGeralRefeicao),
      ),
      row(
        'Peças',
        TipoAtendimentoPlanilha.todos.map((t) => formatarMoedaBr(resumo[t]!.pecas)).toList(),
        formatarMoedaBr(planilha.totalGeralPecas),
      ),
      row(
        'Outros',
        TipoAtendimentoPlanilha.todos.map((t) => formatarMoedaBr(resumo[t]!.outros)).toList(),
        formatarMoedaBr(planilha.totalGeralOutros),
      ),
      row(
        'Total a receber',
        TipoAtendimentoPlanilha.todos.map((t) => formatarMoedaBr(resumo[t]!.totalReceber)).toList(),
        formatarMoedaBr(planilha.totalGeralReceber),
        destaque: true,
      ),
    ];
  }
}
