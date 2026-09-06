import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra de Filtros
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    'Orçamento Enviado',
                    'orcamento_enviado',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Técnico Atribuído',
                    'atribuido',
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
    final isAtribuido = chamado.status == ChamadoStatus.atribuido;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAprovadoPendente
              ? const Color(0xFF10B981) // Borda verde esmeralda destacando aprovação
              : (isAtribuido ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0)),
          width: isAprovadoPendente ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isAprovadoPendente
                ? const Color(0xFF10B981).withOpacity(0.12)
                : Colors.black.withOpacity(0.03),
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
            // Linha do Topo: Nº ATS + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
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
                    const SizedBox(width: 8),
                    if (isAprovadoPendente)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
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
                if (isAprovadoPendente || chamado.status == ChamadoStatus.novo || chamado.status == ChamadoStatus.orcamentoEnviado)
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

    switch (status) {
      case ChamadoStatus.aprovadoPendente:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        break;
      case ChamadoStatus.orcamentoEnviado:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        break;
      case ChamadoStatus.atribuido:
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF4338CA);
        break;
      case ChamadoStatus.emAtendimento:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      case ChamadoStatus.finalizado:
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF6B21A8);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        ChamadoStatus.getLabel(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
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
}
