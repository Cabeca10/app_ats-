import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/chamado.dart';
import '../../services/ats_documentacao_service.dart';
import 'ats_form_screen.dart';
import 'tecnico_dashboard.dart';

/// Tela estrutural de Atendimento do Técnico com navegação em 3 Abas:
/// 1. Documentar (Bloco de notas de campo e fotos)
/// 2. Relatório (Formulário ATS completo)
/// 3. Chat IA (Assistente de diagnóstico e manuais de serviço)
class AtendimentoScreen extends StatefulWidget {
  final Ticket? ticket;
  final Chamado? chamado;

  const AtendimentoScreen({
    super.key,
    this.ticket,
    this.chamado,
  });

  @override
  State<AtendimentoScreen> createState() => _AtendimentoScreenState();
}

class _AtendimentoScreenState extends State<AtendimentoScreen> {
  int _currentIndex = 1; // Inicia na aba central 'Relatório' ou 'Documentar'

  late final String _chamadoId;
  late final String _numeroAts;
  late final String _razaoSocial;
  late final String _modeloMaquina;
  late final String _fabricante;

  // Estado da Aba 1 (Documentar)
  final TextEditingController _notasController = TextEditingController();
  final List<String> _fotosLocais = [];
  final List<String> _fotosUrls = [];
  bool _carregandoDoc = true;
  bool _salvandoDoc = false;
  bool _pendingSyncDoc = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
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
          _fotosLocais.clear();
          _fotosLocais.addAll(doc.localFotosPaths);
          _fotosUrls.clear();
          _fotosUrls.addAll(doc.fotosUrls);
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
      final docAtualizado = await AtsDocumentacaoService.instance.salvarDocumentacao(
        chamadoId: _chamadoId,
        anotacoes: _notasController.text.trim(),
        localFotosPaths: _fotosLocais,
        fotosUrlsExistentes: _fotosUrls,
      );

      if (mounted) {
        setState(() {
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
              content: Text('Erro ao salvar notas: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _adicionarFoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
      );

      if (picked != null) {
        setState(() {
          _fotosLocais.add(picked.path);
        });
        await _salvarDocumentacao(silencioso: true);
      }
    } catch (e) {
      debugPrint('[AtendimentoScreen] Erro ao capturar foto: $e');
    }
  }

  void _removerFoto(int index) {
    setState(() {
      _fotosLocais.removeAt(index);
    });
    _salvarDocumentacao(silencioso: true);
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
              'O.S. $_numeroAts',
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
          onPressed: () => Navigator.pop(context, true),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit_note, color: Color(0xFF0A369D)),
                      SizedBox(width: 8),
                      Text(
                        'Notas de Campo (Estilo OneNote)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Anote dados rápidos de medição, diagnóstico, peças substituídas ou observações de campo.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notasController,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: 'Digite aqui suas anotações técnicas do atendimento...\nEx: Pressão hidráulica em 120 bar; substituído retentor do fuso; verificado alinhamento do eixo X.',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
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

          // Card de Galeria de Fotos de Campo
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
                      Row(
                        children: [
                          const Icon(Icons.photo_library_outlined, color: Color(0xFF0A369D)),
                          const SizedBox(width: 8),
                          Text(
                            'Registro Fotográfico (${_fotosLocais.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF0A369D)),
                            tooltip: 'Tirar Foto',
                            onPressed: () => _adicionarFoto(ImageSource.camera),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF0A369D)),
                            tooltip: 'Selecionar da Galeria',
                            onPressed: () => _adicionarFoto(ImageSource.gallery),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Fotos de defeitos, painel de comando, placas de identificação e peças trocadas.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),

                  if (_fotosLocais.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 36, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Nenhuma foto registrada para este atendimento.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _adicionarFoto(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt, size: 16),
                                label: const Text('Câmera'),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: () => _adicionarFoto(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library, size: 16),
                                label: const Text('Galeria'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: _fotosLocais.length,
                      itemBuilder: (context, index) {
                        final path = _fotosLocais[index];
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb
                                  ? Image.network(path, fit: BoxFit.cover)
                                  : Image.file(File(path), fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removerFoto(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
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
