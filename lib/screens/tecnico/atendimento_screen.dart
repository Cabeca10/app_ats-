import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/ats_documentacao.dart';
import '../../models/chamado.dart';
import '../../services/ats_documentacao_service.dart';
import '../../services/orientation_service.dart';
import 'ats_form_screen.dart';
import 'tecnico_dashboard.dart';

class _FotoMidiaEntry {
  FotoMidiaItem midia;
  final Uint8List? previewBytes;

  _FotoMidiaEntry({
    required this.midia,
    this.previewBytes,
  });
}

class _AssuntoDocEntry {
  FotoDocumentacaoItem item;
  final TextEditingController tituloController;
  final TextEditingController descricaoController;
  final List<_FotoMidiaEntry> fotos;

  _AssuntoDocEntry({
    required this.item,
    required this.tituloController,
    required this.descricaoController,
    required this.fotos,
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
  final List<_AssuntoDocEntry> _assuntosEntries = [];
  bool _carregandoDoc = true;
  bool _salvandoDoc = false;
  bool _enviandoFoto = false;
  String? _uploadAssuntoId;
  int _uploadAtual = 0;
  int _uploadTotal = 0;
  bool _pendingSyncDoc = false;

  final ImagePicker _picker = ImagePicker();
  final DateFormat _docDateFormat = DateFormat('dd/MM/yyyy HH:mm');

  int get _totalFotosRegistros =>
      _assuntosEntries.fold<int>(0, (sum, assunto) => sum + assunto.fotos.length);

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
    for (final entry in _assuntosEntries) {
      entry.tituloController.dispose();
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
          for (final old in _assuntosEntries) {
            old.tituloController.dispose();
            old.descricaoController.dispose();
          }
          _assuntosEntries.clear();
          for (final item in doc.itensFotos) {
            _assuntosEntries.add(
              _AssuntoDocEntry(
                item: item,
                tituloController: TextEditingController(text: item.titulo),
                descricaoController: TextEditingController(text: item.descricao),
                fotos: item.fotos.map((m) => _FotoMidiaEntry(midia: m)).toList(),
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
      for (final entry in _assuntosEntries) {
        entry.item = entry.item.copyWith(
          titulo: entry.tituloController.text.trim(),
          descricao: entry.descricaoController.text.trim(),
          fotos: entry.fotos.map((f) => f.midia).toList(),
        );
      }

      final docAtualizado = await AtsDocumentacaoService.instance.salvarDocumentacao(
        chamadoId: _chamadoId,
        anotacoes: _notasController.text.trim(),
        itensFotos: _assuntosEntries.map((e) => e.item).toList(),
      );

      if (mounted) {
        setState(() {
          for (int i = 0; i < _assuntosEntries.length && i < docAtualizado.itensFotos.length; i++) {
            final updatedItem = docAtualizado.itensFotos[i];
            _assuntosEntries[i].item = updatedItem;
            for (int j = 0; j < _assuntosEntries[i].fotos.length && j < updatedItem.fotos.length; j++) {
              _assuntosEntries[i].fotos[j].midia = updatedItem.fotos[j];
            }
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

  void _criarNovoAssunto() {
    final novoItem = FotoDocumentacaoItem(
      categoria: _assuntosEntries.isEmpty ? 'Alarme / Falha' : 'Serviço Realizado',
      criadoEm: DateTime.now(),
    );
    setState(() {
      _assuntosEntries.add(
        _AssuntoDocEntry(
          item: novoItem,
          tituloController: TextEditingController(),
          descricaoController: TextEditingController(),
          fotos: [],
        ),
      );
    });
  }

  Future<void> _adicionarFotoCamera({int? assuntoIndex}) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
      );

      if (picked != null) {
        await _processarArquivosNoAssunto([picked], assuntoIndex: assuntoIndex);
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

  Future<void> _adicionarFotosGaleria({int? assuntoIndex}) async {
    try {
      final pickedList = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
      );

      if (pickedList.isNotEmpty) {
        await _processarArquivosNoAssunto(pickedList, assuntoIndex: assuntoIndex);
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

  Future<void> _processarArquivosNoAssunto(List<XFile> arquivos, {int? assuntoIndex}) async {
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

    final _AssuntoDocEntry targetEntry;
    if (assuntoIndex != null && assuntoIndex >= 0 && assuntoIndex < _assuntosEntries.length) {
      targetEntry = _assuntosEntries[assuntoIndex];
    } else {
      final novoItem = FotoDocumentacaoItem(
        categoria: _assuntosEntries.isEmpty ? 'Alarme / Falha' : 'Serviço Realizado',
        criadoEm: DateTime.now(),
      );
      targetEntry = _AssuntoDocEntry(
        item: novoItem,
        tituloController: TextEditingController(),
        descricaoController: TextEditingController(),
        fotos: [],
      );
      if (mounted) {
        setState(() {
          _assuntosEntries.add(targetEntry);
        });
      }
    }

    if (mounted) {
      setState(() {
        _enviandoFoto = true;
        _uploadAssuntoId = targetEntry.item.id;
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

        final novaMidia = FotoMidiaItem(
          url: uploadedUrl ?? '',
          localPath: kIsWeb ? '' : picked.path,
        );

        if (!mounted) break;
        setState(() {
          targetEntry.fotos.add(
            _FotoMidiaEntry(
              midia: novaMidia,
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
          _uploadAssuntoId = null;
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
            content: Text('$adicionadas fotos adicionadas na mesma caixa! Agora escreva a anotação deste assunto.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removerFotoDoAssunto(int assuntoIndex, int fotoIndex) async {
    if (assuntoIndex < 0 || assuntoIndex >= _assuntosEntries.length) return;
    final assunto = _assuntosEntries[assuntoIndex];
    if (fotoIndex < 0 || fotoIndex >= assunto.fotos.length) return;

    final removedUrl = assunto.fotos[fotoIndex].midia.url;

    setState(() {
      assunto.fotos.removeAt(fotoIndex);
    });

    if (removedUrl.trim().isNotEmpty) {
      await AtsDocumentacaoService.instance.removerFotoStorage(removedUrl);
    }
    await _salvarDocumentacao(silencioso: true);
  }

  Future<void> _removerAssunto(int index) async {
    if (index < 0 || index >= _assuntosEntries.length) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Assunto?'),
        content: const Text('Deseja remover este assunto, todas as fotos e a anotação dele da documentação?'),
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

    final entry = _assuntosEntries[index];
    final urlsParaRemover = entry.fotos
        .map((f) => f.midia.url)
        .where((u) => u.trim().isNotEmpty)
        .toList();

    setState(() {
      _assuntosEntries.removeAt(index);
    });
    entry.tituloController.dispose();
    entry.descricaoController.dispose();

    for (final url in urlsParaRemover) {
      await AtsDocumentacaoService.instance.removerFotoStorage(url);
    }
    await _salvarDocumentacao(silencioso: true);
  }

  void _abrirGaleriaAmpliada(_AssuntoDocEntry entry, int numeroAssunto, int initialFotoIndex) {
    if (entry.fotos.isEmpty) return;

    int currentIndex = initialFotoIndex.clamp(0, entry.fotos.length - 1);
    final tituloTexto = entry.tituloController.text.trim().isNotEmpty
        ? entry.tituloController.text.trim()
        : entry.item.categoria;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final fotoAtual = entry.fotos[currentIndex];
          final hasUrl = fotoAtual.midia.hasUrl;

          Widget previewAmpliado;
          if (fotoAtual.previewBytes != null) {
            previewAmpliado = Image.memory(fotoAtual.previewBytes!, fit: BoxFit.contain);
          } else if (hasUrl) {
            previewAmpliado = Image.network(fotoAtual.midia.url, fit: BoxFit.contain);
          } else if (!kIsWeb && fotoAtual.midia.localPath.isNotEmpty) {
            previewAmpliado = Image.file(File(fotoAtual.midia.localPath), fit: BoxFit.contain);
          } else {
            previewAmpliado = const Icon(Icons.broken_image, color: Colors.white, size: 48);
          }

          return Dialog(
            backgroundColor: Colors.black87,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                InteractiveViewer(
                  key: ValueKey('tec_${entry.item.id}_$currentIndex'),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(child: previewAmpliado),
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
                      'Assunto #$numeroAssunto ($tituloTexto) • Foto ${currentIndex + 1} de ${entry.fotos.length}',
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
                if (entry.fotos.length > 1) ...[
                  if (currentIndex > 0)
                    Positioned(
                      left: 10,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 32),
                          tooltip: 'Foto anterior',
                          onPressed: () => setDialogState(() => currentIndex--),
                        ),
                      ),
                    ),
                  if (currentIndex < entry.fotos.length - 1)
                    Positioned(
                      right: 10,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 32),
                          tooltip: 'Próxima foto',
                          onPressed: () => setDialogState(() => currentIndex++),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
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
          IconButton(
            icon: const Icon(Icons.screen_rotation_rounded),
            tooltip: 'Alternar Modo Paisagem / Retrato',
            onPressed: () => OrientationService.instance.toggleOrientation(context),
          ),
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

          // Card de Registros por Assunto (sequência de fotos dentro da mesma caixa + anotação única)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              'Registros por Assunto (${_assuntosEntries.length} • $_totalFotosRegistros fotos)',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _enviandoFoto ? null : _criarNovoAssunto,
                        icon: const Icon(Icons.add_box_outlined, size: 16),
                        label: const Text('+ Novo Assunto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A369D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Adicione várias fotos em sequência dentro da mesma caixa e escreva uma anotação para o assunto. Só crie uma nova caixa quando iniciar outro assunto.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),

                  if (_assuntosEntries.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.collections_outlined, size: 38, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Nenhum assunto registrado ainda.\nSelecione várias fotos de uma só vez pela Galeria ou tire com a Câmera para montar sua primeira caixa.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _enviandoFoto ? null : () => _adicionarFotosGaleria(),
                                icon: const Icon(Icons.collections_outlined, size: 16),
                                label: const Text('Selecionar Fotos (Galeria)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A369D),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _enviandoFoto ? null : () => _adicionarFotoCamera(),
                                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                label: const Text('Tirar Foto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0A369D),
                                  side: const BorderSide(color: Color(0xFF93C5FD)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _enviandoFoto ? null : _criarNovoAssunto,
                                icon: const Icon(Icons.note_add_outlined, size: 16),
                                label: const Text('+ Criar Assunto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF334155),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Column(
                      children: _assuntosEntries.asMap().entries.map((mapEntry) {
                        final index = mapEntry.key;
                        final entry = mapEntry.value;
                        final enviandoNesteAssunto = _enviandoFoto && _uploadAssuntoId == entry.item.id;

                        Widget buildFotoItemTile(_FotoMidiaEntry fotoEntry, int fotoIdx, double height) {
                          final hasUrl = fotoEntry.midia.hasUrl;

                          Widget imagePreview;
                          if (fotoEntry.previewBytes != null) {
                            imagePreview = Image.memory(fotoEntry.previewBytes!, fit: BoxFit.contain);
                          } else if (hasUrl) {
                            imagePreview = Image.network(
                              fotoEntry.midia.url,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator(color: Color(0xFF0A369D)));
                              },
                              errorBuilder: (context, error, stackTrace) {
                                if (!kIsWeb && fotoEntry.midia.localPath.isNotEmpty) {
                                  return Image.file(File(fotoEntry.midia.localPath), fit: BoxFit.contain);
                                }
                                return const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image_outlined, size: 32, color: Color(0xFF94A3B8)),
                                      SizedBox(height: 4),
                                      Text('Erro ao carregar foto', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                );
                              },
                            );
                          } else if (!kIsWeb && fotoEntry.midia.localPath.isNotEmpty) {
                            imagePreview = Image.file(File(fotoEntry.midia.localPath), fit: BoxFit.contain);
                          } else {
                            imagePreview = const Center(
                              child: Icon(Icons.image_not_supported_outlined, size: 32, color: Color(0xFF94A3B8)),
                            );
                          }

                          return GestureDetector(
                            onTap: () => _abrirGaleriaAmpliada(entry, index + 1, fotoIdx),
                            child: Stack(
                              children: [
                                Container(
                                  height: height,
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
                                  left: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      '${fotoIdx + 1}/${entry.fotos.length}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Material(
                                    color: Colors.black54,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () => _removerFotoDoAssunto(index, fotoIdx),
                                      child: const Tooltip(
                                        message: 'Remover esta foto',
                                        child: Padding(
                                          padding: EdgeInsets.all(5),
                                          child: Icon(Icons.close_rounded, color: Colors.white, size: 15),
                                        ),
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
                            ),
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
                              // Linha 1: Assunto #N + contagem + data/hora + excluir assunto
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
                                          'Assunto #${index + 1}',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE2E8F0),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${entry.fotos.length} ${entry.fotos.length == 1 ? "foto" : "fotos"}',
                                          style: const TextStyle(color: Color(0xFF334155), fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _docDateFormat.format(entry.item.criadoEm),
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                        tooltip: 'Remover assunto completo',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _removerAssunto(index),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Linha 2: Categoria em largura total (sem cortes no celular)
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

                              // Linha 3: Assunto / Título opcional
                              TextField(
                                controller: entry.tituloController,
                                decoration: InputDecoration(
                                  labelText: 'Assunto / Título (opcional)',
                                  hintText: 'Ex: Alarme AL-11 no drive X / Troca do cabo encoder',
                                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                  isDense: true,
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
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Linha 4: Sequência de fotos dentro desta mesma caixa
                              if (entry.fotos.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    'Nenhuma foto neste assunto ainda. Adicione fotos abaixo nesta mesma caixa.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                )
                              else if (entry.fotos.length == 1)
                                buildFotoItemTile(entry.fotos.first, 0, 220)
                              else ...[
                                Text(
                                  'Sequência de fotos (${entry.fotos.length}) — deslize para o lado ou toque para ampliar',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 210,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: entry.fotos.length,
                                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                                    itemBuilder: (ctx, fotoIdx) => SizedBox(
                                      width: 230,
                                      child: buildFotoItemTile(entry.fotos[fotoIdx], fotoIdx, 210),
                                    ),
                                  ),
                                ),
                              ],

                              if (enviandoNesteAssunto) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
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
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: _uploadTotal > 1
                                              ? (_uploadAtual / _uploadTotal).clamp(0.0, 1.0)
                                              : null,
                                          minHeight: 5,
                                          backgroundColor: const Color(0xFFDBEAFE),
                                          color: const Color(0xFF0A369D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _enviandoFoto ? null : () => _adicionarFotoCamera(assuntoIndex: index),
                                    icon: const Icon(Icons.camera_alt_outlined, size: 15),
                                    label: const Text('Tirar Foto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0A369D),
                                      side: const BorderSide(color: Color(0xFF93C5FD)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _enviandoFoto ? null : () => _adicionarFotosGaleria(assuntoIndex: index),
                                    icon: const Icon(Icons.collections_outlined, size: 15),
                                    label: const Text('+ Fotos nesta caixa (Galeria)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEFF6FF),
                                      foregroundColor: const Color(0xFF0A369D),
                                      elevation: 0,
                                      side: const BorderSide(color: Color(0xFF93C5FD)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Linha 5: Um único campo de anotação para todo este assunto
                              TextField(
                                controller: entry.descricaoController,
                                minLines: 3,
                                maxLines: 6,
                                decoration: InputDecoration(
                                  labelText: 'Anotação deste assunto',
                                  alignLabelWithHint: true,
                                  hintText: 'Descreva tudo o que foi observado, ajustado ou executado nesta sequência de fotos...',
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
                    OutlinedButton.icon(
                      onPressed: _enviandoFoto ? null : _criarNovoAssunto,
                      icon: const Icon(Icons.add_box_outlined, size: 18),
                      label: const Text(
                        '+ Novo Assunto (Nova Caixa)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0A369D),
                        side: const BorderSide(color: Color(0xFF0A369D)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
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
