import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chamado.dart';
import '../../models/dia_trabalho.dart';
import '../../models/log_horas_custos.dart';
import '../../services/ats_pdf_service.dart';
import '../../services/chamados_service.dart';

const Color _emerald = Color(0xFF10B981);

class GerenteDashboard extends StatefulWidget {
  final VoidCallback? onLogout;
  const GerenteDashboard({super.key, this.onLogout});

  @override
  State<GerenteDashboard> createState() => _GerenteDashboardState();
}

class _GerenteDashboardState extends State<GerenteDashboard> {
  int _selectedMenuIndex = 1; // Tabela de chamados selecionada por padrão para visão de gestão
  String _filtroStatus = 'todos';
  String _buscaTexto = '';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(
        children: [
          // ==================================================================
          // 1. MENU LATERAL (SIDEBAR - LAYOUT HORIZONTAL WEB)
          // ==================================================================
          Container(
            width: 250,
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A), // Dark Navy Slate
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(2, 0)),
              ],
            ),
            child: Column(
              children: [
                // Topo da Sidebar: Logo Pmach e Nome
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Image.asset(
                          'assets/images/logo_pmach.png',
                          height: 32,
                          width: 32,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ATS Serviços',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Portal de Gestão',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Perfil do Gestor
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF0A369D),
                        child: const Icon(Icons.person, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Supabase.instance.client.auth.currentUser?.email?.split('@').first ?? 'Gestor ATS',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Gerente Operacional',
                              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Itens de Navegação do Menu Lateral
                _buildSidebarItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Visão Geral',
                  index: 0,
                ),
                _buildSidebarItem(
                  icon: Icons.table_chart_outlined,
                  label: 'Tabela de Chamados',
                  index: 1,
                ),
                _buildSidebarItem(
                  icon: Icons.people_outline,
                  label: 'Equipe Técnica',
                  index: 2,
                ),

                const Spacer(),

                // Rodapé do Menu Lateral com Sair
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                    title: const Text('Encerrar Sessão', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold)),
                    onTap: () => _showLogoutDialog(context),
                  ),
                ),
              ],
            ),
          ),

          // ==================================================================
          // 2. ÁREA PRINCIPAL (MAIN CONTENT AREA - WEB HORIZONTAL)
          // ==================================================================
          Expanded(
            child: Column(
              children: [
                // Topo da Área Principal: Barra Superior com Ação Rápida
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _obterTituloPagina(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Supervisão industrial e atribuição de serviços em tempo real',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Botão Principal de Ação: Criar e Atribuir Serviço
                          ElevatedButton.icon(
                            onPressed: () => _abrirModalCriarEAtribuir(context),
                            icon: const Icon(Icons.add_task, size: 18),
                            label: const Text('+ Criar e Atribuir Serviço'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A369D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Conteúdo da Aba Selecionada
                Expanded(
                  child: _buildConteudoAba(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({required IconData icon, required String label, required int index}) {
    final isSelected = _selectedMenuIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedMenuIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A369D) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF94A3B8), size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _obterTituloPagina() {
    switch (_selectedMenuIndex) {
      case 0:
        return 'Visão Geral e Indicadores';
      case 1:
        return 'Tabela Reativa de Chamados';
      case 2:
        return 'Equipe de Técnicos em Campo';
      default:
        return 'Painel do Gestor';
    }
  }

  Widget _buildConteudoAba() {
    switch (_selectedMenuIndex) {
      case 0:
        return _buildVisaoGeralPage();
      case 1:
        return _buildTabelaChamadosReativa();
      case 2:
        return _buildEquipeTecnicaPage();
      default:
        return _buildTabelaChamadosReativa();
    }
  }

  // ============================================================================
  // TABELA REATIVA DE CHAMADOS (FULL DATA TABLE COM AÇÕES)
  // ============================================================================
  Widget _buildTabelaChamadosReativa() {
    return ValueListenableBuilder<List<Chamado>>(
      valueListenable: ChamadosService.instance.chamadosNotifier,
      builder: (context, todosChamados, _) {
        // Aplica filtros de status e busca textual
        final chamados = todosChamados.where((c) {
          final matchesBusca = _buscaTexto.isEmpty ||
              c.numeroAts.toLowerCase().contains(_buscaTexto.toLowerCase()) ||
              c.razaoSocial.toLowerCase().contains(_buscaTexto.toLowerCase()) ||
              (c.modeloMaquina ?? '').toLowerCase().contains(_buscaTexto.toLowerCase()) ||
              (c.tecnicoNome ?? '').toLowerCase().contains(_buscaTexto.toLowerCase());

          if (!matchesBusca) return false;

          switch (_filtroStatus) {
            case 'aprovado_pendente':
              return c.status == ChamadoStatus.aprovadoPendente;
            case 'atribuido':
              return c.status == ChamadoStatus.atribuido;
            case 'em_atendimento':
              return c.status == ChamadoStatus.emAtendimento;
            case 'finalizado':
              return c.status == ChamadoStatus.finalizado;
            case 'todos':
            default:
              return true;
          }
        }).toList();

        return Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de Filtros e Busca
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Campo de Busca Rápida
                    Expanded(
                      flex: 2,
                      child: TextField(
                        onChanged: (val) => setState(() => _buscaTexto = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'Buscar por ATS, cliente, máquina ou técnico...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Filtros por Status (Chips)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Todos (${todosChamados.length})', 'todos'),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Aprovados (${todosChamados.where((c) => c.status == ChamadoStatus.aprovadoPendente).length})',
                            'aprovado_pendente',
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Atribuídos (${todosChamados.where((c) => c.status == ChamadoStatus.atribuido).length})',
                            'atribuido',
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Finalizados (${todosChamados.where((c) => c.status == ChamadoStatus.finalizado).length})',
                            'finalizado',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Tabela com Scroll Horizontal e Vertical
              Expanded(
                child: chamados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_late_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'Nenhum chamado corresponde aos filtros aplicados.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                            horizontalMargin: 20,
                            columnSpacing: 24,
                            columns: const [
                              DataColumn(label: Text('ATS Nº', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Cliente / Razão Social', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Máquina / Equipamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Técnico Responsável', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Abertura', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                            rows: chamados.map((c) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      'ATS-${c.numeroAts}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A369D), fontSize: 13),
                                    ),
                                  ),
                                  DataCell(
                                    Text(c.razaoSocial, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ),
                                  DataCell(
                                    Text(c.modeloMaquina ?? 'Em levantamento', style: const TextStyle(fontSize: 12)),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          c.tecnicoNome != null ? Icons.person : Icons.person_outline,
                                          size: 16,
                                          color: c.tecnicoNome != null ? const Color(0xFF0A369D) : Colors.grey,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          c.tecnicoNome ?? 'Não atribuído',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: c.tecnicoNome != null ? FontWeight.bold : FontWeight.normal,
                                            color: c.tecnicoNome != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(_buildStatusBadge(c.status)),
                                  DataCell(
                                    Text(_dateFormat.format(c.createdAt), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Botão para atribuir / alterar técnico
                                        OutlinedButton.icon(
                                          onPressed: () => _abrirModalAtribuirTecnico(context, c),
                                          icon: const Icon(Icons.engineering, size: 14),
                                          label: Text(c.tecnicoNome == null ? 'Atribuir' : 'Alterar'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (c.status == ChamadoStatus.finalizado) ...[
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: _enviandoEmailChamadoId == c.id
                                                ? null
                                                : () => _gerarPdfEEnviarCliente(c),
                                            icon: _enviandoEmailChamadoId == c.id
                                                ? const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                  )
                                                : const Icon(Icons.send_rounded, size: 14),
                                            label: Text(_enviandoEmailChamadoId == c.id
                                                ? 'Enviando...'
                                                : 'Gerar PDF e Enviar para o Cliente'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0A369D),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String valor, {bool isAlert = false}) {
    final isSelected = _filtroStatus == valor;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _filtroStatus = valor);
      },
      selectedColor: const Color(0xFF0A369D),
      backgroundColor: isAlert ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : (isAlert ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);
    String label = ChamadoStatus.getLabel(status);

    switch (status) {
      case ChamadoStatus.finalizado:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case ChamadoStatus.emAtendimento:
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        break;
      case ChamadoStatus.atribuido:
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF4338CA);
        break;
      case ChamadoStatus.aprovadoPendente:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      case ChamadoStatus.orcamentoEnviado:
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        break;
      case ChamadoStatus.novo:
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ============================================================================
  // PÁGINA 1: VISÃO GERAL (CARDS DE MÉTRICAS)
  // ============================================================================
  Widget _buildVisaoGeralPage() {
    return ValueListenableBuilder<List<Chamado>>(
      valueListenable: ChamadosService.instance.chamadosNotifier,
      builder: (context, chamados, _) {
        final total = chamados.length;
        final pendentes = chamados.where((c) => c.status == ChamadoStatus.aprovadoPendente).length;
        final atribuidos = chamados.where((c) => c.status == ChamadoStatus.atribuido).length;
        final finalizados = chamados.where((c) => c.status == ChamadoStatus.finalizado).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cards de Métricas em Linha Horizontal
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Total de Chamados', '$total', Icons.assignment, const Color(0xFF0A369D))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMetricCard('Aprovados (Aguardando)', '$pendentes', Icons.warning_amber, const Color(0xFFD97706))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMetricCard('Em Execução / Atribuídos', '$atribuidos', Icons.engineering, const Color(0xFF2563EB))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMetricCard('Finalizados', '$finalizados', Icons.check_circle, const Color(0xFF10B981))),
                ],
              ),
              const SizedBox(height: 24),

              // Chamados Recentes em Tabela Rápida
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Últimos Chamados Registrados',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _selectedMenuIndex = 1),
                          child: const Text('Ver todos na tabela →'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...chamados.take(5).map((c) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFEFF6FF),
                            child: Text(c.numeroAts.substring(c.numeroAts.length - 2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0A369D))),
                          ),
                          title: Text(c.razaoSocial, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('Máquina: ${c.modeloMaquina ?? "N/A"} • Técnico: ${c.tecnicoNome ?? "Pendente"}', style: const TextStyle(fontSize: 12)),
                          trailing: _buildStatusBadge(c.status),
                        )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String valor, IconData icon, Color cor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: cor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // PÁGINA 2: EQUIPE TÉCNICA
  // ============================================================================
  Widget _buildEquipeTecnicaPage() {
    return ValueListenableBuilder<List<Chamado>>(
      valueListenable: ChamadosService.instance.chamadosNotifier,
      builder: (context, chamados, _) {
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: _tecnicosDisponiveis.length,
          itemBuilder: (context, index) {
            final nome = _tecnicosDisponiveis[index];
            final chamadosDoTecnico = chamados.where((c) => c.tecnicoNome == nome).toList();
            final emAndamento = chamadosDoTecnico.where((c) => c.status != ChamadoStatus.finalizado).length;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 1,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF0A369D),
                  child: Text(nome[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(
                  emAndamento > 0
                      ? 'Em atendimento ($emAndamento ordem(ns) atribuída(s))'
                      : 'Disponível para novos atendimentos',
                  style: TextStyle(
                    color: emAndamento > 0 ? const Color(0xFF1D4ED8) : _emerald,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Chip(
                  label: Text('$emAndamento O.S. ativas', style: const TextStyle(fontSize: 11)),
                  backgroundColor: const Color(0xFFF1F5F9),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // MODAL: CRIAR E ATRIBUIR NOVO SERVIÇO AO TÉCNICO
  // ============================================================================
  void _abrirModalCriarEAtribuir(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final clienteCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final telefoneCtrl = TextEditingController();
    final maquinaCtrl = TextEditingController();
    final defeitoCtrl = TextEditingController();
    String tecnicoSelecionado = _tecnicosDisponiveis.first;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Row(
                children: [
                  Icon(Icons.add_task, color: Color(0xFF0A369D)),
                  SizedBox(width: 8),
                  Text('Criar e Atribuir Novo Serviço', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: clienteCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'Cliente / Solicitante *',
                            hintText: 'Ex: Metalúrgica Haas / Roberto',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o cliente' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'E-mail do Cliente',
                            hintText: 'cliente@empresa.com.br',
                            prefixIcon: const Icon(Icons.email_outlined, size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: telefoneCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Telefone / WhatsApp',
                                  hintText: '(47) 99999-0000',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: maquinaCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Máquina / Modelo',
                                  hintText: 'Ex: Haas CNC ST-20',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: defeitoCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Defeito Breve / Ocorrência',
                            hintText: 'Descreva a anomalia informada',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Seleção de Técnico Responsável
                        DropdownButtonFormField<String>(
                          value: tecnicoSelecionado,
                          decoration: InputDecoration(
                            labelText: 'Técnico Responsável *',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: _tecnicosDisponiveis.map((t) {
                            return DropdownMenuItem(value: t, child: Text(t));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => tecnicoSelecionado = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(dialogCtx);

                      // 1. Cria o chamado
                      final novo = await ChamadosService.instance.criarNovoChamado(
                        contato: clienteCtrl.text.trim(),
                        emailCliente: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                        telefone: telefoneCtrl.text.trim(),
                        modeloMaquina: maquinaCtrl.text.trim(),
                        defeitoRelatado: defeitoCtrl.text.trim(),
                      );

                      // 2. Atribui o técnico instantaneamente
                      await ChamadosService.instance.atribuirTecnico(
                        chamadoId: novo.id,
                        tecnicoNome: tecnicoSelecionado,
                      );

                      if (context.mounted) {
                        final msg = novo.pendingSync
                            ? 'O.S. Nº ${novo.numeroAts} salva localmente (offline/pendente de sincronização com o banco).'
                            : 'O.S. Nº ${novo.numeroAts} criada e atribuída a $tecnicoSelecionado!';
                        final cor = novo.pendingSync ? Colors.orange.shade800 : const Color(0xFF10B981);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: cor,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A369D),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Salvar e Atribuir'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // MODAL: ATRIBUIR TÉCNICO A UM CHAMADO EXISTENTE
  // ============================================================================
  void _abrirModalAtribuirTecnico(BuildContext context, Chamado chamado) {
    String tecnicoSelecionado = chamado.tecnicoNome ?? _tecnicosDisponiveis.first;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Atribuir Técnico - ATS Nº ${chamado.numeroAts}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cliente: ${chamado.razaoSocial}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Máquina: ${chamado.modeloMaquina ?? "N/A"}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: tecnicoSelecionado,
                    decoration: InputDecoration(
                      labelText: 'Selecione o Técnico',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: _tecnicosDisponiveis.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => tecnicoSelecionado = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    await ChamadosService.instance.atribuirTecnico(
                      chamadoId: chamado.id,
                      tecnicoNome: tecnicoSelecionado,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Técnico $tecnicoSelecionado atribuído à ATS Nº ${chamado.numeroAts}!'),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A369D), foregroundColor: Colors.white),
                  child: const Text('Confirmar Atribuição'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair do Sistema'),
        content: const Text('Deseja realmente encerrar a sessão de gestão?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (widget.onLogout != null) widget.onLogout!();
              await Supabase.instance.client.auth.signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Sair'),
          ),
        ],
      ),
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
}
