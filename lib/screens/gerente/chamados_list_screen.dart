import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chamado.dart';
import '../../services/chamados_service.dart';
import '../../services/orcamento_pdf_service.dart';

class ChamadosListScreen extends StatefulWidget {
  const ChamadosListScreen({super.key});

  @override
  State<ChamadosListScreen> createState() => _ChamadosListScreenState();
}

class _ChamadosListScreenState extends State<ChamadosListScreen> {
  String _selectedFilter = 'todos'; // 'todos', 'aprovado_pendente', 'orcamento_enviado', 'atribuido'
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  final List<String> _tecnicosDisponiveis = [
    'Carlos Silva',
    'André Souza',
    'Marcos Oliveira',
    'Lucas Pereira',
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Chamado>>(
      valueListenable: ChamadosService.instance.chamadosNotifier,
      builder: (context, chamados, _) {
        final chamadosFiltrados = _filtrarChamados(chamados);
        final pendentesCount = chamados.where((c) => c.status == ChamadoStatus.aprovadoPendente).length;
        final orcamentosCount = chamados.where((c) =>
            c.status == ChamadoStatus.orcamentoEnviado ||
            c.status == ChamadoStatus.orcamentoPendenteEnvio ||
            c.status == ChamadoStatus.novo).length;
        final atribuidosCount = chamados.where((c) => c.status == ChamadoStatus.atribuido).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra Superior: Filtros com Contadores + Botão de Abertura de Novo Orçamento
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Todos (${chamados.length})', 'todos'),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Aprovados ($pendentesCount)',
                            'aprovado_pendente',
                            isAlert: pendentesCount > 0,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Orçamentos ($orcamentosCount)',
                            'orcamentos',
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Técnico Atribuído ($atribuidosCount)',
                            'atribuido',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _mostrarModalNovoOrcamento(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Novo Orçamento'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A369D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 1,
                    ),
                  ),
                ],
              ),
            ),

            // Lista de Chamados
            Expanded(
              child: chamadosFiltrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhum chamado encontrado para este filtro.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: chamadosFiltrados.length,
                      itemBuilder: (context, index) {
                        final chamado = chamadosFiltrados[index];
                        return _buildChamadoCard(chamado);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  List<Chamado> _filtrarChamados(List<Chamado> lista) {
    if (_selectedFilter == 'todos') return lista;
    if (_selectedFilter == 'orcamentos') {
      return lista.where((c) =>
          c.status == ChamadoStatus.orcamentoEnviado ||
          c.status == ChamadoStatus.orcamentoPendenteEnvio ||
          c.status == ChamadoStatus.novo).toList();
    }
    return lista.where((c) => c.status == _selectedFilter).toList();
  }

  Widget _buildFilterChip(String label, String value, {bool isAlert = false}) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? Colors.white
            : (isAlert ? const Color(0xFFB45309) : const Color(0xFF334155)),
      ),
      backgroundColor: isAlert ? const Color(0xFFFEF3C7) : Colors.white,
      selectedColor: isAlert ? const Color(0xFFD97706) : const Color(0xFF0A369D),
      side: BorderSide(
        color: isAlert ? const Color(0xFFF59E0B) : Colors.grey.shade300,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
        });
      },
    );
  }

  Widget _buildChamadoCard(Chamado chamado) {
    final isAprovadoPendente = chamado.status == ChamadoStatus.aprovadoPendente;
    final isOrcamentoEnviado = chamado.status == ChamadoStatus.orcamentoEnviado;
    final isPendenteEnvio = chamado.status == ChamadoStatus.orcamentoPendenteEnvio;
    final isAtribuido = chamado.status == ChamadoStatus.atribuido;

    Color borderColor = const Color(0xFFE2E8F0);
    if (isAprovadoPendente) {
      borderColor = const Color(0xFF10B981); // Verde esmeralda destacando aprovação
    } else if (isOrcamentoEnviado) {
      borderColor = const Color(0xFFFDBA74); // Laranja para orçamento enviado
    } else if (isPendenteEnvio) {
      borderColor = const Color(0xFFFCD34D); // Âmbar para pendente de envio
    } else if (isAtribuido) {
      borderColor = const Color(0xFF3B82F6);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isAprovadoPendente ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isAprovadoPendente
                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                : (isOrcamentoEnviado
                    ? const Color(0xFFEA580C).withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.03)),
            blurRadius: isAprovadoPendente ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha do Topo: Nº ATS + Badges em Wrap (Elimina o erro de overflow lateral)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'O.S. Nº ${chamado.numeroAts}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A369D),
                        ),
                      ),
                    ),
                    if (isAprovadoPendente)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 12, color: Color(0xFF166534)),
                            SizedBox(width: 4),
                            Text(
                              'ORÇAMENTO APROVADO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                _buildStatusBadge(chamado.status),
              ],
            ),
            const SizedBox(height: 10),

            // Razão Social & Máquina
            Text(
              chamado.razaoSocial,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            if (chamado.contato != null && chamado.contato!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    'Contato: ${chamado.contato} | Tel: ${chamado.telefone ?? "Não informado"}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.precision_manufacturing, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${chamado.fabricante ?? "Pmach"} - ${chamado.modeloMaquina ?? "Máquina CNC"} (S/N: ${chamado.numeroSerie ?? "S/N"})',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Defeito Relatado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Defeito: ${chamado.defeitoRelatado ?? "Diagnóstico e reparo geral."}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Informações de Aceite (se houver)
            if (chamado.termosAceitos && chamado.responsavelAceiteNome != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 13, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text(
                    'Aceito por ${chamado.responsavelAceiteNome} (${chamado.responsavelAceiteCargo ?? "Cliente"}) em ${_dateFormat.format(chamado.aceiteData ?? DateTime.now())}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],

            if (isAtribuido && chamado.tecnicoNome != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 14, color: Color(0xFF2563EB)),
                  const SizedBox(width: 4),
                  Text(
                    'Técnico Responsável: ${chamado.tecnicoNome}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],

            // Seção de Envio para o Cliente (para chamados que aguardam aprovação de orçamento)
            if (chamado.status == ChamadoStatus.orcamentoEnviado ||
                chamado.status == ChamadoStatus.orcamentoPendenteEnvio ||
                chamado.status == ChamadoStatus.novo) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.share_outlined, size: 15, color: Color(0xFF1E40AF)),
                        SizedBox(width: 6),
                        Text(
                          'Enviar para Aprovação do Cliente:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Anotação interna de geração e envio do link
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.link, size: 14, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Link gerado para: ${chamado.contato ?? chamado.razaoSocial} em ${_dateFormat.format(chamado.createdAt)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (chamado.anotacaoEnvio != null && chamado.anotacaoEnvio!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFFEA580C)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    chamado.anotacaoEnvio!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFC2410C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // a) Botão "Copiar Link de Aprovação"
                        OutlinedButton.icon(
                          onPressed: () => _copiarLinkAprovacao(context, chamado),
                          icon: const Icon(Icons.link, size: 15),
                          label: const Text('Copiar Link de Aprovação'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0A369D),
                            side: const BorderSide(color: Color(0xFF93C5FD)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        // b) Botão "WhatsApp"
                        ElevatedButton.icon(
                          onPressed: () => _compartilharWhatsApp(context, chamado),
                          icon: const Icon(Icons.chat, size: 15),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 20),

            // Ações
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Botão de Baixar / Ver PDF Orçamento
                OutlinedButton.icon(
                  onPressed: () => _visualizarPdfOrcamento(chamado),
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('Ver PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0A369D),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),

                // Botão "Atribuir Técnico" (destacado para chamados aprovados)
                if (isAprovadoPendente ||
                    chamado.status == ChamadoStatus.novo ||
                    chamado.status == ChamadoStatus.orcamentoEnviado ||
                    chamado.status == ChamadoStatus.orcamentoPendenteEnvio)
                  ElevatedButton.icon(
                    onPressed: () => _mostrarModalAtribuirTecnico(context, chamado),
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text('Atribuir Técnico'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAprovadoPendente ? const Color(0xFF10B981) : const Color(0xFF0A369D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);
    Color border = const Color(0xFFCBD5E1);
    Color dotColor = const Color(0xFF64748B);

    switch (status) {
      case ChamadoStatus.orcamentoPendenteEnvio:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        border = const Color(0xFFFCD34D);
        dotColor = const Color(0xFFD97706);
        break;
      case ChamadoStatus.orcamentoEnviado:
        // Badge na cor LARANJA com indicador circular laranja
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFC2410C);
        border = const Color(0xFFFDBA74);
        dotColor = const Color(0xFFEA580C);
        break;
      case ChamadoStatus.aprovadoPendente:
        // A bolinha passa de laranja para VERDE (Orçamento Aprovado)
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        border = const Color(0xFF86EFAC);
        dotColor = const Color(0xFF16A34A);
        break;
      case ChamadoStatus.atribuido:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        border = const Color(0xFFBFDBFE);
        dotColor = const Color(0xFF2563EB);
        break;
      case ChamadoStatus.emAtendimento:
        bg = const Color(0xFFFEF9C3);
        fg = const Color(0xFFA16207);
        border = const Color(0xFFFDE047);
        dotColor = const Color(0xFFCA8A04);
        break;
      case ChamadoStatus.finalizado:
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF6B21A8);
        border = const Color(0xFFD8B4FE);
        dotColor = const Color(0xFF9333EA);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            ChamadoStatus.getLabel(status),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _visualizarPdfOrcamento(Chamado chamado) async {
    // Gera em tempo de execução caso não esteja em URL pública remota
    final dummySignature = List<int>.generate(100, (i) => 255);
    final pdfBytes = await OrcamentoPdfService.generatePdf(
      chamado: chamado,
      signatureBytes: Uint8List.fromList(dummySignature),
      responsavelNome: chamado.responsavelAceiteNome ?? 'Cliente Responsável',
      responsavelCargo: chamado.responsavelAceiteCargo ?? 'Representante',
    );

    await Printing.layoutPdf(
      onLayout: (_) => pdfBytes,
      name: 'Orcamento_ATS_${chamado.numeroAts}.pdf',
    );
  }

  void _mostrarModalAtribuirTecnico(BuildContext context, Chamado chamado) {
    String tecnicoSelecionado = _tecnicosDisponiveis.first;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.assignment_ind, color: Color(0xFF0A369D)),
                ),
                const SizedBox(width: 12),
                const Text('Atribuir Técnico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ordem de Serviço Nº ${chamado.numeroAts}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cliente: ${chamado.razaoSocial}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                Text(
                  'Equipamento: ${chamado.modeloMaquina ?? "Máquina CNC"}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Selecione o profissional da equipe técnica:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: tecnicoSelecionado,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _tecnicosDisponiveis.map((tec) {
                    return DropdownMenuItem(value: tec, child: Text(tec));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        tecnicoSelecionado = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF475569)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'O chamado passará para o status "atribuido" e será imediatamente disponibilizado no aplicativo do técnico.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  final success = await ChamadosService.instance.atribuirTecnico(
                    chamadoId: chamado.id,
                    tecnicoNome: tecnicoSelecionado,
                  );

                  if (context.mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Chamado Nº ${chamado.numeroAts} atribuído a $tecnicoSelecionado com sucesso!'),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A369D),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirmar Atribuição'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _gerarUrlPublica(Chamado chamado) {
    final base = Uri.base.hasAuthority && Uri.base.authority.isNotEmpty
        ? '${Uri.base.scheme}://${Uri.base.authority}'
        : 'https://app.pmach.com';
    return '$base/#/orcamento?token=${chamado.tokenUrl}';
  }

  Future<void> _copiarLinkAprovacao(BuildContext context, Chamado chamado) async {
    final url = _gerarUrlPublica(chamado);
    await Clipboard.setData(ClipboardData(text: url));

    final carimbo = 'Link copiado em ${DateFormat('dd/MM/yyyy às HH:mm').format(DateTime.now())}';
    await ChamadosService.instance.registrarEnvioLink(
      chamadoId: chamado.id,
      anotacao: carimbo,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link de aprovação copiado! Status alterado para Orçamento Enviado.\n$url'),
          backgroundColor: const Color(0xFF0A369D),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _compartilharWhatsApp(BuildContext context, Chamado chamado) async {
    final url = _gerarUrlPublica(chamado);
    final destinatario = chamado.contato != null && chamado.contato!.isNotEmpty
        ? chamado.contato
        : chamado.razaoSocial;
    final mensagem = 'Olá $destinatario! Segue o link para conferência e aprovação digital do Orçamento / O.S. Nº ${chamado.numeroAts} da ${chamado.razaoSocial}:\n$url\nBasta acessar para assinar diretamente pelo celular ou computador.';

    String phoneParam = '';
    if (chamado.telefone != null && chamado.telefone!.trim().isNotEmpty) {
      final apenasDigitos = chamado.telefone!.replaceAll(RegExp(r'\D'), '');
      if (apenasDigitos.length >= 10) {
        final ddi = apenasDigitos.startsWith('55') ? apenasDigitos : '55$apenasDigitos';
        phoneParam = 'phone=$ddi&';
      }
    }

    final carimbo = 'Enviado via WhatsApp em ${DateFormat('dd/MM/yyyy às HH:mm').format(DateTime.now())}';
    await ChamadosService.instance.registrarEnvioLink(
      chamadoId: chamado.id,
      anotacao: carimbo,
    );

    final whatsappUrl = Uri.parse('https://api.whatsapp.com/send?${phoneParam}text=${Uri.encodeComponent(mensagem)}');

    try {
      final launched = await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        await launchUrl(whatsappUrl, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (context.mounted) {
        await _copiarLinkAprovacao(context, chamado);
      }
    }
  }

  void _mostrarModalNovoOrcamento(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final contatoCtrl = TextEditingController();
    final telefoneCtrl = TextEditingController();
    final fabricanteCtrl = TextEditingController(text: 'Pmach');
    final modeloCtrl = TextEditingController();
    final defeitoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_task, color: Color(0xFF0A369D)),
            ),
            const SizedBox(width: 12),
            const Text('Novo Orçamento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Color(0xFF475569)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Preencha os dados de contato e máquina. O cliente completará CNPJ e Endereço ao assinar.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. Nome do Contato / Cliente
                  TextFormField(
                    controller: contatoCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nome do Contato / Cliente *',
                      hintText: 'Ex: Roberto Mendes (Indústria Haas)',
                      prefixIcon: const Icon(Icons.person_outline, size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome do contato/cliente' : null,
                  ),
                  const SizedBox(height: 12),

                  // 2. Telefone / WhatsApp
                  TextFormField(
                    controller: telefoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Telefone / WhatsApp *',
                      hintText: '(47) 99999-9999',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o telefone/WhatsApp' : null,
                  ),
                  const SizedBox(height: 12),

                  // 3. Fabricante e Modelo do Equipamento
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: fabricanteCtrl,
                          decoration: InputDecoration(
                            labelText: 'Fabricante *',
                            hintText: 'Pmach',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: modeloCtrl,
                          decoration: InputDecoration(
                            labelText: 'Modelo Máquina *',
                            hintText: 'Ex: Torno CNC ST-20',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o modelo' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 4. Defeito Breve
                  TextFormField(
                    controller: defeitoCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Defeito Breve / Ocorrência *',
                      hintText: 'Descreva sucintamente a anomalia ou serviço',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o defeito breve' : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogCtx);
                final novo = await ChamadosService.instance.criarNovoChamado(
                  contato: contatoCtrl.text.trim(),
                  telefone: telefoneCtrl.text.trim(),
                  fabricante: fabricanteCtrl.text.trim(),
                  modeloMaquina: modeloCtrl.text.trim(),
                  defeitoRelatado: defeitoCtrl.text.trim(),
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Orçamento O.S. Nº ${novo.numeroAts} aberto com sucesso!'),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Criar Orçamento'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A369D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

