import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ats_documentacao.dart';
import '../../models/chamado.dart';
import '../../models/dia_trabalho.dart';
import '../../models/log_horas_custos.dart';
import '../../models/planilha_reembolso.dart';
import '../../models/relatorio_custos_gerente.dart';
import '../../models/tecnico.dart';
import '../../services/ats_documentacao_service.dart';
import '../../services/ats_pdf_service.dart';
import '../../services/chamados_service.dart';
import '../../services/orientation_service.dart';
import '../../services/orcamento_pdf_service.dart';
import '../../services/planilha_reembolso_service.dart';
import '../../services/tecnicos_service.dart';
import '../../utils/url_helper.dart';
import '../../widgets/documentacao_pasta_dialog.dart';
import '../../widgets/planilha_reembolso_widget.dart';
import '../../widgets/relatorio_gerente_dialog.dart';
import 'chamados_list_screen.dart';

const Color _emerald = Color(0xFF10B981);

class GerenteDashboard extends StatefulWidget {
  final VoidCallback? onLogout;
  const GerenteDashboard({super.key, this.onLogout});

  @override
  State<GerenteDashboard> createState() => _GerenteDashboardState();
}

class _GerenteDashboardState extends State<GerenteDashboard> {
  int _selectedMenuIndex = 1; // Tabela de chamados selecionada por padrão para visão de gestão
  bool _mostrarModoCards = false; // Alterna entre visão em Tabela e visão em Cards
  String _filtroStatus = 'todos';
  String _buscaTexto = '';
  String? _enviandoEmailChamadoId;
  String? _abrindoPdfChamadoId;
  String? _abrindoRelatorioChamadoId;
  String? _excluindoChamadoId;
  Map<String, AtsDocumentacao> _documentacoesPorChamado = {};
  bool _carregandoDocumentacoes = false;
  String _buscaRegistro = '';
  String _filtroStatusRegistro = 'todos';
  int _planilhaAnoGerente = DateTime.now().year;
  int _planilhaMesGerente = DateTime.now().month;
  Tecnico? _tecnicoSelecionadoPlanilha;
  Map<String, PlanilhaReembolso> _resumoPlanilhasMes = {};
  bool _carregandoPlanilhasMes = false;
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  List<String> get _tecnicosDisponiveis => TecnicosService.instance.nomesTecnicos;

  @override
  void initState() {
    super.initState();
    TecnicosService.instance.inicializarESincronizar();
    ChamadosService.instance.inicializarESincronizar();
    _carregarDocumentacoesGerente();
  }

  Future<void> _carregarPlanilhasMesGerente() async {
    if (mounted) {
      setState(() => _carregandoPlanilhasMes = true);
    }
    try {
      await TecnicosService.instance.recarregarTecnicos();
      final mapa = await PlanilhaReembolsoService.instance.listarPlanilhasDoMes(
        ano: _planilhaAnoGerente,
        mes: _planilhaMesGerente,
      );
      if (mounted) {
        setState(() {
          _resumoPlanilhasMes = mapa;
          _carregandoPlanilhasMes = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _carregandoPlanilhasMes = false);
      }
    }
  }

  void _alterarMesPlanilhaGerente(int delta) {
    var novoMes = _planilhaMesGerente + delta;
    var novoAno = _planilhaAnoGerente;
    if (novoMes < 1) {
      novoMes = 12;
      novoAno--;
    } else if (novoMes > 12) {
      novoMes = 1;
      novoAno++;
    }
    setState(() {
      _planilhaMesGerente = novoMes;
      _planilhaAnoGerente = novoAno;
    });
    _carregarPlanilhasMesGerente();
  }

  Future<void> _carregarDocumentacoesGerente() async {
    if (mounted) {
      setState(() => _carregandoDocumentacoes = true);
    }
    try {
      final docs = await AtsDocumentacaoService.instance.listarTodasDocumentacoes();
      if (mounted) {
        setState(() {
          _documentacoesPorChamado = docs;
          _carregandoDocumentacoes = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _carregandoDocumentacoes = false);
      }
    }
  }

  Widget _buildSidebarContent({bool inDrawer = false}) {
    return Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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

          // Itens de Navegação com rolagem segura em modo paisagem
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
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
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFF0A369D),
                          child: Icon(Icons.person, color: Colors.white, size: 20),
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
                  const SizedBox(height: 4),
                  _buildSidebarItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Visão Geral',
                    index: 0,
                    inDrawer: inDrawer,
                  ),
                  _buildSidebarItem(
                    icon: Icons.table_chart_outlined,
                    label: 'Tabela de Chamados',
                    index: 1,
                    inDrawer: inDrawer,
                  ),
                  _buildSidebarItem(
                    icon: Icons.folder_copy_outlined,
                    label: 'Registro de Chamados',
                    index: 3,
                    inDrawer: inDrawer,
                  ),
                  _buildSidebarItem(
                    icon: Icons.table_view_rounded,
                    label: 'Planilhas',
                    index: 4,
                    inDrawer: inDrawer,
                  ),
                  _buildSidebarItem(
                    icon: Icons.people_outline,
                    label: 'Equipe Técnica',
                    index: 2,
                    inDrawer: inDrawer,
                  ),
                ],
              ),
            ),
          ),

          // Rodapé do Menu Lateral com Sair
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
              title: const Text('Encerrar Sessão', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold)),
              onTap: () {
                if (inDrawer) Navigator.of(context).pop();
                _showLogoutDialog(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompactScreen = MediaQuery.of(context).size.width < 820;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: isCompactScreen
          ? Drawer(
              width: 260,
              backgroundColor: const Color(0xFF0F172A),
              child: SafeArea(child: _buildSidebarContent(inDrawer: true)),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // 1. MENU LATERAL FIXO EM TELAS AMPLAS
            if (!isCompactScreen) _buildSidebarContent(),

            // 2. ÁREA PRINCIPAL
            Expanded(
              child: Column(
                children: [
                  // Topo da Área Principal: Barra Superior Responsiva
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompactScreen ? 12 : 24,
                      vertical: isCompactScreen ? 10 : 16,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCompactScreen) ...[
                                  Builder(
                                    builder: (drawerCtx) => IconButton(
                                      icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A)),
                                      tooltip: 'Abrir menu',
                                      onPressed: () => Scaffold.of(drawerCtx).openDrawer(),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _obterTituloPagina(),
                                        style: TextStyle(
                                          fontSize: isCompactScreen ? 16 : 20,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Supervisão industrial e atribuição de serviços em tempo real',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (kIsWeb || MediaQuery.of(context).size.shortestSide < 700)
                                  IconButton(
                                    onPressed: () => OrientationService.instance.toggleOrientation(context),
                                    icon: const Icon(Icons.screen_rotation_rounded, color: Color(0xFF0A369D)),
                                    tooltip: 'Alternar Modo Paisagem / Retrato',
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFFEFF6FF),
                                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                                    ),
                                  ),
                                if (_selectedMenuIndex == 2)
                                  ElevatedButton.icon(
                                    onPressed: () => _abrirModalAdicionarTecnico(context),
                                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                                    label: const Text('+ Adicionar Técnico'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _emerald,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 2,
                                    ),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    ChamadosService.instance.recarregarChamados();
                                    TecnicosService.instance.recarregarTecnicos();
                                    _carregarDocumentacoesGerente();
                                    if (_selectedMenuIndex == 4) {
                                      _carregarPlanilhasMesGerente();
                                    }
                                  },
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Atualizar'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0A369D),
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _abrirModalCriarEAtribuir(context),
                                  icon: const Icon(Icons.request_quote_outlined, size: 18),
                                  label: const Text('+ Nova Proposta Comercial'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0A369D),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Banner de alerta caso haja erro de sincronização com o Supabase
                  ValueListenableBuilder<String?>(
                    valueListenable: ChamadosService.instance.syncErrorNotifier,
                    builder: (context, syncError, _) {
                      if (syncError == null || syncError.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        width: double.infinity,
                        color: const Color(0xFFFEF2F2),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                syncError,
                                style: const TextStyle(
                                  color: Color(0xFF991B1B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => ChamadosService.instance.syncErrorNotifier.value = null,
                              icon: const Icon(Icons.close, size: 18, color: Color(0xFF991B1B)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Fechar aviso',
                            ),
                          ],
                        ),
                      );
                    },
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
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required int index,
    bool inDrawer = false,
  }) {
    final isSelected = _selectedMenuIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMenuIndex = index;
          if (index == 4) {
            _tecnicoSelecionadoPlanilha = null;
          }
        });
        if (index == 2) {
          TecnicosService.instance.recarregarTecnicos();
        } else if (index == 3) {
          _carregarDocumentacoesGerente();
        } else if (index == 4) {
          _carregarPlanilhasMesGerente();
        }
        if (inDrawer) {
          Navigator.of(context).pop();
        }
      },
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
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
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
      case 3:
        return 'Registro de Chamados';
      case 4:
        return 'Planilhas de Reembolso dos Técnicos';
      default:
        return 'Painel do Gestor';
    }
  }

  Widget _buildConteudoAba() {
    switch (_selectedMenuIndex) {
      case 0:
        return _buildVisaoGeralPage();
      case 1:
        return _mostrarModoCards
            ? ChamadosListScreen(onAlternarParaTabela: () => setState(() => _mostrarModoCards = false))
            : _buildTabelaChamadosReativa();
      case 2:
        return _buildEquipeTecnicaPage();
      case 3:
        return _buildRegistroChamadosPage();
      case 4:
        return _buildPlanilhasGerentePage();
      default:
        return _mostrarModoCards
            ? ChamadosListScreen(onAlternarParaTabela: () => setState(() => _mostrarModoCards = false))
            : _buildTabelaChamadosReativa();
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
              (c.tecnicoNome ?? '').toLowerCase().contains(_buscaTexto.toLowerCase()) ||
              (c.tecnico2Nome ?? '').toLowerCase().contains(_buscaTexto.toLowerCase());

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
              // Barra de Filtros e Busca + Botão Alternar para Cards
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
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _mostrarModoCards = true),
                      icon: const Icon(Icons.grid_view_rounded, size: 16),
                      label: const Text('Visão em Cards'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0A369D),
                        side: const BorderSide(color: Color(0xFF93C5FD)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Técnico 1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Técnico 2', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Abertura', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Relatório Finalizado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Custo Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Pdf Aprovado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Excluir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                            rows: chamados.map((c) {
                              final temPdfAprovado =
                                  (c.orcamentoPdfUrl != null && c.orcamentoPdfUrl!.trim().isNotEmpty) ||
                                  c.termosAceitos ||
                                  c.status == ChamadoStatus.aprovadoPendente ||
                                  c.status == ChamadoStatus.atribuido ||
                                  c.status == ChamadoStatus.emAtendimento ||
                                  c.status == ChamadoStatus.finalizado;
                              final temRelatorioFinal = c.status == ChamadoStatus.finalizado ||
                                  (c.relatorioPdfUrl != null && c.relatorioPdfUrl!.trim().isNotEmpty);
                              final versaoRelatorio = c.relatorioVersao > 0 ? c.relatorioVersao : 1;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      c.numeroAts.toUpperCase().startsWith('ATS-') ? c.numeroAts : 'ATS-${c.numeroAts}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A369D), fontSize: 13),
                                    ),
                                  ),
                                  DataCell(
                                    Text(c.razaoSocial, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ),
                                  DataCell(
                                    Text(c.modeloMaquina ?? 'Em levantamento', style: const TextStyle(fontSize: 12)),
                                  ),
                                  DataCell(_buildStatusBadge(c.status)),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          (c.tecnicoNome != null && c.tecnicoNome!.trim().isNotEmpty) ? Icons.person : Icons.person_outline,
                                          size: 16,
                                          color: (c.tecnicoNome != null && c.tecnicoNome!.trim().isNotEmpty) ? const Color(0xFF0A369D) : Colors.grey,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          (c.tecnicoNome != null && c.tecnicoNome!.trim().isNotEmpty) ? c.tecnicoNome! : 'Não atribuído',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: (c.tecnicoNome != null && c.tecnicoNome!.trim().isNotEmpty) ? FontWeight.bold : FontWeight.normal,
                                            color: (c.tecnicoNome != null && c.tecnicoNome!.trim().isNotEmpty) ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          (c.tecnico2Nome != null && c.tecnico2Nome!.trim().isNotEmpty) ? Icons.person : Icons.person_outline,
                                          size: 16,
                                          color: (c.tecnico2Nome != null && c.tecnico2Nome!.trim().isNotEmpty) ? const Color(0xFF0A369D) : Colors.grey,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          (c.tecnico2Nome != null && c.tecnico2Nome!.trim().isNotEmpty) ? c.tecnico2Nome! : 'Não atribuído',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: (c.tecnico2Nome != null && c.tecnico2Nome!.trim().isNotEmpty) ? FontWeight.bold : FontWeight.normal,
                                            color: (c.tecnico2Nome != null && c.tecnico2Nome!.trim().isNotEmpty) ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(_dateFormat.format(c.createdAt), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Botão para atribuir técnico (visível apenas quando o status for aprovado_pendente)
                                        if (c.status == ChamadoStatus.aprovadoPendente) ...[
                                          ElevatedButton.icon(
                                            onPressed: () => _abrirModalAtribuirTecnico(context, c),
                                            icon: const Icon(Icons.person_add_alt_1, size: 14),
                                            label: const Text('Atribuir Técnico'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF10B981),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        // Botão para alterar técnico já atribuído
                                        if (c.status == ChamadoStatus.atribuido) ...[
                                          OutlinedButton.icon(
                                            onPressed: () => _abrirModalAtribuirTecnico(context, c),
                                            icon: const Icon(Icons.engineering, size: 14),
                                            label: const Text('Alterar Técnico'),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        // Botões de proposta comercial (Copiar Link de Aprovação e Enviar WhatsApp)
                                        if (c.status == ChamadoStatus.orcamentoPendenteEnvio ||
                                            c.status == ChamadoStatus.orcamentoEnviado ||
                                            c.status == ChamadoStatus.novo) ...[
                                          OutlinedButton.icon(
                                            onPressed: () => _copiarLinkAprovacao(context, c),
                                            icon: const Icon(Icons.link, size: 14),
                                            label: const Text('Copiar Link de Aprovação'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF0A369D),
                                              side: const BorderSide(color: Color(0xFF93C5FD)),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () => _compartilharWhatsApp(context, c),
                                            icon: const Icon(Icons.chat, size: 14),
                                            label: const Text('Enviar WhatsApp'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF25D366),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              elevation: 0,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
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
                                  DataCell(_buildBotaoRelatorioFinalizado(c, temRelatorioFinal, versaoRelatorio)),
                                  DataCell(_buildBotaoCalculoCustos(c, temRelatorioFinal)),
                                  DataCell(
                                    temPdfAprovado
                                        ? OutlinedButton.icon(
                                            onPressed: _abrindoPdfChamadoId == c.id
                                                ? null
                                                : () => _abrirPdfAprovado(c),
                                            icon: _abrindoPdfChamadoId == c.id
                                                ? const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Color(0xFFDC2626),
                                                    ),
                                                  )
                                                : const Icon(Icons.picture_as_pdf_rounded, size: 15),
                                            label: Text(
                                              _abrindoPdfChamadoId == c.id ? 'Abrindo...' : 'Ver PDF',
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFFDC2626),
                                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          )
                                        : const Text(
                                            'Aguardando',
                                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                          ),
                                  ),
                                  DataCell(
                                    _excluindoChamadoId == c.id
                                        ? const SizedBox(
                                            width: 36,
                                            child: Center(
                                              child: SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Color(0xFFDC2626),
                                                ),
                                              ),
                                            ),
                                          )
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 20,
                                              color: Color(0xFFDC2626),
                                            ),
                                            tooltip: 'Excluir chamado permanentemente',
                                            onPressed: _excluindoChamadoId != null
                                                ? null
                                                : () => _confirmarExclusaoChamado(context, c),
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

  Widget _buildFilterChip(
    String label,
    String valor, {
    bool isAlert = false,
    String? selectedStatus,
    ValueChanged<String>? onStatusSelected,
  }) {
    final isSelected = (selectedStatus ?? _filtroStatus) == valor;
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
        if (!val) return;
        if (onStatusSelected != null) {
          onStatusSelected(valor);
        } else {
          setState(() => _filtroStatus = valor);
        }
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

  // ============================================================================
  // PÁGINA 3: REGISTRO DE CHAMADOS (PASTA DE FOTOS, DESCRITIVO E RELATÓRIO FINAL)
  // ============================================================================
  Widget _buildRegistroChamadosPage() {
    return ValueListenableBuilder<List<Chamado>>(
      valueListenable: ChamadosService.instance.chamadosNotifier,
      builder: (context, todosChamados, _) {
        final chamados = todosChamados.where((c) {
          final query = _buscaRegistro.toLowerCase();
          final matchesBusca = query.isEmpty ||
              c.numeroAts.toLowerCase().contains(query) ||
              c.razaoSocial.toLowerCase().contains(query) ||
              (c.modeloMaquina ?? '').toLowerCase().contains(query) ||
              (c.tecnicoNome ?? '').toLowerCase().contains(query) ||
              (c.tecnico2Nome ?? '').toLowerCase().contains(query);

          if (!matchesBusca) return false;

          switch (_filtroStatusRegistro) {
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        onChanged: (val) => setState(() => _buscaRegistro = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'Buscar por ATS, cliente, máquina ou técnico...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            'Todos (${todosChamados.length})',
                            'todos',
                            selectedStatus: _filtroStatusRegistro,
                            onStatusSelected: (v) => setState(() => _filtroStatusRegistro = v),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Atribuídos (${todosChamados.where((c) => c.status == ChamadoStatus.atribuido).length})',
                            'atribuido',
                            selectedStatus: _filtroStatusRegistro,
                            onStatusSelected: (v) => setState(() => _filtroStatusRegistro = v),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Em Atendimento (${todosChamados.where((c) => c.status == ChamadoStatus.emAtendimento).length})',
                            'em_atendimento',
                            selectedStatus: _filtroStatusRegistro,
                            onStatusSelected: (v) => setState(() => _filtroStatusRegistro = v),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Finalizados (${todosChamados.where((c) => c.status == ChamadoStatus.finalizado).length})',
                            'finalizado',
                            selectedStatus: _filtroStatusRegistro,
                            onStatusSelected: (v) => setState(() => _filtroStatusRegistro = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _carregandoDocumentacoes ? null : _carregarDocumentacoesGerente,
                      icon: _carregandoDocumentacoes
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A369D)),
                            )
                          : const Icon(Icons.sync, size: 16),
                      label: const Text('Atualizar Pastas'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0A369D),
                        side: const BorderSide(color: Color(0xFF93C5FD)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: chamados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_off_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'Nenhum registro de chamado encontrado para os filtros aplicados.',
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
                            columnSpacing: 28,
                            columns: const [
                              DataColumn(label: Text('ATS Nº', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Cliente / Razão Social', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Máquina / Equipamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Fotos e Descritivo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Relatório Final', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('Custo Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                            rows: chamados.map((c) {
                              final doc = _documentacoesPorChamado[c.id];
                              final temPdfAprovado =
                                  (c.orcamentoPdfUrl != null && c.orcamentoPdfUrl!.trim().isNotEmpty) ||
                                  c.termosAceitos ||
                                  c.status == ChamadoStatus.aprovadoPendente ||
                                  c.status == ChamadoStatus.atribuido ||
                                  c.status == ChamadoStatus.emAtendimento ||
                                  c.status == ChamadoStatus.finalizado;
                              final temRelatorioFinal = c.status == ChamadoStatus.finalizado ||
                                  (c.relatorioPdfUrl != null && c.relatorioPdfUrl!.trim().isNotEmpty);
                              final versaoRelatorio = c.relatorioVersao > 0 ? c.relatorioVersao : 1;

                              final String pastaLabel;
                              final bool temConteudoPasta;
                              if (doc != null && doc.totalFotos > 0) {
                                pastaLabel =
                                    'Abrir Pasta (${doc.totalFotos} ${doc.totalFotos == 1 ? "foto" : "fotos"})';
                                temConteudoPasta = true;
                              } else if (doc != null && doc.possuiConteudo) {
                                pastaLabel = 'Abrir Pasta (Notas)';
                                temConteudoPasta = true;
                              } else {
                                pastaLabel = 'Abrir Pasta';
                                temConteudoPasta = false;
                              }

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      c.numeroAts.toUpperCase().startsWith('ATS-') ? c.numeroAts : 'ATS-${c.numeroAts}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A369D), fontSize: 13),
                                    ),
                                  ),
                                  DataCell(
                                    Text(c.razaoSocial, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ),
                                  DataCell(
                                    Text(c.modeloMaquina ?? 'Em levantamento', style: const TextStyle(fontSize: 12)),
                                  ),
                                  DataCell(_buildStatusBadge(c.status)),
                                  DataCell(
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        await showDialog(
                                          context: context,
                                          builder: (_) => DocumentacaoPastaDialog(
                                            chamado: c,
                                            initialDoc: doc,
                                            onAbrirRelatorioFinal:
                                                temRelatorioFinal ? () => _abrirRelatorioFinalizado(c) : null,
                                            onAbrirPdfAprovado:
                                                temPdfAprovado ? () => _abrirPdfAprovado(c) : null,
                                          ),
                                        );
                                        _carregarDocumentacoesGerente();
                                      },
                                      icon: const Icon(Icons.folder_open_rounded, size: 15),
                                      label: Text(pastaLabel),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor:
                                            temConteudoPasta ? const Color(0xFF4338CA) : Colors.white,
                                        foregroundColor:
                                            temConteudoPasta ? Colors.white : const Color(0xFF475569),
                                        side: BorderSide(
                                          color: temConteudoPasta
                                              ? const Color(0xFF4338CA)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        textStyle: TextStyle(
                                          fontSize: 11,
                                          fontWeight: temConteudoPasta ? FontWeight.bold : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(_buildBotaoRelatorioFinalizado(c, temRelatorioFinal, versaoRelatorio)),
                                  DataCell(_buildBotaoCalculoCustos(c, temRelatorioFinal)),
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

  Widget _buildBotaoRelatorioFinalizado(Chamado c, bool temRelatorioFinal, int versaoRelatorio) {
    if (!temRelatorioFinal) {
      return const Text(
        'Aguardando',
        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
      );
    }

    final enviadoGerente = c.relatorioGerenteEnviado;
    final Color fg = enviadoGerente ? const Color(0xFF15803D) : const Color(0xFFC2410C);
    final Color bg = enviadoGerente ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED);
    final Color border = enviadoGerente ? const Color(0xFF86EFAC) : const Color(0xFFFDBA74);

    return Tooltip(
      message: enviadoGerente
          ? 'Relatório p/ Gerente recebido — Pronto para cobrar o cliente'
          : 'Aguardando técnico atualizar KM em Relatório p/ Gerente',
      child: OutlinedButton.icon(
        onPressed: _abrindoRelatorioChamadoId == c.id
            ? null
            : () => _abrirRelatorioFinalizado(c),
        icon: _abrindoRelatorioChamadoId == c.id
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fg,
                ),
              )
            : Icon(
                enviadoGerente ? Icons.picture_as_pdf_rounded : Icons.schedule_rounded,
                size: 15,
              ),
        label: Text(
          _abrindoRelatorioChamadoId == c.id
              ? 'Abrindo...'
              : 'Finalizado v$versaoRelatorio',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: bg,
          side: BorderSide(color: border, width: 1.3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBotaoCalculoCustos(Chamado c, bool temRelatorioFinal) {
    if (!temRelatorioFinal) {
      return const Text(
        'Aguardando',
        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
      );
    }

    final enviadoGerente = c.relatorioGerenteEnviado;
    final temValor = c.custoTotalGerado > 0;
    final label = (temValor || enviadoGerente)
        ? NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(c.custoTotalGerado)
        : 'Calcular Custos';

    final Color fg = enviadoGerente ? const Color(0xFF0A369D) : const Color(0xFFD97706);
    final Color bg = enviadoGerente ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB);
    final Color border = enviadoGerente ? const Color(0xFF93C5FD) : const Color(0xFFFCD34D);

    return Tooltip(
      message: 'Abrir planilha de cálculo de KM, horas, despesas e custo total',
      child: OutlinedButton.icon(
        onPressed: () => _abrirModalCalculoCustos(c),
        icon: const Icon(Icons.calculate_outlined, size: 15),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: bg,
          side: BorderSide(color: border, width: 1.3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _abrirModalCalculoCustos(Chamado chamado) async {
    final atualizado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RelatorioGerenteDialog(chamado: chamado),
    );
    if (atualizado == true && mounted) {
      await ChamadosService.instance.recarregarChamados();
    }
  }

  String _gerarUrlPublica(Chamado chamado) {
    return UrlHelper.buildOrcamentoUrl(chamado.tokenUrl);
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
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[GerenteDashboard] Erro ao abrir WhatsApp: $e\n$stackTrace');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o WhatsApp. O link foi copiado para sua área de transferência.'),
            backgroundColor: Color(0xFF0A369D),
          ),
        );
        await _copiarLinkAprovacao(context, chamado);
      }
    }
  }

  /// Abre o PDF da proposta aprovada em nova aba ou gera em memória como fallback
  Future<void> _abrirPdfAprovado(Chamado chamado) async {
    setState(() => _abrindoPdfChamadoId = chamado.id);

    try {
      final pdfUrl = chamado.orcamentoPdfUrl?.trim();
      if (pdfUrl != null &&
          pdfUrl.isNotEmpty &&
          pdfUrl.startsWith('http') &&
          !pdfUrl.contains('storage.local')) {
        try {
          final uri = Uri.parse(pdfUrl);
          var launched = await launchUrl(
            uri,
            webOnlyWindowName: '_blank',
            mode: LaunchMode.externalApplication,
          );
          if (!launched) {
            launched = await launchUrl(
              uri,
              webOnlyWindowName: '_blank',
              mode: LaunchMode.platformDefault,
            );
          }
          if (launched) return;
        } catch (e, stackTrace) {
          if (kDebugMode) {
            debugPrint('[GerenteDashboard] Erro ao abrir URL direta do PDF, tentando fallback: $e\n$stackTrace');
          }
        }
      }

      Uint8List? pdfBytes;
      if (pdfUrl != null && pdfUrl.contains('/orcamentos/')) {
        try {
          final path = pdfUrl.split('/orcamentos/').last;
          final downloaded = await Supabase.instance.client.storage.from('orcamentos').download(path);
          if (downloaded.isNotEmpty) {
            pdfBytes = downloaded;
          }
        } catch (e, stackTrace) {
          if (kDebugMode) {
            debugPrint('[GerenteDashboard] Erro ao baixar PDF do Storage: $e\n$stackTrace');
          }
        }
      }

      pdfBytes ??= await OrcamentoPdfService.generatePdf(
        chamado: chamado,
        signatureBytes: await _obterAssinaturaBytes(chamado.assinaturaUrl),
        responsavelNome: chamado.responsavelAceiteNome ?? 'Cliente Responsável',
        responsavelCargo: chamado.responsavelAceiteCargo ?? 'Representante Autorizado',
      );

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes!,
        name: 'Proposta_ATS_${chamado.numeroAts}.pdf',
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[GerenteDashboard] Erro ao abrir PDF aprovado: $e\n$stackTrace');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir PDF aprovado: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _abrindoPdfChamadoId = null);
      }
    }
  }

  /// Abre o PDF do relatório técnico finalizado (v1, v2, ...) em nova aba ou gera como fallback
  Future<void> _abrirRelatorioFinalizado(Chamado chamado) async {
    setState(() => _abrindoRelatorioChamadoId = chamado.id);

    try {
      final relatorioUrl = chamado.relatorioPdfUrl?.trim();
      final versao = chamado.relatorioVersao > 0 ? chamado.relatorioVersao : 1;

      if (relatorioUrl != null &&
          relatorioUrl.isNotEmpty &&
          relatorioUrl.startsWith('http') &&
          !relatorioUrl.contains('storage.local')) {
        try {
          final uri = Uri.parse(relatorioUrl);
          var launched = await launchUrl(
            uri,
            webOnlyWindowName: '_blank',
            mode: LaunchMode.externalApplication,
          );
          if (!launched) {
            launched = await launchUrl(
              uri,
              webOnlyWindowName: '_blank',
              mode: LaunchMode.platformDefault,
            );
          }
          if (launched) return;
        } catch (e, stackTrace) {
          if (kDebugMode) {
            debugPrint('[GerenteDashboard] Erro ao abrir URL do relatório finalizado, tentando fallback: $e\n$stackTrace');
          }
        }
      }

      Uint8List? pdfBytes;
      if (relatorioUrl != null && relatorioUrl.contains('/orcamentos/')) {
        try {
          final path = relatorioUrl.split('/orcamentos/').last.split('?').first;
          final downloaded = await Supabase.instance.client.storage.from('orcamentos').download(path);
          if (downloaded.isNotEmpty) {
            pdfBytes = downloaded;
          }
        } catch (e, stackTrace) {
          if (kDebugMode) {
            debugPrint('[GerenteDashboard] Erro ao baixar relatório finalizado do Storage: $e\n$stackTrace');
          }
        }
      }

      if (pdfBytes == null) {
        final client = Supabase.instance.client;
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

        LogHorasCustos logHoras = LogHorasCustos(
          id: 'log-${DateTime.now().millisecondsSinceEpoch}',
          idChamado: chamado.id,
          data: dias.isNotEmpty ? dias.first.data : DateTime.now(),
          horaInicio: dias.isNotEmpty ? dias.first.horaInicio : '08:00',
          horaFim: dias.isNotEmpty ? (dias.first.horaFim ?? '17:00') : '17:00',
          kmRodado: chamado.kmEstimado ?? 0.0,
        );
        if (chamado.id.isNotEmpty && !chamado.id.startsWith('chamado-')) {
          try {
            final logRes = await client
                .from('log_horas_custos')
                .select()
                .eq('id_chamado', chamado.id)
                .order('updated_at', ascending: false)
                .limit(1)
                .maybeSingle();
            if (logRes != null) {
              logHoras = LogHorasCustos.fromJson(Map<String, dynamic>.from(logRes));
            }
          } catch (_) {}
        }

        final custosParaPdf =
            (chamado.relatorioGerenteEnviado && chamado.relatorioCustosJson != null)
                ? RelatorioCustosGerente.fromMap(chamado.relatorioCustosJson!)
                : null;

        pdfBytes = await AtsPdfService.instance.gerarRelatorioAtsPdf(
          chamado: chamado,
          logHoras: logHoras,
          diasTrabalho: dias,
          servicoExecutado: (chamado.servicoExecutado != null && chamado.servicoExecutado!.trim().isNotEmpty)
              ? chamado.servicoExecutado!.trim()
              : 'Atendimento e revisão técnica industrial concluídos.',
          assinaturaBytes: await _obterAssinaturaBytes(chamado.assinaturaUrl),
          responsavelNome: (chamado.responsavelAceiteNome != null && chamado.responsavelAceiteNome!.trim().isNotEmpty)
              ? chamado.responsavelAceiteNome!.trim()
              : (chamado.contato ?? 'Cliente Responsável'),
          videoUrl: chamado.videoUrl,
          versao: versao,
          custosGerente: custosParaPdf,
        );
      }

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes!,
        name: 'Relatorio_ATS_${chamado.numeroAts}_v$versao.pdf',
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[GerenteDashboard] Erro ao abrir relatório finalizado: $e\n$stackTrace');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir relatório finalizado: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _abrindoRelatorioChamadoId = null);
      }
    }
  }

  Future<void> _confirmarExclusaoChamado(BuildContext context, Chamado chamado) async {
    final atsLabel = chamado.numeroAts.toUpperCase().startsWith('ATS-')
        ? chamado.numeroAts
        : 'ATS-${chamado.numeroAts}';
    final tecnicosVinculados = [
      if (chamado.tecnicoNome != null && chamado.tecnicoNome!.trim().isNotEmpty)
        chamado.tecnicoNome!.trim(),
      if (chamado.tecnico2Nome != null && chamado.tecnico2Nome!.trim().isNotEmpty)
        chamado.tecnico2Nome!.trim(),
    ];

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 26),
            SizedBox(width: 8),
            Text('Excluir Chamado?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deseja apagar definitivamente o chamado $atsLabel?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                'Cliente: ${chamado.razaoSocial}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              if (tecnicosVinculados.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Este chamado está vinculado a: ${tecnicosVinculados.join(", ")}. Ao apagar, ele também será removido da tela do(s) técnico(s), junto com todos os registros vinculados e PDFs aprovados.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Text(
                  'Esta ação apagará permanentemente o chamado, registros vinculados e PDFs aprovados do sistema e não pode ser desfeita.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Apagar Definitivamente'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _excluindoChamadoId = chamado.id);
    try {
      final sucesso = await ChamadosService.instance.excluirChamado(chamado);
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              sucesso
                  ? 'Chamado $atsLabel excluído definitivamente.'
                  : (ChamadosService.instance.syncErrorNotifier.value ??
                      'Erro ao excluir o chamado $atsLabel.'),
            ),
            backgroundColor: sucesso ? const Color(0xFF10B981) : const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _excluindoChamadoId = null);
      }
    }
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
                            child: Text(
                              c.numeroAts.length >= 2 ? c.numeroAts.substring(c.numeroAts.length - 2) : c.numeroAts,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0A369D)),
                            ),
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
  // PÁGINA 4: PLANILHAS DE REEMBOLSO DOS TÉCNICOS
  // ============================================================================
  Widget _buildPlanilhasGerentePage() {
    final selecionado = _tecnicoSelecionadoPlanilha;
    if (selecionado != null) {
      return PlanilhaReembolsoWidget(
        tecnicoId: selecionado.id,
        tecnicoNome: selecionado.nome,
        isGerente: true,
        initialAno: _planilhaAnoGerente,
        initialMes: _planilhaMesGerente,
        onVoltar: () {
          setState(() => _tecnicoSelecionadoPlanilha = null);
          _carregarPlanilhasMesGerente();
        },
        onPlanilhaAtualizada: (p) {
          setState(() {
            _resumoPlanilhasMes = {..._resumoPlanilhasMes, p.tecnicoId: p};
          });
        },
      );
    }

    return ValueListenableBuilder<List<Tecnico>>(
      valueListenable: TecnicosService.instance.tecnicosNotifier,
      builder: (context, tecnicos, _) {
        double totalEquipeReceber = 0.0;
        double totalEquipeKm = 0.0;
        int enviadasOuAprovadas = 0;

        for (final t in tecnicos) {
          final p = _resumoPlanilhasMes[t.id];
          if (p != null) {
            totalEquipeReceber += p.totalGeralReceber;
            totalEquipeKm += p.totalGeralKm;
            if (p.status == StatusPlanilha.enviada || p.status == StatusPlanilha.aprovada) {
              enviadasOuAprovadas++;
            }
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de seleção do período mensal
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conferência de Planilhas e Reembolsos',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Selecione o técnico abaixo para visualizar sua planilha completa, taxas, PDF e aprovar o pagamento.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: _carregandoPlanilhasMes ? null : () => _alterarMesPlanilhaGerente(-1),
                                icon: const Icon(Icons.chevron_left_rounded),
                                tooltip: 'Mês anterior',
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '${mesesPtBr[(_planilhaMesGerente - 1).clamp(0, 11)]} / $_planilhaAnoGerente',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0A369D)),
                                ),
                              ),
                              IconButton(
                                onPressed: _carregandoPlanilhasMes ? null : () => _alterarMesPlanilhaGerente(1),
                                icon: const Icon(Icons.chevron_right_rounded),
                                tooltip: 'Próximo mês',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _carregandoPlanilhasMes ? null : _carregarPlanilhasMesGerente,
                          icon: _carregandoPlanilhasMes
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A369D)),
                                )
                              : const Icon(Icons.sync, size: 16),
                          label: const Text('Atualizar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Cards consolidados da equipe no mês
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Total Geral da Equipe',
                      formatarMoedaBr(totalEquipeReceber),
                      Icons.payments_outlined,
                      const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      'Enviadas / Aprovadas',
                      '$enviadasOuAprovadas de ${tecnicos.length}',
                      Icons.assignment_turned_in_outlined,
                      const Color(0xFF0A369D),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      'Total KM da Equipe',
                      '${formatarNumeroBr(totalEquipeKm)} km',
                      Icons.route_outlined,
                      const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (tecnicos.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.engineering_outlined, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      const Text(
                        'Nenhum técnico cadastrado na equipe.',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _abrirModalAdicionarTecnico(context),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Cadastrar Técnico'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A369D), foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                )
              else
                ...tecnicos.map((tec) {
                  final p = _resumoPlanilhasMes[tec.id];
                  final statusLabel = p != null ? StatusPlanilha.getLabel(p.status) : 'Não iniciada';
                  Color statusBg;
                  Color statusFg;
                  switch (p?.status) {
                    case StatusPlanilha.aprovada:
                      statusBg = const Color(0xFFDCFCE7);
                      statusFg = const Color(0xFF15803D);
                      break;
                    case StatusPlanilha.enviada:
                      statusBg = const Color(0xFFDBEAFE);
                      statusFg = const Color(0xFF1D4ED8);
                      break;
                    case StatusPlanilha.ajusteSolicitado:
                      statusBg = const Color(0xFFFEF3C7);
                      statusFg = const Color(0xFFB45309);
                      break;
                    default:
                      statusBg = const Color(0xFFF1F5F9);
                      statusFg = const Color(0xFF475569);
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFF0A369D),
                                child: Text(
                                  tec.nome.isNotEmpty ? tec.nome[0].toUpperCase() : 'T',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(tec.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
                                        child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusFg)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${tec.email ?? "Sem e-mail"} • ${tec.telefone.isNotEmpty ? tec.telefone : "Sem telefone"}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 20,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Lançamentos', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  Text(
                                    '${p?.itens.length ?? 0}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('KM no mês', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  Text(
                                    '${formatarNumeroBr(p?.totalGeralKm ?? 0.0)} km',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0A369D)),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Total a Receber', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  Text(
                                    formatarMoedaBr(p?.totalGeralReceber ?? 0.0),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF059669)),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () => setState(() => _tecnicoSelecionadoPlanilha = tec),
                                icon: const Icon(Icons.table_chart_outlined, size: 16),
                                label: const Text('Abrir Planilha'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A369D),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  // ============================================================================
  // PÁGINA 2: EQUIPE TÉCNICA
  // ============================================================================
  Widget _buildEquipeTecnicaPage() {
    return ValueListenableBuilder<List<Tecnico>>(
      valueListenable: TecnicosService.instance.tecnicosNotifier,
      builder: (context, tecnicos, _) {
        return ValueListenableBuilder<List<Chamado>>(
          valueListenable: ChamadosService.instance.chamadosNotifier,
          builder: (context, chamados, _) {
            if (tecnicos.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(
                          Icons.engineering_outlined,
                          size: 52,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Nenhum técnico cadastrado na equipe',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cadastre técnicos informando nome, telefone, e-mail e senha para criar contas reais com acesso completo ao aplicativo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _abrirModalAdicionarTecnico(context),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Cadastrar Primeiro Técnico'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A369D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total de Profissionais: ${tecnicos.length}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => TecnicosService.instance.recarregarTecnicos(),
                            icon: const Icon(Icons.sync, size: 16, color: Color(0xFF0A369D)),
                            label: const Text('Atualizar Equipe', style: TextStyle(color: Color(0xFF0A369D))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF93C5FD)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () => _abrirModalAdicionarTecnico(context),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Adicionar Técnico'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A369D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: tecnicos.length,
                    itemBuilder: (context, index) {
                      final tec = tecnicos[index];
                      final chamadosDoTecnico = chamados
                          .where((c) =>
                              c.tecnicoNome == tec.nome ||
                              c.tecnicoId == tec.id ||
                              c.tecnico2Nome == tec.nome ||
                              c.tecnico2Id == tec.id)
                          .toList();
                      final emAndamento = chamadosDoTecnico.where((c) => c.status != ChamadoStatus.finalizado).length;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: const Color(0xFF0A369D),
                                    child: Text(
                                      tec.nome.isNotEmpty ? tec.nome[0].toUpperCase() : 'T',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(tec.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          if (tec.especialidade != null && tec.especialidade!.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                tec.especialidade!,
                                                style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          if (tec.role == 'gerente_tecnico')
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'Gerente + Técnico',
                                                style: TextStyle(color: Color(0xFFB45309), fontSize: 10.5, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 4,
                                        children: [
                                          if (tec.telefone.isNotEmpty)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.phone, size: 13, color: Color(0xFF64748B)),
                                                const SizedBox(width: 4),
                                                Text(tec.telefone, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                              ],
                                            ),
                                          if (tec.email != null && tec.email!.isNotEmpty)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.email_outlined, size: 13, color: Color(0xFF64748B)),
                                                const SizedBox(width: 4),
                                                Text(tec.email!, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                              ],
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        emAndamento > 0
                                            ? 'Em atendimento ($emAndamento ordem(ns) atribuída(s))'
                                            : 'Disponível para novos atendimentos',
                                        style: TextStyle(
                                          color: emAndamento > 0 ? const Color(0xFF1D4ED8) : _emerald,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Chip(
                                    label: Text('$emAndamento O.S. ativas', style: const TextStyle(fontSize: 11)),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.table_chart_outlined, size: 15),
                                    label: const Text('Planilha'),
                                    onPressed: () {
                                      setState(() {
                                        _tecnicoSelecionadoPlanilha = tec;
                                        _selectedMenuIndex = 4;
                                      });
                                      _carregarPlanilhasMesGerente();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0A369D),
                                      side: const BorderSide(color: Color(0xFF93C5FD)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.edit_outlined, size: 15),
                                    label: const Text('Editar / Senha'),
                                    onPressed: () => _abrirModalEditarTecnico(context, tec),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF334155),
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFDC2626)),
                                    tooltip: 'Remover técnico',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Remover Técnico'),
                                          content: Text(
                                            'Deseja remover ${tec.nome} da equipe? A conta de acesso do técnico será desativada/removida do sistema.',
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                              onPressed: () => Navigator.pop(c, true),
                                              child: const Text('Remover', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        try {
                                          await TecnicosService.instance.removerTecnico(tec.id);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Técnico ${tec.nome} removido.'),
                                                backgroundColor: const Color(0xFF10B981),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Erro ao remover técnico: ${e.toString().replaceFirst("Exception: ", "")}'),
                                                backgroundColor: const Color(0xFFDC2626),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // MODAL: ADICIONAR NOVO TÉCNICO (CONTA REAL NO AUTH + PUBLIC.USUARIOS)
  // ============================================================================
  void _abrirModalAdicionarTecnico(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nomeCtrl = TextEditingController();
    final telefoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final senhaCtrl = TextEditingController();
    final especialidadeCtrl = TextEditingController();
    bool obscureSenha = true;
    bool salvando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF0A369D)),
                  SizedBox(width: 10),
                  Text('Adicionar Novo Técnico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFF1D4ED8)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Será criada uma conta real de acesso para este técnico entrar no app com suas próprias O.S., documentação, relatório final e planilha de reembolso.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: nomeCtrl,
                          decoration: InputDecoration(
                            labelText: 'Nome do Técnico *',
                            hintText: 'Ex: Carlos Silva',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome do técnico' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: telefoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Telefone / WhatsApp *',
                            hintText: 'Ex: (47) 99876-5432',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Informe o telefone de contato' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'E-mail de acesso *',
                            hintText: 'Ex: carlos.silva@pmach.com.br',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                          validator: (v) {
                            final email = (v ?? '').trim();
                            if (email.isEmpty) return 'Informe o e-mail de acesso';
                            if (!email.contains('@') || !email.contains('.')) return 'Informe um e-mail válido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: senhaCtrl,
                          obscureText: obscureSenha,
                          decoration: InputDecoration(
                            labelText: 'Senha inicial * (mín. 6 caracteres)',
                            hintText: 'Digite uma senha para o primeiro acesso',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(obscureSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setDialogState(() => obscureSenha = !obscureSenha),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Informe uma senha inicial';
                            if (v.trim().length < 6) return 'A senha deve ter pelo menos 6 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: especialidadeCtrl,
                          decoration: InputDecoration(
                            labelText: 'Especialidade (opcional)',
                            hintText: 'Ex: Manutenção Mecânica / CNC',
                            prefixIcon: const Icon(Icons.build_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: salvando ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  icon: salvando
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 16),
                  label: Text(salvando ? 'Criando Conta...' : 'Criar Conta do Técnico'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A369D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: salvando
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final nome = nomeCtrl.text.trim();
                          final telefone = telefoneCtrl.text.trim();
                          final email = emailCtrl.text.trim();
                          final senha = senhaCtrl.text.trim();
                          final especialidade = especialidadeCtrl.text.trim().isNotEmpty ? especialidadeCtrl.text.trim() : null;

                          setDialogState(() => salvando = true);
                          try {
                            await TecnicosService.instance.adicionarTecnico(
                              nome: nome,
                              telefone: telefone,
                              email: email,
                              password: senha,
                              especialidade: especialidade,
                            );

                            if (!context.mounted) return;
                            Navigator.pop(dialogCtx);

                            await showDialog(
                              context: context,
                              builder: (okCtx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                title: const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                                    SizedBox(width: 8),
                                    Expanded(child: Text('Técnico Cadastrado com Sucesso!')),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('A conta real de $nome já está ativa e pronta para uso.'),
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: SelectableText(
                                        'Portal: https://pmach-ats.web.app (Perfil Técnico)\nE-mail: $email\nSenha: $senha',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.5),
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(
                                          text: 'Acesso ATS Serviços (Perfil: Técnico)\nLink: https://pmach-ats.web.app\nE-mail: $email\nSenha: $senha',
                                        ),
                                      );
                                      if (okCtx.mounted) {
                                        ScaffoldMessenger.of(okCtx).showSnackBar(
                                          const SnackBar(
                                            content: Text('Dados de acesso copiados!'),
                                            backgroundColor: Color(0xFF10B981),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    label: const Text('Copiar Dados de Acesso'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(okCtx),
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A369D), foregroundColor: Colors.white),
                                    child: const Text('Fechar'),
                                  ),
                                ],
                              ),
                            );
                          } catch (e) {
                            if (ctx.mounted) {
                              setDialogState(() => salvando = false);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erro ao criar técnico: ${e.toString().replaceFirst("Exception: ", "")}'),
                                  backgroundColor: const Color(0xFFDC2626),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // MODAL: EDITAR DADOS / REDEFINIR SENHA DO TÉCNICO
  // ============================================================================
  void _abrirModalEditarTecnico(BuildContext context, Tecnico tec) {
    final formKey = GlobalKey<FormState>();
    final nomeCtrl = TextEditingController(text: tec.nome);
    final telefoneCtrl = TextEditingController(text: tec.telefone);
    final especialidadeCtrl = TextEditingController(text: tec.especialidade ?? '');
    final novaSenhaCtrl = TextEditingController();
    bool obscureNovaSenha = true;
    bool salvando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.manage_accounts_outlined, color: Color(0xFF0A369D)),
              SizedBox(width: 10),
              Text('Editar Técnico / Redefinir Senha', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tec.email != null && tec.email!.isNotEmpty) ...[
                      Text('E-mail de acesso: ${tec.email}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: nomeCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nome *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: telefoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Telefone / WhatsApp *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Informe o telefone' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: especialidadeCtrl,
                      decoration: InputDecoration(
                        labelText: 'Especialidade (opcional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: novaSenhaCtrl,
                      obscureText: obscureNovaSenha,
                      decoration: InputDecoration(
                        labelText: 'Nova Senha (deixe em branco para manter)',
                        suffixIcon: IconButton(
                          icon: Icon(obscureNovaSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setDialogState(() => obscureNovaSenha = !obscureNovaSenha),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty && v.trim().length < 6) {
                          return 'A nova senha deve ter pelo menos 6 caracteres';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: salvando ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: salvando
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => salvando = true);
                      try {
                        await TecnicosService.instance.atualizarTecnico(
                          id: tec.id,
                          nome: nomeCtrl.text.trim(),
                          telefone: telefoneCtrl.text.trim(),
                          especialidade: especialidadeCtrl.text.trim().isNotEmpty ? especialidadeCtrl.text.trim() : null,
                          novaSenha: novaSenhaCtrl.text.trim().isNotEmpty ? novaSenhaCtrl.text.trim() : null,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Dados do técnico atualizados com sucesso!'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      } catch (e) {
                        if (ctx.mounted) setDialogState(() => salvando = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao atualizar técnico: ${e.toString().replaceFirst("Exception: ", "")}'),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A369D), foregroundColor: Colors.white),
              child: Text(salvando ? 'Salvando...' : 'Salvar Alterações'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // MODAL: NOVA PROPOSTA COMERCIAL
  // ============================================================================
  void _abrirModalCriarEAtribuir(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final clienteCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final telefoneCtrl = TextEditingController();
    final maquinaCtrl = TextEditingController();
    final defeitoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Row(
                children: [
                  Icon(Icons.request_quote_outlined, color: Color(0xFF0A369D)),
                  SizedBox(width: 8),
                  Text('Nova Proposta Comercial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

                      // 1. Cria a proposta com status orcamento_pendente_envio e id_tecnico = null
                      final novo = await ChamadosService.instance.criarNovoChamado(
                        contato: clienteCtrl.text.trim(),
                        emailCliente: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                        telefone: telefoneCtrl.text.trim(),
                        modeloMaquina: maquinaCtrl.text.trim(),
                        defeitoRelatado: defeitoCtrl.text.trim(),
                      );

                      if (context.mounted) {
                        final msg = novo.pendingSync
                            ? 'Proposta O.S. Nº ${novo.numeroAts} salva localmente (offline/pendente de sincronização com o banco).'
                            : 'Proposta O.S. Nº ${novo.numeroAts} criada com sucesso!';
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
                  child: const Text('Gerar Link de Proposta'),
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
    if (_tecnicosDisponiveis.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nenhum Técnico Cadastrado'),
          content: const Text(
            'Para atribuir um chamado, cadastre primeiro ao menos um técnico na aba "Equipe de Técnicos em Campo".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _abrirModalAdicionarTecnico(context);
              },
              child: const Text('Cadastrar Técnico Agora'),
            ),
          ],
        ),
      );
      return;
    }

    String tecnico1Selecionado = chamado.tecnicoNome ?? _tecnicosDisponiveis.first;
    String tecnico2Selecionado = (chamado.tecnico2Nome != null && chamado.tecnico2Nome!.trim().isNotEmpty)
        ? chamado.tecnico2Nome!
        : 'Nenhum';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Atribuir Técnicos - ATS Nº ${chamado.numeroAts}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cliente: ${chamado.razaoSocial}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Máquina: ${chamado.modeloMaquina ?? "N/A"}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _tecnicosDisponiveis.contains(tecnico1Selecionado)
                          ? tecnico1Selecionado
                          : _tecnicosDisponiveis.first,
                      decoration: InputDecoration(
                        labelText: 'Técnico 1 (Principal)',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: _tecnicosDisponiveis.map((t) {
                        return DropdownMenuItem(value: t, child: Text(t));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => tecnico1Selecionado = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: (_tecnicosDisponiveis.contains(tecnico2Selecionado) || tecnico2Selecionado == 'Nenhum')
                          ? tecnico2Selecionado
                          : 'Nenhum',
                      decoration: InputDecoration(
                        labelText: 'Técnico 2 (Auxiliar - Opcional)',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'Nenhum', child: Text('Nenhum (Apenas 1 técnico)')),
                        ..._tecnicosDisponiveis.map((t) {
                          return DropdownMenuItem(value: t, child: Text(t));
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => tecnico2Selecionado = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    final tec2 = (tecnico2Selecionado != 'Nenhum' && tecnico2Selecionado.trim().isNotEmpty)
                        ? tecnico2Selecionado.trim()
                        : null;
                    final tec1Obj = TecnicosService.instance.buscarPorNome(tecnico1Selecionado);
                    final tec2Obj = tec2 != null ? TecnicosService.instance.buscarPorNome(tec2) : null;
                    await ChamadosService.instance.atribuirTecnico(
                      chamadoId: chamado.id,
                      tecnicoNome: tecnico1Selecionado,
                      tecnicoId: tec1Obj?.id,
                      tecnico2Nome: tec2,
                      tecnico2Id: tec2Obj?.id,
                    );
                    if (context.mounted) {
                      final msg = tec2 != null
                          ? 'Técnicos $tecnico1Selecionado e $tec2 atribuídos à ATS Nº ${chamado.numeroAts}!'
                          : 'Técnico $tecnico1Selecionado atribuído à ATS Nº ${chamado.numeroAts}!';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
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
    if (!chamado.relatorioGerenteEnviado) {
      final prosseguir = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.schedule_rounded, color: Color(0xFFEA580C), size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Custos Finais Pendentes (Laranja)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'O técnico ainda não enviou o "Relatório p/ Gerente" com o fechamento de KM e custos finais deste atendimento.\n\n'
            'Quando o técnico enviar, a barra "Relatório Finalizado" ficará Verde com o valor total.\n\n'
            'Deseja aguardar o técnico ou gerar/enviar para o cliente mesmo assim?',
            style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF334155)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Aguardar Técnico'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Enviar Mesmo Assim'),
            ),
          ],
        ),
      );
      if (prosseguir != true) return;
    }

    setState(() => _enviandoEmailChamadoId = chamado.id);

    try {
      final client = Supabase.instance.client;
      Chamado chamadoAtual = chamado;

      if (chamado.id.isNotEmpty && !chamado.id.startsWith('chamado-')) {
        try {
          final freshRow = await client
              .from('chamados')
              .select(Chamado.selectColumnsCompletas)
              .eq('id', chamado.id)
              .maybeSingle();
          if (freshRow != null) {
            chamadoAtual = Chamado.fromMap(Map<String, dynamic>.from(freshRow));
          }
        } catch (_) {}
      }

      // 1. Busca os dias de trabalho atualizados
      List<DiaTrabalho> dias = chamadoAtual.diasTrabalho;
      if (chamadoAtual.id.isNotEmpty && !chamadoAtual.id.startsWith('chamado-')) {
        try {
          final diasRes = await client
              .from('ats_dias_trabalho')
              .select()
              .eq('chamado_id', chamadoAtual.id)
              .order('data', ascending: true);
          if (diasRes.isNotEmpty) {
            dias = (diasRes as List)
                .map((d) => DiaTrabalho.fromMap(Map<String, dynamic>.from(d as Map)))
                .toList();
          }
        } catch (e, stackTrace) {
          if (kDebugMode) {
            debugPrint('[GerenteDashboard] Erro ao carregar dias de trabalho da nuvem: $e\n$stackTrace');
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Falha na comunicação ao sincronizar dias de trabalho. Utilizando dados locais.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      // 2. Busca log_horas_custos real com KM, pedágio, refeição, hospedagem e peças
      LogHorasCustos logHoras = LogHorasCustos(
        id: 'log-${DateTime.now().millisecondsSinceEpoch}',
        idChamado: chamadoAtual.id,
        data: dias.isNotEmpty ? dias.first.data : DateTime.now(),
        horaInicio: dias.isNotEmpty ? dias.first.horaInicio : '08:00',
        horaFim: dias.isNotEmpty ? (dias.first.horaFim ?? '17:00') : '17:00',
        kmRodado: chamadoAtual.kmEstimado ?? 0.0,
      );
      if (chamadoAtual.id.isNotEmpty && !chamadoAtual.id.startsWith('chamado-')) {
        try {
          final logRes = await client
              .from('log_horas_custos')
              .select()
              .eq('id_chamado', chamadoAtual.id)
              .order('updated_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (logRes != null) {
            logHoras = LogHorasCustos.fromJson(Map<String, dynamic>.from(logRes));
          }
        } catch (_) {}
      }

      final RelatorioCustosGerente? custosParaPdf =
          (chamadoAtual.relatorioGerenteEnviado && chamadoAtual.relatorioCustosJson != null)
              ? RelatorioCustosGerente.fromMap(chamadoAtual.relatorioCustosJson!)
              : null;

      // 3. Obtém assinatura (ou fallback transparente)
      final assinaturaBytes = await _obterAssinaturaBytes(chamadoAtual.assinaturaUrl);

      // 4. Gera o PDF oficial da ATS com os custos completos
      final versao = chamadoAtual.relatorioVersao > 0 ? chamadoAtual.relatorioVersao : 1;
      final pdfBytes = await AtsPdfService.instance.gerarRelatorioAtsPdf(
        chamado: chamadoAtual,
        logHoras: logHoras,
        diasTrabalho: dias,
        servicoExecutado: (chamadoAtual.servicoExecutado != null && chamadoAtual.servicoExecutado!.trim().isNotEmpty)
            ? chamadoAtual.servicoExecutado!.trim()
            : 'Atendimento e revisão técnica industrial concluídos.',
        assinaturaBytes: assinaturaBytes,
        responsavelNome: (chamadoAtual.responsavelAceiteNome != null && chamadoAtual.responsavelAceiteNome!.trim().isNotEmpty)
            ? chamadoAtual.responsavelAceiteNome!.trim()
            : (chamadoAtual.contato ?? 'Cliente Responsável'),
        videoUrl: chamadoAtual.videoUrl,
        versao: versao,
        custosGerente: custosParaPdf,
      );

      // 5. Upload do PDF (v$versao) para o Supabase Storage
      final cleanAts = chamadoAtual.numeroAts.replaceAll('ATS-', '').trim();
      final pdfPath = 'relatorios_ats/ats_${cleanAts}_v$versao.pdf';
      final ts = DateTime.now().millisecondsSinceEpoch;
      await client.storage.from('orcamentos').uploadBinary(
            pdfPath,
            pdfBytes,
            fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
          );
      final pdfUrl = '${client.storage.from('orcamentos').getPublicUrl(pdfPath)}?t=$ts';

      // 6. UPDATE na tabela chamados atualizando relatorio_pdf_url (preserva orcamento_pdf_url)
      if (chamadoAtual.id.isNotEmpty && !chamadoAtual.id.startsWith('chamado-')) {
        await client.from('chamados').update({
          'relatorio_pdf_url': pdfUrl,
          'relatorio_versao': versao,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', chamadoAtual.id);
      } else {
        await client.from('chamados').update({
          'relatorio_pdf_url': pdfUrl,
          'relatorio_versao': versao,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('numero_ats', cleanAts);
      }

      // Atualiza o chamado no cache reativo local
      await ChamadosService.instance.atualizarChamado(
        chamadoAtual.copyWith(relatorioPdfUrl: pdfUrl, relatorioVersao: versao),
      );

      // 7. Invoca a Supabase Edge Function send-ats-pdf
      final response = await client.functions.invoke(
        'send-ats-pdf',
        body: {
          'chamado_id': chamadoAtual.id,
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
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('[GerenteDashboard] Erro ao baixar assinatura do Storage: $e\n$stackTrace');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Falha na comunicação ao obter a assinatura digital remota.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
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
