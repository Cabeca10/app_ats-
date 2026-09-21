import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/chamado.dart';
import '../models/log_horas_custos.dart';
import '../models/dia_trabalho.dart';

/// Serviço para geração do relatório técnico industrial (ATS) em PDF
/// com assinatura do cliente e QR Code direcionando para o vídeo do teste.
class AtsPdfService {
  static final AtsPdfService instance = AtsPdfService._internal();
  AtsPdfService._internal();

  /// Gera os bytes do PDF da ATS finalizada
  Future<Uint8List> gerarRelatorioAtsPdf({
    required Chamado chamado,
    required LogHorasCustos logHoras,
    List<DiaTrabalho> diasTrabalho = const [],
    required String servicoExecutado,
    required Uint8List assinaturaBytes,
    required String responsavelNome,
    String? videoUrl,
    String? fotoUrl,
  }) async {
    final pdf = pw.Document();

    // Tenta carregar logo Pmach
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo_pmach.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final signatureImage = pw.MemoryImage(assinaturaBytes);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            // 1. CABEÇALHO INDUSTRIAL
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        width: 50,
                        height: 50,
                        margin: const pw.EdgeInsets.only(right: 12),
                        child: pw.Image(logoImage),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'ATS SERVIÇOS',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0xFF0A369D),
                          ),
                        ),
                        pw.Text(
                          'Equipamentos e Peças Ltda - Manutenção Industrial',
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF1F5F9),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromInt(0xFFCBD5E1)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'RELATÓRIO TÉCNICO ATS',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0A369D)),
                      ),
                      pw.Text(
                        'Nº ${chamado.numeroAts}',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                      ),
                      pw.Text(
                        'Emissão: ${dateFormat.format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // 2. DADOS DO CLIENTE E DO EQUIPAMENTO
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '1. DADOS DO CLIENTE E LOCALIZAÇÃO',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0A369D)),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text('Razão Social: ${chamado.razaoSocial}', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('CNPJ: ${chamado.cnpj ?? "Não informado"}', style: const pw.TextStyle(fontSize: 8)),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text('Endereço: ${chamado.endereco ?? "Não informado"}', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('Telefone: ${chamado.telefone ?? "Não informado"}', style: const pw.TextStyle(fontSize: 8)),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text('E-mail: ${chamado.emailCliente ?? "Não informado"}', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('Contato: ${chamado.contato ?? "Não informado"}', style: const pw.TextStyle(fontSize: 8)),
                      ),
                    ],
                  ),
                  pw.Divider(color: PdfColor.fromInt(0xFFE2E8F0), thickness: 0.5, height: 10),
                  pw.Text(
                    '2. DADOS DO EQUIPAMENTO / MÁQUINA',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0A369D)),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text('Modelo: ${chamado.modeloMaquina ?? "Conforme atendimento"}', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Expanded(
                        child: pw.Text('Fabricante: ${chamado.fabricante ?? "N/A"}', style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Expanded(
                        child: pw.Text('Nº de Série: ${chamado.numeroSerie ?? "N/A"}', style: const pw.TextStyle(fontSize: 8)),
                      ),
                    ],
                  ),
                  if (chamado.defeitoRelatado != null && chamado.defeitoRelatado!.isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Text('Defeito Informado: ${chamado.defeitoRelatado}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                  ],
                  pw.Divider(color: PdfColor.fromInt(0xFFE2E8F0), thickness: 0.5, height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TIPO DE ATENDIMENTO:',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0A369D)),
                      ),
                      pw.Row(
                        children: [
                          _buildTipoCheckbox('SERV. ENG.', chamado.tipoAtendimento == 'SERV. ENG.'),
                          pw.SizedBox(width: 10),
                          _buildTipoCheckbox('MANUTENÇÃO', chamado.tipoAtendimento == 'MANUTENÇÃO'),
                          pw.SizedBox(width: 10),
                          _buildTipoCheckbox('INSTALAÇÃO', chamado.tipoAtendimento == 'INSTALAÇÃO'),
                          pw.SizedBox(width: 10),
                          _buildTipoCheckbox('GARANTIA', chamado.tipoAtendimento == 'GARANTIA'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // 3. HORAS E CUSTOS DE DESLOCAMENTO
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '3. APONTAMENTO DE DIAS E HORAS TRABALHADAS (ATS)',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0A369D)),
                  ),
                  pw.SizedBox(height: 6),
                  if (diasTrabalho.isNotEmpty) ...[
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
                          children: [
                            _buildTh('Data'),
                            _buildTh('Início'),
                            _buildTh('Fim'),
                            _buildTh('Almoço'),
                            _buildTh('Viagem'),
                            _buildTh('H. Líquidas'),
                            _buildTh('Nº Técn.'),
                            _buildTh('Técnicos Alocados'),
                          ],
                        ),
                        ...diasTrabalho.map(
                          (d) => pw.TableRow(
                            children: [
                              _buildTd(d.dataFormatada),
                              _buildTd(d.horaInicio),
                              _buildTd(d.horaFim ?? '--'),
                              _buildTd(d.horaAlmoco),
                              _buildTd(d.horaViagem),
                              _buildTd(d.horasLiquidasFormatadas),
                              _buildTd('${d.numeroTecnicos}'),
                              _buildTd(d.nomesTecnicos.isNotEmpty ? d.nomesTecnicos : 'Técnico responsável'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                  ] else ...[
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
                          children: [
                            _buildTh('Data'),
                            _buildTh('Hora Início'),
                            _buildTh('Hora Fim'),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            _buildTd(dateFormat.format(logHoras.data)),
                            _buildTd(logHoras.horaInicio),
                            _buildTd(logHoras.horaFim),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                  ],

                  pw.Text(
                    'DESPESAS OPERACIONAIS DO ATENDIMENTO',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF475569)),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
                        children: [
                          _buildTh('Km Rodado'),
                          _buildTh('Pedágio'),
                          _buildTh('Refeição'),
                          _buildTh('Total Despesas Extras'),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          _buildTd('${logHoras.kmRodado.toStringAsFixed(1)} km'),
                          _buildTd(currencyFormat.format(logHoras.pedagio)),
                          _buildTd(currencyFormat.format(logHoras.refeicao)),
                          _buildTd(currencyFormat.format(logHoras.totalDespesasExtras)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // 4. MEMORIAL DO SERVIÇO EXECUTADO
            pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '4. RELATÓRIO TÉCNICO DOS SERVIÇOS EXECUTADOS',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0A369D)),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    servicoExecutado.trim().isNotEmpty ? servicoExecutado : 'Intervenção técnica e testes realizados com sucesso.',
                    style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.4),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // 5. SEÇÃO DE VALIDAÇÃO: QR CODE DO VÍDEO & ASSINATURA DIGITAL
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // QR Code para vídeo do teste
                if (videoUrl != null && videoUrl.isNotEmpty) ...[
                  pw.Container(
                    width: 130,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'VÍDEO DO TESTE',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0A369D)),
                        ),
                        pw.SizedBox(height: 4),
                        pw.BarcodeWidget(
                          data: videoUrl,
                          barcode: pw.Barcode.qrCode(),
                          width: 80,
                          height: 80,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Aponte a câmera para ver o teste de funcionamento',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 14),
                ],

                // Assinatura do Cliente
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'ACEITE E ASSINATURA DO CLIENTE',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0A369D)),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          height: 65,
                          child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                        ),
                        pw.Divider(color: PdfColor.fromInt(0xFFCBD5E1), thickness: 0.5),
                        pw.Text(
                          responsavelNome.isNotEmpty ? responsavelNome : 'Responsável Técnico / Cliente',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Declaro que os serviços e horas discriminados acima foram prestados e aprovados.',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildTh(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        title,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0A369D)),
      ),
    );
  }

  pw.Widget _buildTd(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 7.5),
      ),
    );
  }

  pw.Widget _buildTipoCheckbox(String label, bool isSelected) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 9,
          height: 9,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: isSelected ? PdfColor.fromInt(0xFF0A369D) : PdfColors.grey600,
              width: 1,
            ),
            color: isSelected ? PdfColor.fromInt(0xFF0A369D) : PdfColors.white,
            borderRadius: pw.BorderRadius.circular(1.5),
          ),
          child: isSelected
              ? pw.Center(
                  child: pw.Text(
                    'X',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                )
              : null,
        ),
        pw.SizedBox(width: 4),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: isSelected ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isSelected ? PdfColor.fromInt(0xFF0A369D) : PdfColors.grey800,
          ),
        ),
      ],
    );
  }
}
