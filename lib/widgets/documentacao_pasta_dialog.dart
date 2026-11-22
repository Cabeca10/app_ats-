import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ats_documentacao.dart';
import '../models/chamado.dart';
import '../services/ats_documentacao_service.dart';

/// Visualizador em formato Pasta Técnica (estilo OneNote) para o Gerente consultar
/// as fotos, anotações por foto, notas gerais e relatórios de um chamado.
class DocumentacaoPastaDialog extends StatefulWidget {
  final Chamado chamado;
  final AtsDocumentacao? initialDoc;
  final VoidCallback? onAbrirRelatorioFinal;
  final VoidCallback? onAbrirPdfAprovado;

  const DocumentacaoPastaDialog({
    super.key,
    required this.chamado,
    this.initialDoc,
    this.onAbrirRelatorioFinal,
    this.onAbrirPdfAprovado,
  });

  @override
  State<DocumentacaoPastaDialog> createState() => _DocumentacaoPastaDialogState();
}

class _DocumentacaoPastaDialogState extends State<DocumentacaoPastaDialog> {
  AtsDocumentacao? _doc;
  bool _carregando = true;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _doc = widget.initialDoc;
    _buscarDocumentacaoAtualizada();
  }

  Future<void> _buscarDocumentacaoAtualizada() async {
    try {
      final atualizada = await AtsDocumentacaoService.instance.obterDocumentacao(widget.chamado.id);
      if (mounted) {
        setState(() {
          _doc = atualizada;
          _carregando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _abrirImagemNovaAba(String url) async {
    try {
      final uri = Uri.parse(url);
      var launched = await launchUrl(
        uri,
        webOnlyWindowName: '_blank',
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(
          uri,
          webOnlyWindowName: '_blank',
          mode: LaunchMode.platformDefault,
        );
      }
    } catch (_) {}
  }

  void _abrirFotoAmpliada(FotoDocumentacaoItem item, int numero) {
    final hasUrl = item.url.trim().isNotEmpty && item.url.startsWith('http');
    if (!hasUrl) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(item.url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              left: 16,
              right: 96,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Foto #$numero • ${item.categoria}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 52,
              child: IconButton(
                icon: const Icon(Icons.open_in_new, color: Colors.white, size: 22),
                tooltip: 'Abrir imagem original em nova aba',
                onPressed: () => _abrirImagemNovaAba(item.url),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chamado;
    final atsLabel = c.numeroAts.toUpperCase().startsWith('ATS-') ? c.numeroAts : 'ATS-${c.numeroAts}';
    final tecnicos = [
      if (c.tecnicoNome != null && c.tecnicoNome!.trim().isNotEmpty) c.tecnicoNome!.trim(),
      if (c.tecnico2Nome != null && c.tecnico2Nome!.trim().isNotEmpty) c.tecnico2Nome!.trim(),
    ];
    final tecnicosLabel = tecnicos.isNotEmpty ? tecnicos.join(' / ') : 'Não atribuído';
    final versaoRelatorio = c.relatorioVersao > 0 ? c.relatorioVersao : 1;
    final screenHeight = MediaQuery.of(context).size.height;
    final doc = _doc;
    final itensFotos = doc?.itensFotos ?? const <FotoDocumentacaoItem>[];

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: screenHeight * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho azul escuro
            Container(
              color: const Color(0xFF0A369D),
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.folder_open_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Pasta do Chamado — $atsLabel',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                ChamadoStatus.getLabel(c.status),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cliente: ${c.razaoSocial} • Máquina: ${c.modeloMaquina ?? "Em levantamento"}',
                          style: const TextStyle(color: Color(0xFFDBEAFE), fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Técnico(s): $tecnicosLabel',
                          style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 12),
                        ),
                        if (widget.onAbrirRelatorioFinal != null || widget.onAbrirPdfAprovado != null) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (widget.onAbrirRelatorioFinal != null)
                                ElevatedButton.icon(
                                  onPressed: widget.onAbrirRelatorioFinal,
                                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                                  label: Text('Finalizado v$versaoRelatorio'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              if (widget.onAbrirPdfAprovado != null)
                                OutlinedButton.icon(
                                  onPressed: widget.onAbrirPdfAprovado,
                                  icon: const Icon(Icons.description_outlined, size: 15),
                                  label: const Text('Ver Proposta PDF'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Color(0xFF93C5FD)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Fechar pasta',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            if (_carregando) const LinearProgressIndicator(minHeight: 2, color: Color(0xFF0A369D)),

            // Conteúdo rolável
            Expanded(
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Resumo Técnico do Chamado
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
                            const Row(
                              children: [
                                Icon(Icons.assignment_outlined, color: Color(0xFF0A369D), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Resumo Técnico do Chamado',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 18),
                            const Text(
                              'Defeito Relatado:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (c.defeitoRelatado != null && c.defeitoRelatado!.trim().isNotEmpty)
                                  ? c.defeitoRelatado!.trim()
                                  : 'Nenhum defeito informado.',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Serviço Executado (Memorial Técnico):',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (c.servicoExecutado != null && c.servicoExecutado!.trim().isNotEmpty)
                                  ? c.servicoExecutado!.trim()
                                  : 'Ainda não preenchido no relatório final.',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Anotações de Campo (OneNote)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFEF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.edit_note_rounded, color: Color(0xFFB45309), size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      'Anotações de Campo (OneNote)',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF78350F),
                                      ),
                                    ),
                                  ],
                                ),
                                if (doc != null)
                                  Text(
                                    'Atualizado em ${_dateFormat.format(doc.updatedAt)}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                                  ),
                              ],
                            ),
                            const Divider(height: 18, color: Color(0xFFFDE68A)),
                            SelectableText(
                              (doc != null && doc.anotacoesCampo.trim().isNotEmpty)
                                  ? doc.anotacoesCampo.trim()
                                  : 'Nenhuma anotação geral registrada.',
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.45,
                                color: (doc != null && doc.anotacoesCampo.trim().isNotEmpty)
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. Registro Fotográfico e Descritivo
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
                            Row(
                              children: [
                                const Icon(Icons.photo_library_outlined, color: Color(0xFF0A369D), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Registro Fotográfico e Descritivo (${itensFotos.length} ${itensFotos.length == 1 ? "foto" : "fotos"})',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (itensFotos.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 28),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(Icons.photo_camera_back_outlined, size: 36, color: Color(0xFF94A3B8)),
                                    SizedBox(height: 8),
                                    Text(
                                      'Nenhuma foto registrada pelo técnico até o momento.',
                                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Column(
                                children: itensFotos.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final item = entry.value;
                                  final hasUrl = item.url.trim().isNotEmpty && item.url.startsWith('http');

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF0A369D),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    'Foto #${idx + 1}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEFF6FF),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                                  ),
                                                  child: Text(
                                                    item.categoria,
                                                    style: const TextStyle(
                                                      color: Color(0xFF1D4ED8),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _dateFormat.format(item.criadoEm),
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                ),
                                                if (hasUrl) ...[
                                                  const SizedBox(width: 4),
                                                  IconButton(
                                                    icon: const Icon(Icons.open_in_new, size: 18, color: Color(0xFF0A369D)),
                                                    tooltip: 'Abrir imagem original em nova aba',
                                                    visualDensity: VisualDensity.compact,
                                                    onPressed: () => _abrirImagemNovaAba(item.url),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        GestureDetector(
                                          onTap: hasUrl ? () => _abrirFotoAmpliada(item, idx + 1) : null,
                                          child: Container(
                                            height: 280,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: hasUrl
                                                ? Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Image.network(
                                                          item.url,
                                                          fit: BoxFit.contain,
                                                          loadingBuilder: (context, child, loadingProgress) {
                                                            if (loadingProgress == null) return child;
                                                            return const Center(
                                                              child: CircularProgressIndicator(color: Color(0xFF0A369D)),
                                                            );
                                                          },
                                                          errorBuilder: (context, error, stackTrace) => const Center(
                                                            child: Text(
                                                              'Imagem indisponível',
                                                              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        right: 8,
                                                        bottom: 8,
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: Colors.black54,
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: const Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                                              SizedBox(width: 4),
                                                              Text('Ampliar', style: TextStyle(color: Colors.white, fontSize: 11)),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                : const Center(
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.cloud_off, color: Color(0xFF94A3B8), size: 32),
                                                        SizedBox(height: 6),
                                                        Text(
                                                          'Foto aguardando sincronização do aparelho do técnico.',
                                                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Descrição / Serviço Realizado nesta foto:',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              SelectableText(
                                                item.descricao.trim().isNotEmpty
                                                    ? item.descricao.trim()
                                                    : 'Sem descrição adicional.',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  height: 1.4,
                                                  color: item.descricao.trim().isNotEmpty
                                                      ? const Color(0xFF0F172A)
                                                      : const Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

