// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';

const Color _emerald = Color(0xFF10B981);

class GerenteDashboard extends StatefulWidget {
  final VoidCallback? onLogout;
  const GerenteDashboard({super.key, this.onLogout});

  @override
  State<GerenteDashboard> createState() => _GerenteDashboardState();
}

class _GerenteDashboardState extends State<GerenteDashboard> {
  int _currentIndex = 0;

  // Mock list of technicians and their statuses
  final List<Map<String, String>> _technicians = [
    {"name": "Carlos Silva", "status": "Em Campo", "job": "Haas CNC ST-20 - Metalúrgica Alfa"},
    {"name": "Marcos Oliveira", "status": "Disponível", "job": "-"},
    {"name": "André Souza", "status": "Em Campo", "job": "Injetora Husky - Plásticos União"},
    {"name": "Lucas Pereira", "status": "Em Almoço", "job": "-"},
  ];

  // Mock list of reports awaiting approval
  final List<Map<String, String>> _pendingApprovals = [
    {"id": "ATS-2026-079", "client": "Indústria Têxtil Linho", "tech": "Carlos Silva", "date": "25/08/2026", "hours": "4h 30m"},
    {"id": "ATS-2026-080", "client": "Metalúrgica Haas Joinville", "tech": "André Souza", "date": "25/08/2026", "hours": "2h 15m"},
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
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.admin_panel_settings, size: 14, color: Color(0xFF0A369D)),
                SizedBox(width: 4),
                Text(
                  'Gerente',
                  style: TextStyle(
                    color: Color(0xFF0A369D),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
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
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Painel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Equipe',
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
        return _buildPainelPage();
      case 1:
        return _buildEquipePage();
      case 2:
        return _buildPerfilPage();
      default:
        return _buildPainelPage();
    }
  }

  // PAGE 1: PAINEL (OVERVIEW & APPROVALS)
  Widget _buildPainelPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Card with Gradient
        Container(
          width: double.infinity,
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
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Olá, Gerente!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Acompanhe a atividade técnica e aprove relatórios pendentes.',
                style: TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        // Quick Stats row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(child: _buildStatCard('Em Campo', '2', Icons.directions_run, Colors.orangeAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Pendente Aprovação', '${_pendingApprovals.length}', Icons.fact_check, Colors.blueAccent)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Big "Abrir Chamado" Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ElevatedButton.icon(
            onPressed: () => _showNewTicketBottomSheet(context),
            icon: const Icon(Icons.add_circle_outline, size: 22),
            label: const Text(
              'Abrir Novo Chamado',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A369D),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56), // Large button
              elevation: 2,
              shadowColor: const Color(0xFF0A369D).withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Text(
            'Aprovações Pendentes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0C1A30),
            ),
          ),
        ),

        // List of approvals
        Expanded(
          child: _pendingApprovals.isEmpty
              ? const Center(child: Text('Nenhum relatório aguardando aprovação.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _pendingApprovals.length,
                  itemBuilder: (context, index) {
                    final report = _pendingApprovals[index];
                    return _buildApprovalCard(report, index);
                  },
                ),
        ),
      ],
    );
  }

  void _showNewTicketBottomSheet(BuildContext context) {
    final companyController = TextEditingController();
    final machineController = TextEditingController();
    final addressController = TextEditingController();
    final timeController = TextEditingController();
    
    String selectedPriority = 'Alta';
    String selectedTech = _technicians.first['name']!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Abrir Novo Chamado',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0C1A30),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    
                    // Empresa/Cliente
                    const Text('Empresa / Cliente', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0C1A30))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: companyController,
                      decoration: InputDecoration(
                        hintText: 'Digite o nome da empresa',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Modelo da Máquina
                    const Text('Modelo da Máquina', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0C1A30))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: machineController,
                      decoration: InputDecoration(
                        hintText: 'Ex: Sopradora Husky H300',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Endereço
                    const Text('Endereço', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0C1A30))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: addressController,
                      decoration: InputDecoration(
                        hintText: 'Endereço completo da assistência',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Row with Técnico and Horário
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Técnico Responsável', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0C1A30))),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedTech,
                                    isExpanded: true,
                                    items: _technicians.map((tech) {
                                      return DropdownMenuItem<String>(
                                        value: tech['name'],
                                        child: Text(tech['name']!, style: const TextStyle(fontSize: 14)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(() {
                                          selectedTech = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Horário Agendado', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0C1A30))),
                              const SizedBox(height: 6),
                              TextField(
                                controller: timeController,
                                decoration: InputDecoration(
                                  hintText: 'Ex: 09:00 - 11:30',
                                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Prioridade
                    const Text('Prioridade', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0C1A30))),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Alta', 'Média', 'Baixa'].map((priority) {
                        final isSelected = selectedPriority == priority;
                        Color chipColor;
                        Color textColor;
                        if (priority == 'Alta') {
                          chipColor = isSelected ? Colors.redAccent : Colors.redAccent.withOpacity(0.1);
                          textColor = isSelected ? Colors.white : Colors.redAccent.shade700;
                        } else if (priority == 'Média') {
                          chipColor = isSelected ? Colors.orangeAccent : Colors.orangeAccent.withOpacity(0.1);
                          textColor = isSelected ? Colors.white : Colors.orangeAccent.shade700;
                        } else {
                          chipColor = isSelected ? Colors.blueAccent : Colors.blueAccent.withOpacity(0.1);
                          textColor = isSelected ? Colors.white : Colors.blueAccent.shade700;
                        }

                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedPriority = priority;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: chipColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : chipColor.withOpacity(0.4),
                              ),
                            ),
                            child: Text(
                              priority,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // Button to submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (companyController.text.trim().isEmpty ||
                              machineController.text.trim().isEmpty ||
                              addressController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Por favor, preencha todos os campos obrigatórios.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(context);

                          // Show success dialog
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Chamado Aberto'),
                                ],
                              ),
                              content: Text(
                                'Chamado para "${companyController.text}" foi criado com sucesso e atribuído ao técnico $selectedTech!',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A369D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Criar Chamado',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0C1A30)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(Map<String, String> report, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                report["id"]!,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
              ),
              Text(
                report["date"]!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            report["client"]!,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0C1A30)),
          ),
          const SizedBox(height: 4),
          Text(
            'Técnico: ${report["tech"]!}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            'Duração total: ${report["hours"]!}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const Divider(height: 24, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Relatório visualizado em detalhes.'),
                      backgroundColor: Color(0xFF0A369D),
                    ),
                  );
                },
                child: const Text('Ver Detalhes', style: TextStyle(color: Color(0xFF0A369D))),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _pendingApprovals.removeAt(index);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Relatório ${report["id"]} aprovado com sucesso!'),
                      backgroundColor: _emerald,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Aprovar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // PAGE 2: EQUIPE (TECHNICIANS)
  Widget _buildEquipePage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status da Equipe',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0C1A30)),
          ),
          const SizedBox(height: 4),
          Text(
            'Acompanhe em tempo real a situação de cada técnico.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _technicians.length,
              itemBuilder: (context, index) {
                final tech = _technicians[index];
                Color statusColor;
                switch (tech["status"]!) {
                  case 'Em Campo':
                    statusColor = Colors.orangeAccent;
                    break;
                  case 'Disponível':
                    statusColor = _emerald;
                    break;
                  default:
                    statusColor = Colors.grey;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEFF6FF),
                      child: Icon(Icons.engineering, color: Color(0xFF0A369D)),
                    ),
                    title: Text(
                      tech["name"]!,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0C1A30)),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          tech["status"] == 'Em Campo' ? 'Serviço: ${tech["job"]!}' : 'Aguardando chamados',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tech["status"]!,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
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
    final email = user?.email ?? "gerente@atsservicos.com.br";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Profile Pic Avatar
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
              child: Icon(Icons.admin_panel_settings, size: 52, color: Color(0xFF0A369D)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Gerente Geral',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0C1A30)),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 32),

          // Actions List
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildProfileItem(Icons.analytics, 'Relatórios Analíticos'),
                const Divider(height: 1, thickness: 0.5),
                _buildProfileItem(Icons.rule, 'Políticas de Aprovação'),
                const Divider(height: 1, thickness: 0.5),
                _buildProfileItem(Icons.help_outline, 'Suporte Administrativo'),
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
}
