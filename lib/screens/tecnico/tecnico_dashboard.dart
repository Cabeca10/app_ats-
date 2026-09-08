import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import 'ats_form_screen.dart';
import '../../models/chamado.dart';
import '../../services/chamados_service.dart';
import '../../services/orcamento_pdf_service.dart';

const Color _emerald = Color(0xFF10B981);
const Color _emeraldDark = Color(0xFF065F46);

class Ticket {
  final String id;
  final String? chamadoId;
  final String? numeroAts;
  final String companyName;
  final String machineModel;
  final String scheduledTime;
  final String priority; // 'Alta', 'Média', 'Baixa'
  final String status; // 'Pendente', 'Em Andamento', 'Concluído'
  final String address;
  final String? defeitoRelatado;
  final String? orcamentoPdfUrl;

  Ticket({
    required this.id,
    this.chamadoId,
    this.numeroAts,
    required this.companyName,
    required this.machineModel,
    required this.scheduledTime,
    required this.priority,
    required this.status,
    required this.address,
    this.defeitoRelatado,
    this.orcamentoPdfUrl,
  });
}

class TecnicoDashboard extends StatefulWidget {
  final VoidCallback? onLogout;
  const TecnicoDashboard({super.key, this.onLogout});

  @override
  State<TecnicoDashboard> createState() => _TecnicoDashboardState();
}

class _TecnicoDashboardState extends State<TecnicoDashboard> {
  int _currentIndex = 0;
  bool _isOnline = true;

  // Mock list of daily tickets
  final List<Ticket> _tickets = [
    Ticket(
      id: "ATS-2026-081",
      companyName: "Metalúrgica Alfa S.A.",
      machineModel: "Torno CNC Haas ST-20",
      scheduledTime: "09:00 - 11:30",
      priority: "Alta",
      status: "Pendente",
      address: "Av. Industrial, 1024 - Joinville",
    ),
  ];

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
          ],
        ),
        actions: [
          // Connection Status Toggle / Display
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _isOnline = !_isOnline;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isOnline ? 'Conexão Restaurada: Modo Online' : 'Conexão Perdida: Modo Offline'),
                    backgroundColor: _isOnline ? _emerald : Colors.redAccent,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isOnline ? _emerald : Colors.redAccent,
                  boxShadow: [
                    if (_isOnline)
                      BoxShadow(
                        color: _emerald.withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                  ],
                ),
              ),
              label: Text(
                _isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  color: _isOnline ? _emeraldDark : Colors.redAccent.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: _isOnline ? _emerald.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            onPressed: () => _showLogoutDialog(context),
            tooltip: 'Sair da Conta',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
      ),
      body: _buildBody(),
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
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Chamados',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Manuais',
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

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildChamadosPage();
      case 1:
        return _buildManuaisPage();
      case 2:
        return _buildPerfilPage();
      default:
        return _buildChamadosPage();
    }
  }

  // PAGE 1: CHAMADOS (TICKETS LIST)
  Widget _buildChamadosPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome technician message card
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A369D), Color(0xFF1E5BB8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A369D).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Olá, Técnico!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Você possui ${_tickets.length} chamados agendados para hoje.',
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: const Icon(
                  Icons.construction,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Text(
            'Chamados de Hoje',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0C1A30),
            ),
          ),
        ),

        // List of tickets integrado com ChamadosService
        Expanded(
          child: ValueListenableBuilder<List<Chamado>>(
            valueListenable: ChamadosService.instance.chamadosNotifier,
            builder: (context, chamados, _) {
              // Converte os chamados atribuídos pelo gerente em tickets para o técnico
              final chamadosAtribuidos = chamados
                  .where((c) =>
                      c.status == ChamadoStatus.atribuido ||
                      c.status == ChamadoStatus.emAtendimento ||
                      c.status == ChamadoStatus.finalizado)
                  .map((c) => Ticket(
                        id: 'ATS-${c.numeroAts}',
                        chamadoId: c.id,
                        numeroAts: c.numeroAts,
                        companyName: c.razaoSocial,
                        machineModel: '${c.fabricante ?? "Pmach"} ${c.modeloMaquina ?? ""}',
                        scheduledTime: 'Prioritário',
                        priority: 'Alta',
                        status: c.status == ChamadoStatus.finalizado
                            ? 'Concluído'
                            : (c.status == ChamadoStatus.emAtendimento ? 'Em Andamento' : 'Pendente'),
                        address: c.endereco ?? 'Joinville / Região',
                        defeitoRelatado: c.defeitoRelatado,
                        orcamentoPdfUrl: c.orcamentoPdfUrl,
                      ))
                  .toList();

              final allTickets = [..._tickets, ...chamadosAtribuidos];

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: allTickets.length,
                itemBuilder: (context, index) {
                  final ticket = allTickets[index];
                  return _buildTicketCard(ticket);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _abrirAtsForm(Ticket ticket) async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AtsFormScreen(ticket: ticket),
      ),
    );
    if (res == true && mounted) {
      setState(() {
        final idx = _tickets.indexWhere((t) => t.id == ticket.id);
        if (idx != -1) {
          final old = _tickets[idx];
          _tickets[idx] = Ticket(
            id: old.id,
            chamadoId: old.chamadoId,
            numeroAts: old.numeroAts,
            companyName: old.companyName,
            machineModel: old.machineModel,
            scheduledTime: old.scheduledTime,
            priority: old.priority,
            status: 'Concluído',
            address: old.address,
            defeitoRelatado: old.defeitoRelatado,
            orcamentoPdfUrl: old.orcamentoPdfUrl,
          );
        }
      });
    }
  }

  Widget _buildTicketCard(Ticket ticket) {
    Color priorityColor;
    switch (ticket.priority) {
      case 'Alta':
        priorityColor = Colors.redAccent;
        break;
      case 'Média':
        priorityColor = Colors.orangeAccent;
        break;
      case 'Baixa':
        priorityColor = Colors.blueAccent;
        break;
      default:
        priorityColor = Colors.grey;
    }

    Color statusColor;
    switch (ticket.status) {
      case 'Pendente':
        statusColor = Colors.grey.shade600;
        break;
      case 'Em Andamento':
        statusColor = const Color(0xFF0A369D);
        break;
      case 'Concluído':
        statusColor = _emerald;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _abrirAtsForm(ticket),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left priority color bar strip
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: priorityColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Content body of the card
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row: ID and Priority
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                ticket.id,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: priorityColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ticket.priority,
                                  style: TextStyle(
                                    color: priorityColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Client details
                          Text(
                            ticket.companyName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0C1A30),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ticket.machineModel,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (ticket.defeitoRelatado != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                'Defeito: ${ticket.defeitoRelatado}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                              ),
                            ),
                          ],
                          const Divider(height: 20, thickness: 0.5),

                          // Technical meta details: Hour and Location
                          Row(
                            children: [
                              Icon(Icons.access_time_filled, size: 14, color: Colors.grey.shade400),
                              const SizedBox(width: 6),
                              Text(
                                ticket.scheduledTime,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade400),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        ticket.address,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Footer actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      ticket.status,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Action Button
                              Row(
                                children: [
                                  if (ticket.defeitoRelatado != null || ticket.orcamentoPdfUrl != null) ...[
                                    OutlinedButton.icon(
                                      onPressed: () => _abrirPdfOrcamento(ticket),
                                      icon: const Icon(Icons.picture_as_pdf, size: 14),
                                      label: const Text('Orçamento'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF0A369D),
                                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (ticket.status != "Concluído")
                                    ElevatedButton.icon(
                                      onPressed: () => _abrirAtsForm(ticket),
                                      icon: const Icon(Icons.note_add_outlined, size: 16),
                                      label: Text(ticket.status == "Pendente" ? "Iniciar Relatório" : "Continuar ATS"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0A369D),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    )
                                  else
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Relatório ATS já finalizado e enviado.'),
                                            backgroundColor: _emerald,
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text("Finalizado"),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _emerald,
                                        side: const BorderSide(color: _emerald),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // PAGE 2: MANUAIS (SERVICE MANUALS)
  Widget _buildManuaisPage() {
    final List<Map<String, String>> manuals = [
      {"title": "Manual Haas CNC ST-20", "desc": "Instruções de operação e manutenção de painel", "size": "4.2 MB"},
      {"title": "Guia Calibração CLP Siemens S7", "desc": "Parâmetros e endereçamento analógico I/O", "size": "1.8 MB"},
      {"title": "Catálogo Peças Injetora Husky", "desc": "Códigos de injetores e válvulas proporcionais", "size": "8.5 MB"},
      {"title": "Manual Operacional Inversor WEG", "desc": "Instalação e parametrização avançada CFW", "size": "2.4 MB"},
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manuais de Serviço',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0C1A30)),
          ),
          const SizedBox(height: 4),
          Text(
            'Acesse documentações técnicas mesmo offline.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Search Field
          TextField(
            decoration: InputDecoration(
              hintText: "Buscar manuais ou esquemas...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade100),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Manual List
          Expanded(
            child: ListView.builder(
              itemCount: manuals.length,
              itemBuilder: (context, index) {
                final manual = manuals[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                    ),
                    title: Text(
                      manual["title"]!,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0C1A30)),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(manual["desc"]!, style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(manual["size"]!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.download_for_offline, color: Color(0xFF0A369D)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${manual["title"]} salvo para acesso offline.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // PAGE 3: PERFIL (PROFILE & SETTINGS)
  Widget _buildPerfilPage() {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? "tecnico@atsservicos.com.br";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Profile Pic Avatar Glow
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFF0A369D), width: 2),
            ),
            child: const CircleAvatar(
              radius: 48,
              backgroundColor: Color(0xFFEFF6FF),
              child: Icon(Icons.engineering, size: 52, color: Color(0xFF0A369D)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Técnico Operacional',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0C1A30)),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Simple Stat Grid Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('Chamados do Mês', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    SizedBox(height: 4),
                    Text('24', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0A369D))),
                  ],
                ),
                VerticalDivider(width: 20, thickness: 1),
                Column(
                  children: [
                    Text('Taxa Conclusão', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    SizedBox(height: 4),
                    Text('96.2%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _emerald)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions List
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildProfileItem(Icons.settings, 'Configurações de Sincronização'),
                const Divider(height: 1, thickness: 0.5),
                _buildProfileItem(Icons.wifi_off, 'Banco de Dados Local (Cache)'),
                const Divider(height: 1, thickness: 0.5),
                _buildProfileItem(Icons.help_outline, 'Suporte Técnico e Ajuda'),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Sign out button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showLogoutDialog(context),
              icon: const Icon(Icons.logout),
              label: const Text('Sair da Conta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.shade100.withOpacity(0.1),
                foregroundColor: Colors.redAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.redAccent, width: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
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
              AppAuthState.bypassAuth = false;
              if (widget.onLogout != null) {
                widget.onLogout!();
              }
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
  }

  Widget _buildProfileItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade600),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: () {},
    );
  }

  Future<void> _abrirPdfOrcamento(Ticket ticket) async {
    final mockChamado = Chamado(
      id: ticket.id,
      numeroAts: ticket.id.replaceAll('ATS-', ''),
      razaoSocial: ticket.companyName,
      modeloMaquina: ticket.machineModel,
      defeitoRelatado: ticket.defeitoRelatado ?? 'Revisão geral',
      endereco: ticket.address,
      tokenUrl: 'mock-token',
      status: ChamadoStatus.atribuido,
      termosAceitos: true,
      responsavelAceiteNome: 'Cliente Aprovador',
      responsavelAceiteCargo: 'Gerente Operacional',
      aceiteData: DateTime.now(),
    );

    final dummySignature = List<int>.generate(80, (i) => 255);
    final pdfBytes = await OrcamentoPdfService.generatePdf(
      chamado: mockChamado,
      signatureBytes: Uint8List.fromList(dummySignature),
      responsavelNome: mockChamado.responsavelAceiteNome!,
      responsavelCargo: mockChamado.responsavelAceiteCargo!,
    );

    await Printing.layoutPdf(
      onLayout: (_) => pdfBytes,
      name: 'Orcamento_${ticket.id}.pdf',
    );
  }
}



