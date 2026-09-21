import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chamado.dart';
import '../../models/dia_trabalho.dart';
import '../../models/log_horas_custos.dart';
import '../../services/ats_pdf_service.dart';
import '../../services/chamados_service.dart';
import '../../services/orcamento_pdf_service.dart';

class ChamadosListScreen extends StatefulWidget {
  const ChamadosListScreen({super.key});

  @override
  State<ChamadosListScreen> createState() => _ChamadosListScreenState();
}

class _ChamadosListScreenState extends State<ChamadosListScreen> {
  String _selectedFilter = 'todos'; // 'todos', 'aprovado_pendente', 'orcamento_enviado', 'atribuido'
  String? _enviandoEmailChamadoId;
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
                    onPressed: () => _mostrarModalNovaProposta(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Nova Proposta'),
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
                if (chamado.status == ChamadoStatus.finalizado) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _enviandoEmailChamadoId == chamado.id
                        ? null
                        : () => _gerarPdfEEnviarCliente(chamado),
                    icon: _enviandoEmailChamadoId == chamado.id
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(_enviandoEmailChamadoId == chamado.id
                        ? 'Enviando...'
                        : 'Gerar PDF e Enviar para o Cliente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A369D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
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

  // ============================================================================
  // GERAÇÃO DE PDF E DISPARO DE E-MAIL VIA SUPABASE EDGE FUNCTIONS
  // ============================================================================
  Future<void> _gerarPdfEEnviarCliente(Chamado chamado) async {
    setState(() => _enviandoEmailChamadoId = chamado.id);

    try {
      final client = Supabase.instance.client;

      // 1. Busca os dias de trabalho caso não estejam em memória
      List<DiaTrabalho> dias = chamado.diasTrabalho;
      if (dias.isEmpty && chamado.id.isNotEmpty && !chamado.id.startsWith('chamado-')) {
        try {
          final diasRes = await client
              .from('ats_dias_trabalho')
              .select()
              .eq('chamado_id', chamado.id)
              .order('data', ascending: true);
          if (diasRes.isNotEmpty) {
            dias = (diasRes as List)
                .map((d) => DiaTrabalho.fromMap(Map<String, dynamic>.from(d as Map)))
                .toList();
          }
        } catch (_) {}
      }

      // 2. Prepara modelo de horas/custos
      final logHoras = LogHorasCustos(
        id: 'log-${DateTime.now().millisecondsSinceEpoch}',
        idChamado: chamado.id,
        data: dias.isNotEmpty ? dias.first.data : DateTime.now(),
        horaInicio: dias.isNotEmpty ? dias.first.horaInicio : '08:00',
        horaFim: dias.isNotEmpty ? (dias.first.horaFim ?? '17:00') : '17:00',
        kmRodado: chamado.kmEstimado ?? 0.0,
      );

      // 3. Obtém assinatura (ou fallback transparente)
      final assinaturaBytes = await _obterAssinaturaBytes(chamado.assinaturaUrl);

      // 4. Gera o PDF oficial da ATS
      final pdfBytes = await AtsPdfService.instance.gerarRelatorioAtsPdf(
        chamado: chamado,
        logHoras: logHoras,
        diasTrabalho: dias,
        servicoExecutado: (chamado.servicoExecutado != null && chamado.servicoExecutado!.trim().isNotEmpty)
            ? chamado.servicoExecutado!.trim()
            : 'Atendimento e revisão técnica industrial concluídos.',
        assinaturaBytes: assinaturaBytes,
        responsavelNome: (chamado.responsavelAceiteNome != null && chamado.responsavelAceiteNome!.trim().isNotEmpty)
            ? chamado.responsavelAceiteNome!.trim()
            : (chamado.contato ?? 'Cliente Responsável'),
        videoUrl: chamado.videoUrl,
      );

      // 5. Upload do PDF (v1) para o Supabase Storage
      final cleanAts = chamado.numeroAts.replaceAll('ATS-', '').trim();
      final pdfPath = 'relatorios_ats/ats_${cleanAts}_v1.pdf';
      await client.storage.from('orcamentos').uploadBinary(
            pdfPath,
            pdfBytes,
            fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
          );
      final pdfUrl = client.storage.from('orcamentos').getPublicUrl(pdfPath);

      // 6. UPDATE na tabela chamados com a nova pdf_url
      if (chamado.id.isNotEmpty && !chamado.id.startsWith('chamado-')) {
        await client.from('chamados').update({
          'orcamento_pdf_url': pdfUrl,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', chamado.id);
      } else {
        await client.from('chamados').update({
          'orcamento_pdf_url': pdfUrl,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('numero_ats', cleanAts);
      }

      // Atualiza o chamado no cache reativo local
      await ChamadosService.instance.atualizarChamado(
        chamado.copyWith(orcamentoPdfUrl: pdfUrl),
      );

      // 7. Invoca a Supabase Edge Function send-ats-pdf
      final response = await client.functions.invoke(
        'send-ats-pdf',
        body: {
          'chamado_id': chamado.id,
          'pdf_url': pdfUrl,
        },
      );

      if (response.status != 200) {
        throw Exception('Falha ao disparar Edge Function: status ${response.status}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF gerado e enviado para o e-mail do cliente com sucesso!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao gerar e enviar PDF para o cliente: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar PDF: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enviandoEmailChamadoId = null);
      }
    }
  }

  Future<Uint8List> _obterAssinaturaBytes(String? assinaturaUrl) async {
    if (assinaturaUrl != null && assinaturaUrl.isNotEmpty) {
      try {
        final client = Supabase.instance.client;
        String path = assinaturaUrl;
        if (path.contains('/orcamentos/')) {
          path = path.split('/orcamentos/').last;
        }
        final bytes = await client.storage.from('orcamentos').download(path);
        if (bytes.isNotEmpty) return bytes;
      } catch (_) {}
    }
    // 1x1 Transparent PNG fallback
    return Uint8List.fromList([
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
      0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 11, 73, 68, 65, 84,
      120, 1, 99, 96, 0, 0, 0, 2, 0, 1, 244, 113, 100, 166, 0, 0, 0, 0, 73, 69,
      78, 68, 174, 66, 96, 130
    ]);
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

  void _mostrarModalNovaProposta(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final contatoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

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
            const Text('Nova Proposta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
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
                          'A O.S./ATS será gerada automaticamente. Os demais dados serão completados na execução técnica ou pelo próprio cliente.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: contatoCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Nome do Cliente / Solicitante *',
                    hintText: 'Ex: Indústria Haas / Roberto Mendes',
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome do cliente / solicitante' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'E-mail do Cliente',
                    hintText: 'cliente@empresa.com.br',
                    prefixIcon: const Icon(Icons.email_outlined, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ],
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
                  emailCliente: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Nova Proposta O.S. Nº ${novo.numeroAts} criada com sucesso!'),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Criar Nova Proposta'),
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
