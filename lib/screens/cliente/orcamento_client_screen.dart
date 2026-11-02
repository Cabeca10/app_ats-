import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chamado.dart';
import '../../services/chamados_service.dart';
import '../../services/orcamento_pdf_service.dart';

class OrcamentoClientScreen extends StatefulWidget {
  final String token;

  const OrcamentoClientScreen({
    super.key,
    required this.token,
  });

  @override
  State<OrcamentoClientScreen> createState() => _OrcamentoClientScreenState();
}

class _OrcamentoClientScreenState extends State<OrcamentoClientScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  late final SignatureController _signatureController;
  final _fabricanteController = TextEditingController();
  final _modeloController = TextEditingController();
  final _numeroSerieController = TextEditingController();
  final _defeitoController = TextEditingController();
  final _razaoSocialController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _inscricaoEstadualController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _nomeController = TextEditingController();
  final _cargoController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _termosAceitos = false;
  bool _aprovadoComSucesso = false;
  bool _jaAprovadoPreviamente = false;
  Uint8List? _generatedPdfBytes;

  Chamado? _chamado;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 2.5,
      penColor: const Color(0xFF0F172A),
      exportBackgroundColor: Colors.white,
    );
    _carregarDadosChamado();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _fabricanteController.dispose();
    _modeloController.dispose();
    _numeroSerieController.dispose();
    _defeitoController.dispose();
    _razaoSocialController.dispose();
    _cnpjController.dispose();
    _inscricaoEstadualController.dispose();
    _enderecoController.dispose();
    _telefoneController.dispose();
    _nomeController.dispose();
    _cargoController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosChamado() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic>? data;
      try {
        final response = await Supabase.instance.client
            .from('chamados')
            .select()
            .eq('token_url', widget.token)
            .maybeSingle();
        if (response != null) {
          data = Map<String, dynamic>.from(response);
        }
      } catch (directErr) {
        if (kDebugMode) {
          debugPrint('[OrcamentoClientScreen] Consulta direta por token_url: $directErr');
        }
        try {
          final rpcRes = await Supabase.instance.client
              .rpc('obter_orcamento_por_token', params: {'p_token': widget.token});
          if (rpcRes != null && rpcRes is Map) {
            data = Map<String, dynamic>.from(rpcRes);
          }
        } catch (_) {}
      }

      if (data != null) {
        _chamado = Chamado.fromMap(data);
      } else {
        final local = ChamadosService.instance.obterChamadoPorToken(widget.token);
        if (local != null) {
          _chamado = local;
        } else {
          _chamado = _criarChamadoMock(widget.token);
        }
      }

      final jaAprovado = _chamado!.status == ChamadoStatus.aprovadoPendente ||
          _chamado!.status == ChamadoStatus.atribuido ||
          _chamado!.status == ChamadoStatus.emAtendimento ||
          _chamado!.status == ChamadoStatus.finalizado ||
          _chamado!.termosAceitos == true ||
          _chamado!.aceiteData != null;

      if (jaAprovado) {
        _jaAprovadoPreviamente = true;
        _aprovadoComSucesso = true;
      }

      // Preenchimento dos controladores (se existirem dados preenchidos no chamado)
      _fabricanteController.text = _chamado?.fabricante ?? '';
      _modeloController.text = _chamado?.modeloMaquina ?? '';
      _numeroSerieController.text = _chamado?.numeroSerie ?? '';
      _defeitoController.text = _chamado?.defeitoRelatado ?? '';
      _razaoSocialController.text = (_chamado?.razaoSocial != null && !_chamado!.razaoSocial.startsWith('mock-'))
          ? _chamado!.razaoSocial
          : '';
      _cnpjController.text = _chamado?.cnpj ?? '';
      _inscricaoEstadualController.text = _chamado?.inscricaoEstadual ?? '';
      _enderecoController.text = _chamado?.endereco ?? '';
      _telefoneController.text = _chamado?.telefone ?? '';
      _nomeController.text = _chamado?.responsavelAceiteNome ?? '';
      _cargoController.text = _chamado?.responsavelAceiteCargo ?? '';
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[OrcamentoClient] Erro ao carregar chamado/orçamento via token: $e\n$stackTrace');
      }
      _chamado = _criarChamadoMock(widget.token);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Chamado _criarChamadoMock(String token) {
    return Chamado(
      id: 'mock-uuid-001',
      numeroAts: '014742',
      razaoSocial: '',
      cnpj: null,
      inscricaoEstadual: null,
      telefone: null,
      clienteEmail: null,
      endereco: null,
      cidade: null,
      fabricante: '',
      modeloMaquina: '',
      numeroSerie: '',
      defeitoRelatado: '',
      tokenUrl: token,
      status: ChamadoStatus.orcamentoEnviado,
      taxaHorariaComercial: 306.00,
      taxaHorariaExtra: 459.00,
      taxaHorariaEspecial: 612.00,
      taxaKm: 3.20,
      kmEstimado: 45.0,
      horaViagemEstimada: 1.0,
      valorEstimadoTotal: 1850.00,
    );
  }

  void _mostrarLoadingModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            constraints: const BoxConstraints(maxWidth: 460),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF0A369D),
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Processando Assinatura',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Compilando documento oficial e registrando assinatura eletrônica...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submeterAprovacao() async {
    if (_razaoSocialController.text.trim().isEmpty) {
      _mostrarAlerta('Informe a Razão Social da empresa.');
      return;
    }

    if (_cnpjController.text.trim().isEmpty) {
      _mostrarAlerta('Informe o CNPJ da empresa.');
      return;
    }

    if (_inscricaoEstadualController.text.trim().isEmpty) {
      _mostrarAlerta('Informe a Inscrição Estadual (ou informe ISENTO).');
      return;
    }

    if (_enderecoController.text.trim().isEmpty) {
      _mostrarAlerta('Informe o Endereço Completo da empresa.');
      return;
    }

    if (_telefoneController.text.trim().isEmpty) {
      _mostrarAlerta('Informe o Telefone / WhatsApp da empresa.');
      return;
    }

    if (!_termosAceitos) {
      _mostrarAlerta('Por favor, confirme o aceite dos termos de atendimento.');
      return;
    }

    if (_nomeController.text.trim().isEmpty) {
      _mostrarAlerta('Informe o nome completo do responsável pela aprovação.');
      return;
    }

    if (_signatureController.isEmpty) {
      _mostrarAlerta('Por favor, desenhe sua assinatura no campo indicado.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    _mostrarLoadingModal();
    bool modalAberto = true;

    try {
      final sigBytes = await _signatureController.toPngBytes();
      if (sigBytes == null) {
        throw Exception('Erro ao capturar assinatura.');
      }

      final fabricante = _fabricanteController.text.trim();
      final modelo = _modeloController.text.trim();
      final serie = _numeroSerieController.text.trim();
      final defeito = _defeitoController.text.trim();
      final razao = _razaoSocialController.text.trim();
      final cnpj = _cnpjController.text.trim();
      final ie = _inscricaoEstadualController.text.trim();
      final end = _enderecoController.text.trim();
      final telefone = _telefoneController.text.trim();
      final nome = _nomeController.text.trim();
      final cargo = _cargoController.text.trim().isEmpty ? 'Responsável Autorizado' : _cargoController.text.trim();

      // Atualiza o chamado em memória com os dados preenchidos pelo cliente
      _chamado = _chamado!.copyWith(
        fabricante: fabricante.isNotEmpty ? fabricante : _chamado!.fabricante,
        modeloMaquina: modelo.isNotEmpty ? modelo : _chamado!.modeloMaquina,
        numeroSerie: serie.isNotEmpty ? serie : _chamado!.numeroSerie,
        defeitoRelatado: defeito.isNotEmpty ? defeito : _chamado!.defeitoRelatado,
        razaoSocial: razao,
        cnpj: cnpj,
        inscricaoEstadual: ie,
        endereco: end,
        telefone: telefone,
        responsavelAceiteNome: nome,
        responsavelAceiteCargo: cargo,
        termosAceitos: true,
        aceiteData: DateTime.now(),
        status: ChamadoStatus.aprovadoPendente,
      );

      // Gera o documento PDF formal
      final pdfBytes = await OrcamentoPdfService.generatePdf(
        chamado: _chamado!,
        signatureBytes: sigBytes,
        responsavelNome: nome,
        responsavelCargo: cargo,
      );

      _generatedPdfBytes = pdfBytes;

      // Salva no Supabase Storage e aciona a Edge Function
      await OrcamentoPdfService.uploadAssetsAndUpdateChamado(
        chamado: _chamado!,
        signatureBytes: sigBytes,
        pdfBytes: pdfBytes,
        responsavelNome: nome,
        responsavelCargo: cargo,
      );

      if (mounted && modalAberto) {
        Navigator.of(context, rootNavigator: true).pop();
        modalAberto = false;
      }

      if (mounted) {
        setState(() {
          _aprovadoComSucesso = true;
          _jaAprovadoPreviamente = false;
        });
      }
    } catch (e) {
      if (mounted && modalAberto) {
        Navigator.of(context, rootNavigator: true).pop();
        modalAberto = false;
      }
      _mostrarAlerta('Erro ao registrar aprovação: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _mostrarAlerta(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF0A369D);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: themeColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
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
      ),
      body: _aprovadoComSucesso
          ? _buildTelaSucesso()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Banner do Orçamento
                      _buildHeaderBanner(),
                      const SizedBox(height: 16),

                      // Card 1: Dados do Equipamento e Sintoma (cliente visualiza primeiro)
                      _buildEquipamentoCard(),
                      const SizedBox(height: 16),

                      // Card 2: Dados Cadastrais Obrigatórios (preenchidos/confirmados pelo cliente)
                      _buildClienteCard(),
                      const SizedBox(height: 16),

                      // Card 3: Condições Comerciais e Taxas
                      _buildCondicoesComerciaisCard(),
                      const SizedBox(height: 16),

                      // Card 4: Termos de Prestação de Serviço
                      _buildTermosCard(),
                      const SizedBox(height: 24),

                      // Card 5: Assinatura Digital do Cliente
                      _buildAssinaturaCard(),
                      const SizedBox(height: 28),

                      // Botão de Ação: Aprovar
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submeterAprovacao,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A369D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child: _isSubmitting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Gerando PDF e gravando aceite...',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'Aprovar Orçamento e Assinar',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'PORTAL PÚBLICO DO CLIENTE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E40AF),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Orçamento de Assistência Técnica',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Revise as condições operacionais e assine eletronicamente abaixo.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipamentoCard() {
    return _buildSectionCard(
      title: '1. Dados do Equipamento & Sintoma Relatado',
      icon: Icons.precision_manufacturing_outlined,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF1E40AF)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Informe os dados da máquina que necessita de atendimento técnico e relate o defeito.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Fabricante e Modelo
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _fabricanteController,
                decoration: InputDecoration(
                  labelText: 'Fabricante',
                  hintText: 'Ex: Pmach, Haas, Romi',
                  prefixIcon: const Icon(Icons.precision_manufacturing_outlined, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _modeloController,
                decoration: InputDecoration(
                  labelText: 'Modelo da Máquina',
                  hintText: 'Ex: Torno CNC ST-20',
                  prefixIcon: const Icon(Icons.build_outlined, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Nº de Série
        TextFormField(
          controller: _numeroSerieController,
          decoration: InputDecoration(
            labelText: 'Nº de Série (se houver)',
            hintText: 'Ex: SN-2024-8841',
            prefixIcon: const Icon(Icons.tag, size: 18),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),

        // Defeito / Ocorrência Relatada (Editável)
        TextFormField(
          controller: _defeitoController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Defeito / Ocorrência Relatada',
            hintText: 'Descreva sucintamente a anomalia, ruído ou serviço solicitado...',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.report_problem_outlined, size: 18),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildClienteCard() {
    return _buildSectionCard(
      title: '2. Dados Cadastrais da Empresa (Obrigatório)',
      icon: Icons.business,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.edit_note, size: 18, color: Color(0xFF1E40AF)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Por favor, preencha as informações cadastrais e fiscais da sua empresa para emissão da O.S. e faturamento antes de assinar.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Razão Social
        TextFormField(
          controller: _razaoSocialController,
          decoration: InputDecoration(
            labelText: 'Razão Social *',
            hintText: 'Nome empresarial completo',
            prefixIcon: const Icon(Icons.business_outlined, size: 18),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),

        // CNPJ e Inscrição Estadual
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _cnpjController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'CNPJ *',
                  hintText: '00.000.000/0001-00',
                  prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _inscricaoEstadualController,
                decoration: InputDecoration(
                  labelText: 'Inscrição Estadual *',
                  hintText: 'Número ou ISENTO',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Endereço Completo
        TextFormField(
          controller: _enderecoController,
          decoration: InputDecoration(
            labelText: 'Endereço Completo de Instalação *',
            hintText: 'Rua, Número, Bairro, Cidade - UF, CEP',
            prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),

        // Telefone / WhatsApp
        TextFormField(
          controller: _telefoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Telefone / WhatsApp de Contato *',
            hintText: '(00) 00000-0000',
            prefixIcon: const Icon(Icons.phone_outlined, size: 18),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildCondicoesComerciaisCard() {
    return _buildSectionCard(
      title: '3. Condições Comerciais e Tarifário de Serviços',
      icon: Icons.attach_money,
      children: [
        Table(
          border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1.2),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
              children: const [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Item / Descrição', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Valor Unitário', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            _buildTarifaRow('Hora Técnica Comercial (08:00 às 18:00)', _currencyFormat.format(_chamado?.taxaHorariaComercial ?? 306)),
            _buildTarifaRow('Hora Técnica Extraordinária (Após 18:00 e Sábados)', _currencyFormat.format(_chamado?.taxaHorariaExtra ?? 459)),
            _buildTarifaRow('Hora Técnica Especial (Domingos e Feriados)', _currencyFormat.format(_chamado?.taxaHorariaEspecial ?? 612)),
            _buildTarifaRow('Deslocamento por KM Rodado', '${_currencyFormat.format(_chamado?.taxaKm ?? 3.20)} / km'),
            _buildTarifaRow('Despesas de Estadia / Refeição', 'Conforme comprovante'),
          ],
        ),
      ],
    );
  }

  TableRow _buildTarifaRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ),
      ],
    );
  }

  Widget _buildTermosCard() {
    return _buildSectionCard(
      title: '4. Termos e Condições de Atendimento',
      icon: Icons.gavel_outlined,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Os termos abaixo são referentes ao serviço de assistência técnica. A aceitação desse é necessária para efetivação do atendimento.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155),
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 14),

              // 1. Da solicitação:
              Text(
                '1. Da solicitação:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              SizedBox(height: 4),
              Text(
                '1.1 Para efetivação da solicitação de atendimento é necessário o preenchimento completo do orçamento;\n'
                '1.2 O atendimento será agendado após aprovação do orçamento e análise de crédito.',
                style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF475569)),
              ),
              SizedBox(height: 14),

              // 2. Dos custos:
              Text(
                '2. Dos custos:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              SizedBox(height: 4),
              Text(
                '2.1 A cobrança do deslocamento iniciará a partir da residência do técnico que será previamente informada ao cliente;\n'
                '2.2 O atendimento será realizado por 1 (um) técnico da Pmach. Caso necessário, será deslocado mais um profissional mediante prévio aviso e aprovação dos custos;\n'
                '2.3 Em serviços que exijam movimentação de peças pesadas e/ou partes da máquina, os equipamentos necessários (empilhadeira, ponte rolante, talhas) deverão ser providenciados pelo cliente;\n'
                '2.4 Despesas com transporte de ferramentas e/ou instrumentos de grande porte serão de responsabilidade do cliente;\n'
                '2.5 Nos atendimentos que o pernoite for necessário, gastos com estadia, café da manhã e alimentação noturna terão ônus ao cliente;\n'
                '2.6 Quando, para a solução completa do defeito, se fizer necessária a substituição de peça(s), após o término do atendimento será enviado orçamento da(s) peça(s) avariada(s) e as horas gastas no diagnóstico técnico serão cobradas normalmente.',
                style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF475569)),
              ),
              SizedBox(height: 14),

              // 3. Da cobrança e prazo de pagamento:
              Text(
                '3. Da cobrança e prazo de pagamento:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              SizedBox(height: 4),
              Text(
                '3.1 Após fechamento do relatório técnico, o departamento financeiro enviará um demonstrativo de cobrança. O prazo para análise e contestação do demonstrativo é de 01 dia útil;\n'
                '3.2 A nota fiscal de prestação de serviço e boleto serão emitidos após a aprovação do demonstrativo ou expiração do prazo de análise. O prazo de pagamento será de 10 dias.',
                style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF475569)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Checkbox(
              value: _termosAceitos,
              activeColor: const Color(0xFF0A369D),
              onChanged: (val) {
                setState(() {
                  _termosAceitos = val ?? false;
                });
              },
            ),
            const Expanded(
              child: Text(
                'Li e concordo expressamente com as condições comerciais e termos de atendimento descritos acima.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssinaturaCard() {
    return _buildSectionCard(
      title: '5. Assinatura Digital do Responsável',
      icon: Icons.draw_outlined,
      children: [
        TextField(
          controller: _nomeController,
          decoration: InputDecoration(
            labelText: 'Nome Completo do Responsável *',
            hintText: 'Ex: João da Silva',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cargoController,
          decoration: InputDecoration(
            labelText: 'Cargo / Departamento',
            hintText: 'Ex: Gerente de Manutenção / Diretor Industrial',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Desenhe a sua assinatura abaixo:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            TextButton.icon(
              onPressed: () => _signatureController.clear(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Limpar Assinatura'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF0A369D), width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Signature(
              controller: _signatureController,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '* Assine usando o dedo na tela ou o mouse.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0A369D), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A369D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }


  Future<void> _baixarPdfAssinado() async {
    try {
      if (_generatedPdfBytes != null) {
        await Printing.layoutPdf(
          onLayout: (_) => _generatedPdfBytes!,
          name: 'Proposta_${_chamado?.numeroAts ?? "ATS"}_Assinada.pdf',
        );
        return;
      }

      if (_chamado == null) return;

      Uint8List? pdfBytes;
      final pdfUrl = _chamado!.orcamentoPdfUrl;
      if (pdfUrl != null && pdfUrl.isNotEmpty) {
        try {
          String path = pdfUrl;
          if (path.contains('/orcamentos/')) {
            path = path.split('/orcamentos/').last;
          }
          final downloaded = await Supabase.instance.client.storage.from('orcamentos').download(path);
          if (downloaded.isNotEmpty) {
            pdfBytes = downloaded;
          }
        } catch (e) {
          debugPrint('[OrcamentoClient] Erro ao baixar PDF do storage: $e');
        }
      }

      if (pdfBytes == null) {
        Uint8List sigBytes = Uint8List.fromList([
          137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
          0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 11, 73, 68, 65, 84,
          120, 1, 99, 96, 0, 0, 0, 2, 0, 1, 244, 113, 100, 166, 0, 0, 0, 0, 73, 69,
          78, 68, 174, 66, 96, 130
        ]);

        if (_chamado!.assinaturaUrl != null && _chamado!.assinaturaUrl!.isNotEmpty) {
          try {
            String path = _chamado!.assinaturaUrl!;
            if (path.contains('/orcamentos/')) {
              path = path.split('/orcamentos/').last;
            }
            final downloadedSig = await Supabase.instance.client.storage.from('orcamentos').download(path);
            if (downloadedSig.isNotEmpty) {
              sigBytes = downloadedSig;
            }
          } catch (_) {}
        }

        pdfBytes = await OrcamentoPdfService.generatePdf(
          chamado: _chamado!,
          signatureBytes: sigBytes,
          responsavelNome: _chamado!.responsavelAceiteNome ?? 'Responsável Autorizado',
          responsavelCargo: _chamado!.responsavelAceiteCargo ?? 'Cliente',
        );
      }

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes!,
        name: 'Proposta_${_chamado?.numeroAts ?? "ATS"}_Assinada.pdf',
      );
    } catch (e) {
      _mostrarAlerta('Erro ao visualizar documento PDF: $e');
    }
  }

  Widget _buildTelaSucesso() {
    final dateFormat = DateFormat('dd/MM/yyyy às HH:mm');
    final titulo = _jaAprovadoPreviamente
        ? 'Proposta Comercial Já Assinada'
        : 'Orçamento Aprovado com Sucesso!';
    final subtitulo = _jaAprovadoPreviamente
        ? 'Esta proposta comercial para a Ordem de Serviço Nº ${_chamado?.numeroAts ?? ""} já foi formalmente aprovada e assinada eletronicamente.'
        : 'A Ordem de Serviço Nº ${_chamado?.numeroAts ?? ""} foi registrada no sistema com sucesso. Nossa equipe técnica já foi notificada para providenciar o atendimento.';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCFCE7), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFDCFCE7),
                ),
                child: const Icon(Icons.verified, color: Color(0xFF166534), size: 48),
              ),
              const SizedBox(height: 20),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 10),
              Text(
                subtitulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4),
              ),
              const SizedBox(height: 20),

              // Card com resumo dos dados registrados
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'REGISTRO DA PROPOSTA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A369D),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ORÇAMENTO APROVADO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    _buildLinhaResumo('O.S. / Proposta:', 'Nº ${_chamado?.numeroAts ?? ""}'),
                    _buildLinhaResumo('Empresa:', _chamado?.razaoSocial ?? 'Não informado'),
                    if (_chamado?.cnpj != null && _chamado!.cnpj!.isNotEmpty)
                      _buildLinhaResumo('CNPJ:', _chamado!.cnpj!),
                    if (_chamado?.responsavelAceiteNome != null && _chamado!.responsavelAceiteNome!.isNotEmpty)
                      _buildLinhaResumo('Responsável:', '${_chamado!.responsavelAceiteNome} (${_chamado!.responsavelAceiteCargo ?? "Cliente"})'),
                    if (_chamado?.aceiteData != null)
                      _buildLinhaResumo('Data de Assinatura:', dateFormat.format(_chamado!.aceiteData!)),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _baixarPdfAssinado,
                icon: const Icon(Icons.picture_as_pdf, size: 20),
                label: const Text('Baixar Cópia em PDF da Proposta', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A369D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinhaResumo(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
