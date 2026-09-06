import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/tecnico/tecnico_dashboard.dart';
import 'screens/gerente/gerente_dashboard.dart';
import 'screens/cliente/orcamento_client_screen.dart';

class AppAuthState {
  static String selectedRole = 'Técnico'; // 'Técnico' or 'Gerente'
  static bool bypassAuth = false;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // TODO: Replace with your actual Supabase URL and Anon Key
  await Supabase.initialize(
    url: 'https://your-supabase-url.supabase.co',
    // ignore: deprecated_member_use
    anonKey: 'your-supabase-anon-key',
  );

  runApp(const MyApp());
}

/// Extrai o token público de orçamento a partir da rota ou da URL do navegador (Web)
String? _extrairTokenPublico(Uri uri) {
  // 1. Verifica parâmetro de query ?token=...
  if (uri.queryParameters.containsKey('token') && uri.queryParameters['token']!.isNotEmpty) {
    return uri.queryParameters['token'];
  }

  // 2. Verifica segmentos de caminho: /orcamento/:token ou /aprovar/:token
  if (uri.pathSegments.isNotEmpty) {
    final first = uri.pathSegments.first.toLowerCase();
    if ((first == 'orcamento' || first == 'aprovar') && uri.pathSegments.length > 1) {
      final possibleToken = uri.pathSegments[1].trim();
      if (possibleToken.isNotEmpty) return possibleToken;
    }
  }

  // 3. Suporte ao padrão de hash routing do Flutter Web: /#/orcamento?token=... ou /#/aprovar/...
  if (uri.hasFragment && uri.fragment.isNotEmpty) {
    try {
      final fragmentPath = uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}';
      final fragmentUri = Uri.parse(fragmentPath);
      return _extrairTokenPublico(fragmentUri);
    } catch (_) {}
  }

  return null;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Detecta se a URL inicial do navegador na Web já possui o token público
    final webInitialToken = _extrairTokenPublico(Uri.base);

    return MaterialApp(
      title: 'ATS Serviços - Equipamentos e Peças Ltda',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A369D),
          primary: const Color(0xFF0A369D),
          secondary: const Color(0xFF4A90E2),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      // Se na inicialização web houver token, abre DIRETO o orçamento sem passar pelo AuthWrapper
      home: webInitialToken != null ? OrcamentoClientScreen(token: webInitialToken) : null,
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');
        final publicToken = _extrairTokenPublico(uri) ?? _extrairTokenPublico(Uri.base);

        if (publicToken != null) {
          return MaterialPageRoute(
            builder: (_) => OrcamentoClientScreen(token: publicToken),
            settings: settings,
          );
        }

        return MaterialPageRoute(
          builder: (_) => const AuthWrapper(),
          settings: settings,
        );
      },
    );
  }
}



class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final StreamSubscription<AuthState> _authSubscription;
  bool _initialCheckDone = false;
  Session? _session;

  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;
    _initialCheckDone = true;
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      setState(() {
        _session = data.session;
      });
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialCheckDone) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF0A369D),
          ),
        ),
      );
    }

    if (_session != null || AppAuthState.bypassAuth) {
      if (AppAuthState.selectedRole == 'Gerente') {
        return GerenteDashboard(onLogout: () {
          setState(() {
            AppAuthState.bypassAuth = false;
          });
        });
      } else {
        return TecnicoDashboard(onLogout: () {
          setState(() {
            AppAuthState.bypassAuth = false;
          });
        });
      }
    } else {
      return LoginScreen(onBypass: () => setState(() {}));
    }
  }
}

class AtsReportScreen extends StatefulWidget {
  const AtsReportScreen({super.key});

  @override
  State<AtsReportScreen> createState() => _AtsReportScreenState();
}

class TimeTrackingRow {
  DateTime? date;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  TimeTrackingRow({this.date, this.startTime, this.endTime});
}

class _AtsReportScreenState extends State<AtsReportScreen> {
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

  // Action methods
  void _submitReport() {
    // Validate Accept Terms
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, aceite os termos de autorização antes de enviar.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Validate Signature
    if (_signaturePoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, adicione a assinatura do cliente.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Validate Printed Name
    if (_printedNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, digite o nome legível do cliente.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Display Loading then Success Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.pop(context); // Close progress bar
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text('Sucesso'),
              ],
            ),
            content: const Text('O Relatório ATS foi enviado com sucesso!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _clearForm();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    });
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                  '014742',
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
                    onPressed: _clearForm,
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
                  child: ElevatedButton(
                    onPressed: _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A369D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Enviar Relatório',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: const Text(
                      'Dia',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: const Text(
                      'Início',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: const Text(
                      'Fim',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    ),
                  ),
                  const SizedBox.shrink(),
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
          Container(
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
