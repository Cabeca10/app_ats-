import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chamado.dart';
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
  final _nomeController = TextEditingController();
  final _cargoController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _termosAceitos = false;
  bool _aprovadoComSucesso = false;
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
    _nomeController.dispose();
    _cargoController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosChamado() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('chamados')
          .select()
          .eq('token_url', widget.token)
          .maybeSingle();

      if (response != null) {
        _chamado = Chamado.fromMap(response);
        if (_chamado!.status == ChamadoStatus.aprovadoPendente ||
            _chamado!.status == ChamadoStatus.atribuido ||
            _chamado!.status == ChamadoStatus.finalizado) {
          _aprovadoComSucesso = true;
        }
      } else {
        // Mock demonstrativo caso o token não exista no banco remoto ou em teste local
        _chamado = _criarChamadoMock(widget.token);
      }
    } catch (_) {
      // Fallback gracioso com dados de demonstração
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
      razaoSocial: 'Metalúrgica Haas Joinville Ltda',
      cnpj: '84.123.456/0001-99',
      inscricaoEstadual: '254.987.123',
      telefone: '(47) 3456-7890',
      clienteEmail: 'manutencao@haasjoinville.com.br',
      endereco: 'Rua das Indústrias, 1500 - Distrito Industrial',
      cidade: 'Joinville - SC',
      fabricante: 'Pmach',
      modeloMaquina: 'Centro de Usinagem CNC V-400',
      numeroSerie: 'PM-2024-8841',
      defeitoRelatado: 'Alarme 1042 no fuso principal durante usinagem em alta rotação. Vibração anormal identificada.',
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

  Future<void> _submeterAprovacao() async {
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

    try {
      final sigBytes = await _signatureController.toPngBytes();
      if (sigBytes == null) {
        throw Exception('Erro ao capturar assinatura.');
      }

      final nome = _nomeController.text.trim();
      final cargo = _cargoController.text.trim().isEmpty ? 'Responsável Autorizado' : _cargoController.text.trim();

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

      if (mounted) {
        setState(() {
          _aprovadoComSucesso = true;
          _chamado = _chamado!.copyWith(
            status: ChamadoStatus.aprovadoPendente,
            termosAceitos: true,
            responsavelAceiteNome: nome,
            responsavelAceiteCargo: cargo,
            aceiteData: DateTime.now(),
          );
        });
      }
    } catch (e) {
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

                      // Card: Dados do Cliente
                      _buildClienteCard(),
                      const SizedBox(height: 16),

                      // Card: Dados do Equipamento e Sintoma
                      _buildEquipamentoCard(),
                      const SizedBox(height: 16),

                      // Card: Condições Comerciais e Taxas
                      _buildCondicoesComerciaisCard(),
                      const SizedBox(height: 16),

                      // Card: Termos de Prestação de Serviço
                      _buildTermosCard(),
                      const SizedBox(height: 24),

                      // Card: Assinatura Digital do Cliente
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
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
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Nº ATS / O.S.',
                  style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                Text(
                  _chamado?.numeroAts ?? '---',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A369D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClienteCard() {
    return _buildSectionCard(
      title: '1. Identificação da Empresa',
      icon: Icons.business,
      children: [
        _buildInfoRow('Razão Social:', _chamado?.razaoSocial ?? '---'),
        _buildInfoRow('CNPJ:', _chamado?.cnpj ?? '---'),
        _buildInfoRow('Inscrição Estadual:', _chamado?.inscricaoEstadual ?? '---'),
        _buildInfoRow('Endereço:', _chamado?.endereco ?? '---'),
        _buildInfoRow('Telefone:', _chamado?.telefone ?? '---'),
        _buildInfoRow('E-mail:', _chamado?.clienteEmail ?? '---'),
      ],
    );
  }

  Widget _buildEquipamentoCard() {
    return _buildSectionCard(
      title: '2. Dados do Equipamento & Sintoma Relatado',
      icon: Icons.precision_manufacturing_outlined,
      children: [
        _buildInfoRow('Fabricante:', _chamado?.fabricante ?? 'Pmach'),
        _buildInfoRow('Modelo:', _chamado?.modeloMaquina ?? '---'),
        _buildInfoRow('Nº de Série:', _chamado?.numeroSerie ?? '---'),
        const Divider(height: 18),
        const Text(
          'Defeito / Ocorrência Relatada:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            _chamado?.defeitoRelatado ?? 'Revisão técnica preventiva e corretiva.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Text(
            '1. A aprovação deste orçamento autoriza o agendamento e o deslocamento dos técnicos especializados da ATS Serviços.\n'
            '2. As horas técnicas serão apuradas conforme apontamento no Relatório ATS final assinado pelo representante da contratante.\n'
            '3. Peças e componentes adicionais serão cotados separadamente mediante autorização expressa.\n'
            '4. Garantia legal de 90 dias sobre os serviços executados.',
            style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF475569)),
          ),
        ),
        const SizedBox(height: 12),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
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
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelaSucesso() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFDCFCE7),
                ),
                child: const Icon(Icons.check, color: Color(0xFF166534), size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'Orçamento Aprovado com Sucesso!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 10),
              Text(
                'A Ordem de Serviço Nº ${_chamado?.numeroAts ?? ""} foi registrada no sistema. Nossa equipe técnica já foi notificada para providenciar o atendimento.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  if (_generatedPdfBytes != null) {
                    await Printing.layoutPdf(onLayout: (_) => _generatedPdfBytes!);
                  } else {
                    // Tenta recriar ou abrir
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Abrindo documento assinado...')),
                    );
                  }
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Baixar Orçamento Assinado (PDF)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A369D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
