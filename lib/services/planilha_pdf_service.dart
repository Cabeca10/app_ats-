import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/planilha_reembolso.dart';

/// Gera o PDF oficial em paisagem da Planilha Mensal de Reembolso espelhando o Excel
class PlanilhaPdfService {
  PlanilhaPdfService._internal();
  static final PlanilhaPdfService instance = PlanilhaPdfService._internal();

  Future<Uint8List> gerarPdf(PlanilhaReembolso planilha) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo_pmach.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final resumo = planilha.calcularResumoPorCategoria();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // Cabeçalho institucional
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 38,
                      height: 38,
                      margin: const pw.EdgeInsets.only(right: 10),
                      child: pw.Image(logoImage),
                    ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PLANILHA MENSAL DE REEMBOLSO E HORAS TÉCNICAS',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFF0A369D),
                        ),
                      ),
                      pw.Text(
                        'Pmach Equipamentos e Peças Ltda • ATS Serviços',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Técnico: ${planilha.tecnicoNome}',
                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Período: ${planilha.nomeMesAno} • Status: ${StatusPlanilha.getLabel(planilha.status)}',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),

          // Faixa de taxas configuradas
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF1F5F9),
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFCBD5E1), width: 0.6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Valor do km: ${formatarMoedaBr(planilha.valorKm)}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                pw.Text('Valor do km interno: ${formatarMoedaBr(planilha.valorKmInterno)}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                pw.Text('Valor Hora técnica: ${formatarMoedaBr(planilha.valorHoraTecnica)}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                pw.Text('Valor hora viagem: ${formatarMoedaBr(planilha.valorHoraViagem)}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // Tabela diária de lançamentos (15 colunas)
          pw.Text(
            'Lançamentos Diários (${planilha.itens.length} registros)',
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F172A)),
          ),
          pw.SizedBox(height: 4),
          if (planilha.itens.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text('Nenhum lançamento registrado neste mês.', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
            )
          else
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFCBD5E1), width: 0.4),
              headerStyle: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF0A369D)),
              cellStyle: const pw.TextStyle(fontSize: 6.5),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              headers: const [
                'Dia',
                'Cliente',
                'No.OS',
                'Tipo',
                'Início',
                'Almoço',
                'Fim',
                'Trab.',
                'Viagem',
                'Km',
                'Pedágio',
                'Refeição',
                'Peças',
                'Outros',
                'Motivo de outros',
              ],
              data: [
                ...planilha.itens.map((item) => [
                      dateFormat.format(item.dia),
                      item.cliente,
                      item.numeroOs,
                      item.tipoAtendimento,
                      item.horarioInicial,
                      item.pausaAlmoco,
                      item.horarioFinal,
                      formatarMinutosHHMM(item.totalHorasTrabalhadasMin),
                      formatarMinutosHHMM(item.horaViagemMin),
                      formatarNumeroBr(item.km),
                      formatarNumeroBr(item.pedagio),
                      formatarNumeroBr(item.refeicao),
                      formatarNumeroBr(item.pecas),
                      formatarNumeroBr(item.outros),
                      item.motivoOutros,
                    ]),
                [
                  'TOTAIS',
                  '',
                  '',
                  '',
                  '',
                  '',
                  '',
                  formatarMinutosHHMM(planilha.totalGeralHorasTrabalhadasMin),
                  formatarMinutosHHMM(planilha.totalGeralHorasViagemMin),
                  formatarNumeroBr(planilha.totalGeralKm),
                  formatarNumeroBr(planilha.totalGeralPedagios),
                  formatarNumeroBr(planilha.totalGeralRefeicao),
                  formatarNumeroBr(planilha.totalGeralPecas),
                  formatarNumeroBr(planilha.totalGeralOutros),
                  '',
                ],
              ],
            ),
          pw.SizedBox(height: 14),

          // Quadro Resumo por Categoria idêntico à planilha
          pw.Text(
            'Quadro Resumo de Reembolso por Tipo de Atendimento',
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F172A)),
          ),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFCBD5E1), width: 0.4),
            headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E293B)),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
            headers: [
              'Indicador',
              ...TipoAtendimentoPlanilha.todos,
              'Total Geral',
            ],
            data: [
              [
                'Horas trabalhadas',
                ...TipoAtendimentoPlanilha.todos.map((t) => formatarMinutosHHMM(resumo[t]!.horasTrabalhadasMin)),
                formatarMinutosHHMM(planilha.totalGeralHorasTrabalhadasMin),
              ],
              [
                'Total a pagar horas trabalhadas',
                ...TipoAtendimentoPlanilha.todos.map((t) => formatarMoedaBr(resumo[t]!.valorHorasTrabalhadas)),
                formatarMoedaBr(planilha.totalGeralPagarHorasTrabalhadas),
              ],
              [
                'Horas viagens',
                ...TipoAtendimentoPlanilha.todos.map((t) => formatarMinutosHHMM(resumo[t]!.horasViagemMin)),
                formatarMinutosHHMM(planilha.totalGeralHorasViagemMin),
              ],
              [
                'Total a pagar horas viagens',
                ...TipoAtendimentoPlanilha.todos.map((t) => formatarMoedaBr(resumo[t]!.valorHorasViagem)),
                formatarMoedaBr(planilha.totalGeralPagarHorasViagem),
              ],
              [
                'Total Km',
                ...TipoAtendimentoPlanilha.todos.map((t) => formatarNumeroBr(resumo[t]!.totalKm)),
                formatarNumeroBr(planilha.totalGeralKm),
              ],
              [
                'Total a pagar KM',
                ...TipoAtendimentoPlanilha.todos.map((t) => formatarMoedaBr(resumo[t]!.valorKm)),
                formatarMoedaBr(planilha.totalGeralPagarKm),
              ],
              [
                'Pedágios',
                ...TipoAtendimentoPlanilha.todos.map((t) => formatarMoedaBr(resumo[t]!.pedagios)),
                formatarMoedaBr(planilha.totalGeralPedagios),
              ],
              [
                'Refeição',
                ...TipoAtendimentoPlanilha.todos.map((t) => formatarMoedaBr(resumo[t]!.refeicao)),
                formatarMoedaBr(planilha.totalGeralRefeicao),
              ],
              [
                'Peças',
                ...TipoAtendimentoPlanilha.todos.map((t) => formatarMoedaBr(resumo[t]!.pecas)),
                formatarMoedaBr(planilha.totalGeralPecas),
              ],
              [
                'Outros',
                ...TipoAtendimentoPlanilha.todos.map((t) => formatarMoedaBr(resumo[t]!.outros)),
                formatarMoedaBr(planilha.totalGeralOutros),
              ],
              [
                'Total a receber',
                ...TipoAtendimentoPlanilha.todos.map((t) => formatarMoedaBr(resumo[t]!.totalReceber)),
                formatarMoedaBr(planilha.totalGeralReceber),
              ],
            ],
          ),
          pw.SizedBox(height: 12),

          // Total Geral Destacado
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFECFDF5),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColor.fromInt(0xFF10B981), width: 1.0),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL GERAL A RECEBER NO MÊS (${planilha.nomeMesAno.toUpperCase()})',
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF065F46),
                  ),
                ),
                pw.Text(
                  formatarMoedaBr(planilha.totalGeralReceber),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF065F46),
                  ),
                ),
              ],
            ),
          ),
          if (planilha.observacaoGerente.trim().isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Observação do Gerente: ${planilha.observacaoGerente}',
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }
}
