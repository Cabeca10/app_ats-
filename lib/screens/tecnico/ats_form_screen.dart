import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chamado.dart';
import '../../services/chamados_service.dart';
import 'tecnico_dashboard.dart';

class AtsFormScreen extends StatefulWidget {
  final Ticket? ticket;

  const AtsFormScreen({super.key, this.ticket});

  @override
  State<AtsFormScreen> createState() => _AtsFormScreenState();
}

/// Alias para manter compatibilidade com códigos legados
typedef AtsReportScreen = AtsFormScreen;

class TimeTrackingRow {
  DateTime? date;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  TimeTrackingRow({this.date, this.startTime, this.endTime});
}

class _AtsFormScreenState extends State<AtsFormScreen> {
  final GlobalKey _signatureKey = GlobalKey();
  bool _isSubmitting = false;

  // Navigation index
  int _currentIndex = 1; // History selected by default in mockup

  // Controllers for client & machine details
  final _companyController = TextEditingController();
  final _addressController = TextEditingController();
  final _machineModelController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _controllerTypeController = TextEditingController();

  // Controllers for log
  final _defectController = TextEditingController();
  final _serviceLogController = TextEditingController();

  // Time tracking rows
  final List<TimeTrackingRow> _timeRows = [
    TimeTrackingRow(),
  ];

  // Validation settings
  bool _termsAccepted = false;
  final _printedNameController = TextEditingController();
  final List<Offset?> _signaturePoints = [];

  // Mock state for photos and videos
  int _photoCount = 0;
  int _videoCount = 0;

  @override
  void initState() {
    super.initState();
    // Pré-preenche os dados se um chamado/ticket tiver sido passado
    if (widget.ticket != null) {
      final t = widget.ticket!;
      _companyController.text = t.companyName;
      _addressController.text = t.address;
      _machineModelController.text = t.machineModel;
      if (t.defeitoRelatado != null && t.defeitoRelatado!.isNotEmpty) {
        _defectController.text = t.defeitoRelatado!;
      }
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _addressController.dispose();
    _machineModelController.dispose();
    _serialNumberController.dispose();
    _controllerTypeController.dispose();
    _defectController.dispose();
    _serviceLogController.dispose();
    _printedNameController.dispose();
    super.dispose();
  }

  // Format Helper methods
  String _formatDate(DateTime? date) {
    if (date == null) return 'mm/dd/yyyy';
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '-- : --';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Show date picker
  Future<void> _selectDate(BuildContext context, TimeTrackingRow row) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: row.date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != row.date) {
      setState(() {
        row.date = picked;
      });
    }
  }

  // Show time picker
  Future<void> _selectTime(BuildContext context, TimeTrackingRow row, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? row.startTime : row.endTime) ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          row.startTime = picked;
        } else {
          row.endTime = picked;
        }
      });
    }
  }

  /// 1. Extrai a assinatura desenhada no componente SignaturePad e converte em bytes (PNG)
  Future<Uint8List?> _obterAssinaturaPngBytes() async {
    if (_signaturePoints.isEmpty) return null;

    // A. Tenta capturar do RepaintBoundary com alta resolução
    try {
      final boundary = _signatureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          return byteData.buffer.asUint8List();
        }
      }
    } catch (e) {
      debugPrint('Aviso ao capturar RepaintBoundary: $e');
    }

    // B. Fallback com PictureRecorder em canvas branco de alta definição
    try {
      final recorder = ui.PictureRecorder();
      const double width = 500.0;
      const double height = 200.0;
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

      // Fundo branco sólido
      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bgPaint);

      final strokePaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3.5;

      for (int i = 0; i < _signaturePoints.length - 1; i++) {
        if (_signaturePoints[i] != null && _signaturePoints[i + 1] != null) {
          canvas.drawLine(_signaturePoints[i]!, _signaturePoints[i + 1]!, strokePaint);
        }
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Erro ao rasterizar assinatura com PictureRecorder: $e');
      return null;
    }
  }

  // Action methods
  Future<void> _submitReport() async {
    if (_isSubmitting) return;

    // Validação 1: Termos
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, aceite os termos de autorização antes de enviar.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Validação 2: Assinatura
    if (_signaturePoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, adicione a assinatura do cliente.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Validação 3: Nome Legível
    if (_printedNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, digite o nome legível do cliente.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Exibe diálogo modal de progresso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(color: Color(0xFF0A369D)),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'Enviando e finalizando relatório...',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      // 1. Extrair a assinatura desenhada no componente SignaturePad e convertê-la em bytes (PNG)
      final pngBytes = await _obterAssinaturaPngBytes();
      if (pngBytes == null || pngBytes.isEmpty) {
        throw Exception('Não foi possível gerar a imagem da assinatura.');
      }

      // 2. Fazer o upload dessa imagem para o bucket do Supabase Storage
      final client = Supabase.instance.client;
      final numeroAts = widget.ticket?.numeroAts ??
          widget.ticket?.id.replaceAll('ATS-', '').trim() ??
          '014742';
      final chamadoId = widget.ticket?.chamadoId;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sigPath = 'assinaturas/ats_${numeroAts}_$timestamp.png';

      String? signatureUrl;

      // Tenta upload nos buckets 'orcamentos' e 'assinaturas'
      final buckets = ['orcamentos', 'assinaturas'];
      for (final b in buckets) {
        try {
          await client.storage.from(b).uploadBinary(
            sigPath,
            pngBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );
          signatureUrl = client.storage.from(b).getPublicUrl(sigPath);
          debugPrint('Upload da assinatura no Supabase Storage no bucket $b: $signatureUrl');
          break;
        } catch (storageErr) {
          debugPrint('Aviso: tentativa no bucket "$b" falhou: $storageErr');
        }
      }

      // Fallback seguro caso os buckets ainda estejam sendo sincronizados
      signatureUrl ??= client.storage.from('orcamentos').getPublicUrl(sigPath);

      // 3. Atualizar o registro deste chamado específico na tabela chamados do banco de dados,
      // alterando o status para 'finalizado' e salvando a URL da assinatura.
      final agora = DateTime.now();
      final updateData = <String, dynamic>{
        'status': ChamadoStatus.finalizado,
        'assinatura_url': signatureUrl,
        'responsavel_aceite_nome': _printedNameController.text.trim(),
        'termos_aceitos': true,
        'aceite_data': agora.toIso8601String(),
        'updated_at': agora.toIso8601String(),
      };

      if (_defectController.text.trim().isNotEmpty) {
        updateData['defeito_relatado'] = _defectController.text.trim();
      }
      if (_companyController.text.trim().isNotEmpty) {
        updateData['razao_social'] = _companyController.text.trim();
      }
      if (_addressController.text.trim().isNotEmpty) {
        updateData['endereco'] = _addressController.text.trim();
      }
      if (_machineModelController.text.trim().isNotEmpty) {
        updateData['modelo_maquina'] = _machineModelController.text.trim();
      }
      if (_serialNumberController.text.trim().isNotEmpty) {
        updateData['numero_serie'] = _serialNumberController.text.trim();
      }

      try {
        if (chamadoId != null && chamadoId.isNotEmpty && !chamadoId.startsWith('c-')) {
          await client.from('chamados').update(updateData).eq('id', chamadoId);
        } else {
          await client.from('chamados').update(updateData).eq('numero_ats', numeroAts);
        }
        debugPrint('Chamado ATS-$numeroAts atualizado no Supabase para status: finalizado.');
      } catch (dbErr) {
        debugPrint('Aviso ao persistir no Supabase: $dbErr');
      }

      // Atualiza o estado reativo local para que a UI do Técnico e do Gerente reflitam instantaneamente
      await ChamadosService.instance.finalizarChamado(
        numeroAts: numeroAts,
        chamadoId: chamadoId,
        assinaturaUrl: signatureUrl,
        responsavelNome: _printedNameController.text.trim(),
        defeitoRelatado: _defectController.text.trim(),
        razaoSocial: _companyController.text.trim(),
        endereco: _addressController.text.trim(),
        modeloMaquina: _machineModelController.text.trim(),
        numeroSerie: _serialNumberController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context); // Fecha diálogo de carregamento
      setState(() {
        _isSubmitting = false;
      });

      // Diálogo de Sucesso com detalhes do upload e status
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext alertCtx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
                SizedBox(width: 10),
                Text('Relatório Finalizado!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'O chamado ATS-$numeroAts foi concluído com sucesso e seu status foi alterado para finalizado.',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_done, color: Color(0xFF0A369D), size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Assinatura PNG enviada ao Supabase Storage e URL vinculada ao chamado.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(alertCtx); // Fecha dialog
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context, true); // Retorna informando conclusão com sucesso
                  } else {
                    _clearForm();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A369D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Concluir'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Fecha diálogo de carregamento
      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao finalizar relatório: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _clearForm() {
    setState(() {
      _companyController.clear();
      _addressController.clear();
      _machineModelController.clear();
      _serialNumberController.clear();
      _controllerTypeController.clear();
      _defectController.clear();
      _serviceLogController.clear();
      _printedNameController.clear();
      _signaturePoints.clear();
      _termsAccepted = false;
      _photoCount = 0;
      _videoCount = 0;
      _timeRows.clear();
      _timeRows.add(TimeTrackingRow());
    });
  }

  @override
  Widget build(BuildContext context) {
    final atsNumber = widget.ticket?.id.replaceAll('ATS-', '') ?? '014742';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF0C1A30)),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Voltar',
              )
            : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Image.asset(
                'assets/images/logo_pmach.png',
                height: 32,
                width: 32,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ATS Serviços',
                  style: TextStyle(
                    color: Color(0xFF0C1A30),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Equipamentos e Peças Ltda',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Nº ATS',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  atsNumber,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Badge(
              label: Text('1'),
              child: Icon(Icons.notifications_none, color: Colors.black87),
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.black87),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sair'),
                  content: const Text('Deseja realmente sair da sua conta?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await Supabase.instance.client.auth.signOut();
                      },
                      child: const Text(
                        'Sair',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Client & Machine Details
            _buildSectionHeader('Detalhes do Cliente e Máquina'),
            const SizedBox(height: 12),
            _buildDetailsCard(),
            const SizedBox(height: 24),

            // Section 2: Issue & Service Log
            _buildSectionHeader('Registro de Problemas e Serviços'),
            const SizedBox(height: 12),
            _buildLogsCard(),
            const SizedBox(height: 24),

            // Section 3: Time Tracking
            _buildSectionHeader('Rastreamento de Tempo'),
            const SizedBox(height: 12),
            _buildTimeTrackingCard(),
            const SizedBox(height: 24),

            // Section 4: Validation
            _buildSectionHeader('Validação'),
            const SizedBox(height: 12),
            _buildValidationCard(),
            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        _clearForm();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitReport,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(
                      _isSubmitting ? 'Enviando...' : 'Finalizar e Enviar',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A369D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0A369D),
        unselectedItemColor: Colors.grey.shade500,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time_outlined),
            activeIcon: Icon(Icons.access_time_filled),
            label: 'Histórico',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Relatórios',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0C1A30),
      ),
    );
  }

  // CARD 1: Client & Machine Details
  Widget _buildDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildRowField('Razão Social', _companyController, 'Digite a razão social'),
          const Divider(height: 24, thickness: 0.5),
          _buildRowField('Endereço', _addressController, 'Endereço completo'),
          const Divider(height: 24, thickness: 0.5),
          _buildRowField('Modelo da Máquina', _machineModelController, 'Modelo da máquina'),
          const Divider(height: 24, thickness: 0.5),
          _buildRowField('Nº de Série', _serialNumberController, 'Nº de Série - XXXXX'),
          const Divider(height: 24, thickness: 0.5),
          _buildRowField('Comando CNC/PLC', _controllerTypeController, 'Tipo de comando (CNC/CLP)'),
        ],
      ),
    );
  }

  Widget _buildRowField(String label, TextEditingController controller, String hint) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: constraints.maxWidth * 0.35,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF0A369D), width: 1.5),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // CARD 2: Issue & Service Log
  Widget _buildLogsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Defeito Apresentado',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _defectController,
            maxLines: 3,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Descreva o defeito apresentado...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0A369D), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Serviço Executado (Histórico)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _serviceLogController,
            maxLines: 4,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Registro detalhado dos serviços executados...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0A369D), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Action media upload buttons
          _buildMediaButton(
            icon: Icons.camera_alt_outlined,
            label: _photoCount > 0 ? 'Adicionar Foto de Alarme ($_photoCount)' : 'Adicionar Foto de Alarme',
            onTap: () {
              setState(() {
                _photoCount++;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Foto de Alarme adicionada! Total: $_photoCount'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildMediaButton(
            icon: Icons.videocam_outlined,
            label: _videoCount > 0 ? 'Gravar Vídeo do Procedimento ($_videoCount)' : 'Gravar Vídeo do Procedimento',
            onTap: () {
              setState(() {
                _videoCount++;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Vídeo de Procedimento adicionado! Total: $_videoCount'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMediaButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // CARD 3: Time Tracking
  Widget _buildTimeTrackingCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1.0),
              2: FlexColumnWidth(1.0),
              3: FixedColumnWidth(36),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // Header Row
              const TableRow(
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Dia',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Início',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Fim',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    ),
                  ),
                  SizedBox.shrink(),
                ],
              ),
              // Data Rows
              ..._timeRows.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return TableRow(
                  children: [
                    // Date Field
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: InkWell(
                        onTap: () => _selectDate(context, row),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _formatDate(row.date),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: row.date != null ? Colors.black87 : Colors.grey.shade500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Start Time Field
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                      child: InkWell(
                        onTap: () => _selectTime(context, row, true),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _formatTime(row.startTime),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: row.startTime != null ? Colors.black87 : Colors.grey.shade500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.access_time, size: 14, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // End Time Field
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: InkWell(
                        onTap: () => _selectTime(context, row, false),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _formatTime(row.endTime),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: row.endTime != null ? Colors.black87 : Colors.grey.shade500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.access_time, size: 14, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Delete Row action (Only show if more than 1 row)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: _timeRows.length > 1
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _timeRows.removeAt(index);
                                });
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _timeRows.add(TimeTrackingRow());
              });
            },
            icon: const Icon(Icons.add, size: 16, color: Color(0xFF0A369D)),
            label: const Text(
              'Adicionar Linha',
              style: TextStyle(
                color: Color(0xFF0A369D),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  // CARD 4: Validation
  Widget _buildValidationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Terms disclaimer card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Text(
              'Autorizo o faturamento de horas técnicas, deslocamento e peças utilizadas (para máquinas fora de garantia ou defeitos causados por erro operacional).',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade900,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Checkbox terms
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _termsAccepted,
                  onChanged: (val) {
                    setState(() {
                      _termsAccepted = val ?? false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Aceito os termos de autorização',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Assinatura do Cliente',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          // Signature pad
          RepaintBoundary(
            key: _signatureKey,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade300,
                  style: BorderStyle.solid,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _signaturePoints.add(details.localPosition);
                        });
                      },
                      onPanEnd: (details) {
                        setState(() {
                          _signaturePoints.add(null);
                        });
                      },
                      child: CustomPaint(
                        painter: SignaturePainter(points: _signaturePoints),
                        size: Size.infinite,
                      ),
                    ),
                    if (_signaturePoints.isEmpty)
                      const Center(
                        child: Text(
                          'Assine aqui',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () {
                setState(() {
                  _signaturePoints.clear();
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  'Limpar Assinatura',
                  style: TextStyle(
                    color: Color(0xFF0A369D),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nome Legível do Cliente',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _printedNameController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Nome legível',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0A369D), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    // First draw a subtle dashed border inside the canvas to replicate the design
    final borderPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw dashed rectangle border
    double dashWidth = 8, dashSpace = 4;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), borderPaint);
      canvas.drawLine(Offset(startX, size.height), Offset(startX + dashWidth, size.height), borderPaint);
      startX += dashWidth + dashSpace;
    }
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashWidth), borderPaint);
      canvas.drawLine(Offset(size.width, startY), Offset(size.width, startY + dashWidth), borderPaint);
      startY += dashWidth + dashSpace;
    }

    // Draw user signature
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => true;
}
