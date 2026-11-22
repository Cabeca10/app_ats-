import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/ats_documentacao.dart';
import '../../models/chamado.dart';
import '../../services/ats_documentacao_service.dart';
import 'ats_form_screen.dart';
import 'tecnico_dashboard.dart';

class _FotoDocEntry {
  FotoDocumentacaoItem item;
  final TextEditingController descricaoController;
  final Uint8List? previewBytes;

  _FotoDocEntry({
    required this.item,
    required this.descricaoController,
    this.previewBytes,
  });
}

/// Tela estrutural de Atendimento do Técnico com navegação em 3 Abas:
/// 1. Documentar (Bloco de notas de campo estilo OneNote e fotos com descritivo)
/// 2. Relatório (Formulário ATS completo)
/// 3. Chat IA (Assistente de diagnóstico e manuais de serviço)
class AtendimentoScreen extends StatefulWidget {
  final Ticket? ticket;
  final Chamado? chamado;
  final bool isRevisao;
  final int initialTabIndex;

  const AtendimentoScreen({
    super.key,
    this.ticket,
    this.chamado,
    this.isRevisao = false,
    this.initialTabIndex = 1,
  });

  @override
  State<AtendimentoScreen> createState() => _AtendimentoScreenState();
}

class _AtendimentoScreenState extends State<AtendimentoScreen> {
  late int _currentIndex;

  late final String _chamadoId;
  late final String _numeroAts;
  late final String _razaoSocial;
  late final String _modeloMaquina;
  late final String _fabricante;

  // Estado da Aba 1 (Documentar)
  final TextEditingController _notasController = TextEditingController();
  final List<_FotoDocEntry> _fotosEntries = [];
  bool _carregandoDoc = true;
  bool _salvandoDoc = false;
  bool _enviandoFoto = false;
  int _uploadAtual = 0;
  int _uploadTotal = 0;
  bool _pendingSyncDoc = false;

  final ImagePicker _picker = ImagePicker();
  final DateFormat _docDateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _numeroAts = widget.chamado?.numeroAts ?? widget.ticket?.numeroAts ?? '000000';
    _chamadoId = widget.chamado?.id ?? widget.ticket?.chamadoId ?? widget.ticket?.id ?? '';
    _razaoSocial = widget.chamado?.razaoSocial ?? widget.ticket?.companyName ?? 'Cliente não informado';
    _modeloMaquina = widget.chamado?.modeloMaquina ?? widget.ticket?.machineModel ?? 'Máquina Industrial';
    _fabricante = widget.chamado?.fabricante ?? 'Pmach';

    _carregarDocumentacao();
  }

  @override
  void dispose() {
    _notasController.dispose();
    for (final entry in _fotosEntries) {
      entry.descricaoController.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarDocumentacao() async {
    if (_chamadoId.isEmpty) {
      setState(() => _carregandoDoc = false);
      return;
    }

    setState(() => _carregandoDoc = true);

    try {
      final doc = await AtsDocumentacaoService.instance.obterDocumentacao(_chamadoId);
      if (mounted) {
        setState(() {
          _notasController.text = doc.anotacoesCampo;
          for (final old in _fotosEntries) {
            old.descricaoController.dispose();
          }
          _fotosEntries.clear();
          for (final item in doc.itensFotos) {
            _fotosEntries.add(
              _FotoDocEntry(
                item: item,
                descricaoController: TextEditingController(text: item.descricao),
              ),
            );
          }
          _pendingSyncDoc = doc.pendingSync;
          _carregandoDoc = false;
        });
      }
    } catch (e) {
      debugPrint('[AtendimentoScreen] Erro ao carregar documentação: $e');
      if (mounted) {
        setState(() => _carregandoDoc = false);
      }
    }
  }

  Future<void> _salvarDocumentacao({bool silencioso = false}) async {
    if (_chamadoId.isEmpty) return;

    setState(() => _salvandoDoc = true);

    try {
      for (final entry in _fotosEntries) {
        entry.item = entry.item.copyWith(
          descricao: entry.descricaoController.text.trim(),
        );
      }

      final docAtualizado = await AtsDocumentacaoService.instance.salvarDocumentacao(
        chamadoId: _chamadoId,
        anotacoes: _notasController.text.trim(),
        itensFotos: _fotosEntries.map((e) => e.item).toList(),
      );

      if (mounted) {
        setState(() {
          for (int i = 0; i < _fotosEntries.length && i < docAtualizado.itensFotos.length; i++) {
            _fotosEntries[i].item = docAtualizado.itensFotos[i];
          }
          _pendingSyncDoc = docAtualizado.pendingSync;
          _salvandoDoc = false;
        });

        if (!silencioso) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_pendingSyncDoc
                  ? 'Anotações salvas localmente no dispositivo (offline).'
                  : 'Documentação sincronizada com sucesso na nuvem!'),
              backgroundColor: _pendingSyncDoc ? Colors.orange.shade800 : const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _salvandoDoc = false);
        if (!silencioso) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao salvar documentação: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _adicionarFotoCamera() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
      );

      if (picked != null) {
        await _processarArquivosSelecionados([picked]);
      }
    } catch (e) {
      debugPrint('[AtendimentoScreen] Erro ao capturar foto pela câmera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir câmera: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _adicionarFotosGaleria() async {
    try {
      final pickedList = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
      );

      if (pickedList.isNotEmpty) {
        await _processarArquivosSelecionados(pickedList);
      }
    } catch (e) {
      debugPrint('[AtendimentoScreen] Erro ao selecionar fotos da galeria: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar fotos da galeria: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _processarArquivosSelecionados(List<XFile> arquivos) async {
    final arquivosValidos = <XFile>[];
    int svgIgnorados = 0;

    for (final arquivo in arquivos) {
      if (arquivo.name.trim().toLowerCase().endsWith('.svg')) {
        svgIgnorados++;
      } else {
        arquivosValidos.add(arquivo);
      }
    }

    if (svgIgnorados > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            svgIgnorados == 1
                ? 'Formato SVG não é permitido por segurança.'
                : '$svgIgnorados arquivos SVG ignorados (formato não permitido por segurança).',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    if (arquivosValidos.isEmpty) return;

    if (mounted) {
      setState(() {
        _enviandoFoto = true;
        _uploadAtual = 0;
        _uploadTotal = arquivosValidos.length;
      });
    }

    int adicionadas = 0;

    try {
      for (int i = 0; i < arquivosValidos.length; i++) {
        final picked = arquivosValidos[i];
        if (!mounted) break;

        setState(() => _uploadAtual = i + 1);

        final bytes = await picked.readAsBytes();
        final fileName = picked.name.trim().isNotEmpty
            ? picked.name.trim()
            : 'foto_${DateTime.now().millisecondsSinceEpoch}_${i + 1}.jpg';

        String? uploadedUrl;
        try {
          uploadedUrl = await AtsDocumentacaoService.instance.uploadFotoBytes(
            chamadoId: _chamadoId,
            bytes: bytes,
            fileName: fileName,
          );
        } catch (upErr) {
          debugPrint('[AtendimentoScreen] Aviso upload imediato da foto $fileName: $upErr');
        }

        final newItem = FotoDocumentacaoItem(
          url: uploadedUrl ?? '',
          localPath: kIsWeb ? '' : picked.path,
          categoria: _fotosEntries.isEmpty ? 'Alarme / Falha' : 'Serviço Realizado',
          criadoEm: DateTime.now(),
        );

        if (!mounted) break;
        setState(() {
          _fotosEntries.add(
            _FotoDocEntry(
              item: newItem,
              descricaoController: TextEditingController(),
              previewBytes: bytes,
            ),
          );
        });
        adicionadas++;
      }
    } catch (e) {
      debugPrint('[AtendimentoScreen] Erro ao processar fotos selecionadas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar foto(s): $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _enviandoFoto = false;
          _uploadAtual = 0;
          _uploadTotal = 0;
        });
      }
    }

    if (adicionadas > 0 && mounted) {
      await _salvarDocumentacao(silencioso: true);
      if (adicionadas > 1 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$adicionadas fotos adicionadas em sequência! Agora escreva a anotação abaixo de cada uma.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removerFoto(int index) async {
    if (index < 0 || index >= _fotosEntries.length) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Foto?'),
        content: const Text('Deseja remover esta foto e a sua descrição da documentação do chamado?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    final entry = _fotosEntries[index];
    final removedUrl = entry.item.url;

    setState(() {
      _fotosEntries.removeAt(index);
    });
    entry.descricaoController.dispose();

    if (removedUrl.trim().isNotEmpty) {
      await AtsDocumentacaoService.instance.removerFotoStorage(removedUrl);
    }
    await _salvarDocumentacao(silencioso: true);
  }

  void _abrirFotoAmpliada(_FotoDocEntry entry, int numero) {
    final hasUrl = entry.item.url.trim().isNotEmpty && entry.item.url.startsWith('http');
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
                child: entry.previewBytes != null
                    ? Image.memory(entry.previewBytes!, fit: BoxFit.contain)
                    : (hasUrl
                        ? Image.network(entry.item.url, fit: BoxFit.contain)
                        : (!kIsWeb && entry.item.localPath.isNotEmpty
                            ? Image.file(File(entry.item.localPath), fit: BoxFit.contain)
                            : const Icon(Icons.broken_image, color: Colors.white, size: 48))),
              ),
            ),
            Positioned(
              top: 8,
              left: 16,
              right: 52,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Foto #$numero • ${entry.item.categoria}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isRevisao ? 'O.S. $_numeroAts (Revisão)' : 'O.S. $_numeroAts',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '$_razaoSocial • $_modeloMaquina',
              style: const TextStyle(fontSize: 11, color: Color(0xFFBFDBFE), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0A369D),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final navigator = Navigator.of(context);
            if (_currentIndex == 0) {
              await _salvarDocumentacao(silencioso: true);
            }
            if (mounted) {
              navigator.pop(false);
            }
          },
        ),
        actions: [
          if (_currentIndex == 0) // Na aba documentar
            IconButton(
              icon: _salvandoDoc
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              tooltip: 'Salvar Anotações',
              onPressed: _salvandoDoc ? null : () => _salvarDocumentacao(silencioso: false),
            ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // ABA 0: DOCUMENTAR (BLOCO DE NOTAS E FOTOS)
          _buildAbaDocumentar(),

          // ABA 1: RELATÓRIO (ATS FORM SCREEN EMBEDDED)
          AtsFormScreen(
            ticket: widget.ticket,
            chamado: widget.chamado,
            isEmbedded: true,
            isRevisao: widget.isRevisao,
          ),

          // ABA 2: CHAT IA (PLACEHOLDER E MANUAIS)
          _buildAbaChatIa(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (_currentIndex == 0 && index != 0) {
            // Auto-salva notas ao sair da aba Documentar
            _salvarDocumentacao(silencioso: true);
          }
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: const Color(0xFFDBEAFE),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.edit_note_rounded),
            selectedIcon: Icon(Icons.edit_note_rounded, color: Color(0xFF0A369D)),
            label: 'Documentar',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment, color: Color(0xFF0A369D)),
            label: 'Relatório',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy, color: Color(0xFF0A369D)),
            label: 'Chat IA',
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // ABA 1: DOCUMENTAR (ESTILO ONENOTE / BLOCO DE CAMPO)
  // ============================================================================
  Widget _buildAbaDocumentar() {
    if (_carregandoDoc) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0A369D)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de Status da Documentação
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _pendingSyncDoc ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _pendingSyncDoc ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _pendingSyncDoc ? Icons.cloud_queue : Icons.cloud_done,
                  color: _pendingSyncDoc ? Colors.orange.shade800 : const Color(0xFF059669),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _pendingSyncDoc
                        ? 'Anotações em cache local (pendente de envio)'
                        : 'Documentação de campo sincronizada na nuvem',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _pendingSyncDoc ? Colors.orange.shade900 : const Color(0xFF065F46),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _salvandoDoc ? null : () => _salvarDocumentacao(silencioso: false),
                  child: Text(
                    _salvandoDoc ? 'Salvando...' : 'Salvar',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card de Anotações Técnicas
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFFDE68A)),
            ),
            color: const Color(0xFFFFFEF5),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: Color(0xFF0A369D), size: 22),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Anotações Gerais e Ajustes (Estilo OneNote)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Anote códigos de alarme, parâmetros ajustados, peças trocadas e observações técnicas deste chamado.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notasController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Digite aqui suas anotações gerais e ajustes efetuados...\nEx: Alarme AL-11 no drive X; reapertado conector CN3 e calibrado ganho em 120 bar.',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF0A369D), width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Card de Galeria de Fotos de Campo com Descritivo Individual abaixo de cada foto
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_outlined, color: Color(0xFF0A369D)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Registro Fotográfico e Descritivo (${_fotosEntries.length})',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _enviandoFoto ? null : _adicionarFotoCamera,
                            icon: _enviandoFoto
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.camera_alt, size: 16),
                            label: const Text('Tirar Foto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A369D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _enviandoFoto ? null : _adicionarFotosGaleria,
                            icon: const Icon(Icons.collections_outlined, size: 16),
                            label: const Text('Galeria (Várias)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0A369D),
                              side: const BorderSide(color: Color(0xFF93C5FD)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Selecione várias fotos de uma só vez pela Galeria ou tire com a Câmera, e escreva logo abaixo de cada foto o que foi feito ali.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  if (_enviandoFoto) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _uploadTotal > 1
                                ? 'Enviando foto $_uploadAtual de $_uploadTotal...'
                                : 'Enviando foto...',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _uploadTotal > 1
                                  ? (_uploadAtual / _uploadTotal).clamp(0.0, 1.0)
                                  : null,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFDBEAFE),
                              color: const Color(0xFF0A369D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  if (_fotosEntries.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 38, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Nenhuma foto adicionada ainda.\nCapture uma foto do alarme ou do serviço para documentar embaixo dela.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Column(
                      children: _fotosEntries.asMap().entries.map((mapEntry) {
                        final index = mapEntry.key;
                        final entry = mapEntry.value;
                        final hasUrl = entry.item.url.trim().isNotEmpty && entry.item.url.startsWith('http');

                        Widget imagePreview;
                        if (entry.previewBytes != null) {
                          imagePreview = Image.memory(entry.previewBytes!, fit: BoxFit.contain);
                        } else if (hasUrl) {
                          imagePreview = Image.network(
                            entry.item.url,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator(color: Color(0xFF0A369D)));
                            },
                            errorBuilder: (context, error, stackTrace) {
                              if (!kIsWeb && entry.item.localPath.isNotEmpty) {
                                return Image.file(File(entry.item.localPath), fit: BoxFit.contain);
                              }
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image_outlined, size: 36, color: Color(0xFF94A3B8)),
                                    SizedBox(height: 4),
                                    Text('Não foi possível carregar a foto', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  ],
                                ),
                              );
                            },
                          );
                        } else if (!kIsWeb && entry.item.localPath.isNotEmpty) {
                          imagePreview = Image.file(File(entry.item.localPath), fit: BoxFit.contain);
                        } else {
                          imagePreview = const Center(
                            child: Icon(Icons.image_not_supported_outlined, size: 36, color: Color(0xFF94A3B8)),
                          );
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Cabeçalho do card da foto em 2 linhas para evitar cortes no celular
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0A369D),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Foto #${index + 1}',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _docDateFormat.format(entry.item.criadoEm),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                    tooltip: 'Remover foto',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _removerFoto(index),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.label_outline_rounded, size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Categoria:',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: DropdownButton<String>(
                                          isDense: true,
                                          isExpanded: true,
                                          value: FotoDocumentacaoItem.categoriasPadrao.contains(entry.item.categoria)
                                              ? entry.item.categoria
                                              : FotoDocumentacaoItem.categoriasPadrao.first,
                                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                                          items: FotoDocumentacaoItem.categoriasPadrao
                                              .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                                              .toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() {
                                                entry.item = entry.item.copyWith(categoria: val);
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Visualização da foto (clique para ampliar)
                              GestureDetector(
                                onTap: () => _abrirFotoAmpliada(entry, index + 1),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 240,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: imagePreview,
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
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Campo OneNote embaixo da foto
                              TextField(
                                controller: entry.descricaoController,
                                minLines: 2,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  labelText: 'Anotação desta foto',
                                  alignLabelWithHint: true,
                                  hintText: 'Descreva o alarme, ajuste ou serviço realizado nesta foto...',
                                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF0A369D), width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _enviandoFoto ? null : _adicionarFotoCamera,
                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                          label: const Text('Tirar Foto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0A369D),
                            side: const BorderSide(color: Color(0xFF93C5FD)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _enviandoFoto ? null : _adicionarFotosGaleria,
                          icon: const Icon(Icons.collections_outlined, size: 16),
                          label: const Text('+ Adicionar Mais Fotos (Galeria)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0A369D),
                            side: const BorderSide(color: Color(0xFF93C5FD)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Botão principal para salvar toda a documentação na nuvem
          ElevatedButton.icon(
            onPressed: _salvandoDoc ? null : () => _salvarDocumentacao(silencioso: false),
            icon: _salvandoDoc
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_rounded, size: 20),
            label: Text(
              _salvandoDoc ? 'Salvando Documentação...' : 'Salvar Documentação na Nuvem',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A369D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ============================================================================
  // ABA 3: CHAT IA (ASSISTENTE E CONSULTA A MANUAIS)
  // ============================================================================
  Widget _buildAbaChatIa() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card de Apresentação da IA
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A369D), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pmach IA Diagnóstico',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Assistente Técnico Inteligente',
                              style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981)),
                        ),
                        child: const Text(
                          'EM BREVE',
                          style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Na próxima versão, você poderá conversar diretamente com os manuais de serviço e diagramas elétricos da máquina ($_modeloMaquina - $_fabricante) no estilo NotebookLM.',
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChipRecurso('Busca Semântica em PDFs'),
                      _buildChipRecurso('Códigos de Falha / Alarmes'),
                      _buildChipRecurso('Roteiro Guiado de Reparo'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Seção de Manuais Técnicos Vinculados
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Manuais Técnicos da Máquina',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          _modeloMaquina,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Acesse documentações de bancada e esquemas hidráulicos e elétricos cadastrados:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),

                  _buildItemManual(
                    titulo: 'Manual de Manutenção - $_modeloMaquina',
                    descricao: 'Tabela de códigos de alarmes, tolerâncias e torques',
                    tamanho: '5.4 MB',
                    icone: Icons.picture_as_pdf,
                  ),
                  const Divider(height: 16),
                  _buildItemManual(
                    titulo: 'Esquema Elétrico e Painel CNC',
                    descricao: 'Diagrama unifilar e bornes de CLP / Inversores',
                    tamanho: '2.1 MB',
                    icone: Icons.electrical_services,
                  ),
                  const Divider(height: 16),
                  _buildItemManual(
                    titulo: 'Guia de Lubrificação e Ajuste do Barramento',
                    descricao: 'Intervalos recomendados e especificação de óleos ISO-VG',
                    tamanho: '1.2 MB',
                    icone: Icons.build_circle_outlined,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipRecurso(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildItemManual({
    required String titulo,
    required String descricao,
    required String tamanho,
    required IconData icone,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icone, color: const Color(0xFF0A369D), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                descricao,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Text(
          tamanho,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.visibility_outlined, size: 20, color: Color(0xFF0A369D)),
          tooltip: 'Visualizar Manual',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Abrindo manual: $titulo'),
                backgroundColor: const Color(0xFF0A369D),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
    );
  }
}
