import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

class RelatorioMensalPdf {
  static const String _vehiclesKey    = 'veiculos_v1';
  static const String _fuelKeyPrefix  = 'fuel_records_';
  static const String _maintKeyPrefix = 'maintenance_records_';
  static const String _tireKeyPrefix  = 'tire_records_';
  static const String _companyNameKey = 'company_name';

  static const PdfColor _navyDark    = PdfColor.fromInt(0xFF0A1628);
  static const PdfColor _navy        = PdfColor.fromInt(0xFF152744);
  static const PdfColor _navyMid     = PdfColor.fromInt(0xFF1E3A5F);
  static const PdfColor _navyLight   = PdfColor.fromInt(0xFF2E5481);
  static const PdfColor _navyAccent  = PdfColor.fromInt(0xFF1A4A7A);
  static const PdfColor _gold        = PdfColor.fromInt(0xFFC9A227);
  static const PdfColor _goldLight   = PdfColor.fromInt(0xFFE8C547);
  static const PdfColor _goldPale    = PdfColor.fromInt(0xFFFFFBED);
  static const PdfColor _greenProfit = PdfColor.fromInt(0xFF155724);
  static const PdfColor _greenMid    = PdfColor.fromInt(0xFF28A745);
  static const PdfColor _greenLight  = PdfColor.fromInt(0xFFD4EDDA);
  static const PdfColor _redLoss     = PdfColor.fromInt(0xFF721C24);
  static const PdfColor _redMid      = PdfColor.fromInt(0xFFDC3545);
  static const PdfColor _redLight    = PdfColor.fromInt(0xFFF8D7DA);
  static const PdfColor _amber       = PdfColor.fromInt(0xFF856404);
  static const PdfColor _amberLight  = PdfColor.fromInt(0xFFFFF3CD);
  static const PdfColor _amberMid    = PdfColor.fromInt(0xFFFFC107);
  static const PdfColor _gray50      = PdfColor.fromInt(0xFFFAFAFA);
  static const PdfColor _gray100     = PdfColor.fromInt(0xFFF8F9FA);
  static const PdfColor _gray200     = PdfColor.fromInt(0xFFE9ECEF);
  static const PdfColor _gray300     = PdfColor.fromInt(0xFFDEE2E6);
  static const PdfColor _gray400     = PdfColor.fromInt(0xFFCED4DA);
  static const PdfColor _gray500     = PdfColor.fromInt(0xFF6C757D);
  static const PdfColor _gray600     = PdfColor.fromInt(0xFF495057);
  static const PdfColor _gray700     = PdfColor.fromInt(0xFF343A40);
  static const PdfColor _white       = PdfColors.white;
  static const PdfColor _divider     = PdfColor.fromInt(0xFFE0E0E0);

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return 0.0;
    return double.tryParse(s.replaceAll(',', '.')) ?? 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static String _fmt2(double v) {
    final s       = v.toStringAsFixed(2);
    final partes  = s.split('.');
    final inteiro = partes[0];
    final decimal = partes[1];
    final negativo= inteiro.startsWith('-');
    final numeros = negativo ? inteiro.substring(1) : inteiro;
    final buffer  = StringBuffer();
    for (int i = 0; i < numeros.length; i++) {
      if (i > 0 && (numeros.length - i) % 3 == 0) buffer.write('.');
      buffer.write(numeros[i]);
    }
    return '${negativo ? '-' : ''}${buffer.toString()},$decimal';
  }

  static String _fmtInt(double v) {
    final inteiro = v.toInt().toString();
    final negativo= inteiro.startsWith('-');
    final numeros = negativo ? inteiro.substring(1) : inteiro;
    final buffer  = StringBuffer();
    for (int i = 0; i < numeros.length; i++) {
      if (i > 0 && (numeros.length - i) % 3 == 0) buffer.write('.');
      buffer.write(numeros[i]);
    }
    return '${negativo ? '-' : ''}${buffer.toString()}';
  }

  static String _money(double v) => 'R\$ ${_fmt2(v)}';

  static String _nomeMes(int mes) {
    const m = ['','JANEIRO','FEVEREIRO','MARCO','ABRIL','MAIO','JUNHO',
        'JULHO','AGOSTO','SETEMBRO','OUTUBRO','NOVEMBRO','DEZEMBRO'];
    return mes >= 1 && mes <= 12 ? m[mes] : '';
  }

  static bool _isInMonth(String? iso, int ano, int mes) {
    if (iso == null || iso.isEmpty) return false;
    try {
      final d = DateTime.parse(iso);
      return d.year == ano && d.month == mes;
    } catch (_) { return false; }
  }

  static String _nomeVeiculo(String placa, String tipo) {
    if (tipo.isEmpty) return placa;
    return '$placa / $tipo';
  }

  static Future<List<int>> gerar({required int mes, required int ano}) async {
    final prefs = await SharedPreferences.getInstance();
    final empresa = prefs.getString(_companyNameKey)?.trim() ?? 'Gestor de Frota';
    final empresaNome = empresa.isEmpty ? 'Gestor de Frota' : empresa;

    final raw = prefs.getString(_vehiclesKey);
    List<Map<String, dynamic>> vehicles = [];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          vehicles = decoded.whereType<Map>()
              .map((e) => e.cast<String, dynamic>()).toList();
        }
      } catch (_) {}
    }

    double totalFuelLitros = 0, totalFuelCusto = 0, totalMaintCusto = 0;
    double totalTireCusto = 0, totalKmReal = 0, totalFaturamento = 0;
    int totalTireQtd = 0, totalAbastecimentos = 0;
    int totalManutencoes = 0, totalPneus = 0, viagensComNota = 0;

    final veicData = <Map<String, dynamic>>[];
    final veicHist = <String, List<Map<String, dynamic>>>{};

    for (final v in vehicles) {
      final id    = (v['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final placa = (v['placa'] ?? '').toString();
      final tipo  = (v['tipo']  ?? v['modelo'] ?? '').toString();
      final nome  = _nomeVeiculo(placa, tipo);

      final fuelRaw = prefs.getString('$_fuelKeyPrefix$id');
      double vFuelL = 0, vFuelC = 0, vKm = 0;
      int vAbast = 0;
      double vFat = 0, vLucro = 0;
      final List<Map<String, dynamic>> hist = [];

      if (fuelRaw != null && fuelRaw.trim().isNotEmpty) {
        try {
          final dec = jsonDecode(fuelRaw);
          if (dec is List) {
            for (final r in dec.whereType<Map>()) {
              final dateStr = r['date']?.toString() ?? '';
              try {
                final d = DateTime.parse(dateStr);
                final diff = (ano * 12 + mes) - (d.year * 12 + d.month);
                if (diff >= 0 && diff < 6) {
                  final litros  = _toDouble(r['litrosFinal']);
                  final kmRod   = _toDouble(r['kmRodadoReal']);
                  final consumo = (litros > 0 && kmRod > 0) ? kmRod / litros : 0.0;
                  hist.add({
                    'mes': d.month, 'ano': d.year, 'litros': litros,
                    'custo': _toDouble(r['custoFinal']), 'km': kmRod,
                    'consumo': consumo, 'motorista': r['motorista']?.toString() ?? '',
                    'date': dateStr, 'isMesAtual': d.year == ano && d.month == mes,
                  });
                }
              } catch (_) {}

              if (!_isInMonth(r['date']?.toString(), ano, mes)) continue;
              final litros   = _toDouble(r['litrosFinal']);
              final custo    = _toDouble(r['custoFinal']);
              final kmRodado = _toDouble(r['kmRodadoReal']);
              final valNota  = _toDouble(r['valorNota']);
              vFuelL += litros;
              vFuelC += custo;
              if (kmRodado > 0) vKm += kmRodado;
              vAbast++;
              if (valNota > 0) {
                vFat   += valNota;
                vLucro += (valNota - custo);
                viagensComNota++;
              }
            }
          }
        } catch (_) {}
      }

      final maintRaw = prefs.getString('$_maintKeyPrefix$id');
      double vMaintC = 0; int vManut = 0;
      if (maintRaw != null && maintRaw.trim().isNotEmpty) {
        try {
          final dec = jsonDecode(maintRaw);
          if (dec is List) {
            for (final r in dec.whereType<Map>()) {
              if (!_isInMonth(r['date']?.toString(), ano, mes)) continue;
              vMaintC += _toDouble(r['custo']); vManut++;
            }
          }
        } catch (_) {}
      }

      final tireRaw = prefs.getString('$_tireKeyPrefix$id');
      double vTireC = 0; int vTireQ = 0, vPneus = 0;
      if (tireRaw != null && tireRaw.trim().isNotEmpty) {
        try {
          final dec = jsonDecode(tireRaw);
          if (dec is List) {
            for (final r in dec.whereType<Map>()) {
              if (!_isInMonth(r['date']?.toString(), ano, mes)) continue;
              vTireC += _toDouble(r['custo']);
              vTireQ += _toInt(r['quantidade']);
              vPneus++;
            }
          }
        } catch (_) {}
      }

      final vTotal   = vFuelC + vMaintC + vTireC;
      final vConsumo = (vFuelL > 0 && vKm > 0) ? vKm / vFuelL : 0.0;
      final vCustKm  = (vKm > 0) ? vTotal / vKm : 0.0;

      if (vTotal > 0 || vAbast > 0 || vManut > 0 || vPneus > 0) {
        veicData.add({
          'id': id, 'nome': nome, 'placa': placa,
          'fuel': vFuelC, 'maint': vMaintC, 'tire': vTireC,
          'total': vTotal, 'kmReal': vKm, 'litros': vFuelL,
          'consumoReal': vConsumo, 'custoPorKm': vCustKm,
          'abast': vAbast, 'manut': vManut, 'pneus': vPneus,
          'faturamento': vFat, 'lucro': vLucro,
        });
        veicHist[id] = hist;
      }

      totalFuelLitros     += vFuelL;
      totalFuelCusto      += vFuelC;
      totalMaintCusto     += vMaintC;
      totalTireCusto      += vTireC;
      totalTireQtd        += vTireQ;
      totalKmReal         += vKm;
      totalAbastecimentos += vAbast;
      totalManutencoes    += vManut;
      totalPneus          += vPneus;
      totalFaturamento    += vFat;
    }

    veicData.sort((a, b) =>
        _toDouble(b['total']).compareTo(_toDouble(a['total'])));

    final custoTotal   = totalFuelCusto + totalMaintCusto + totalTireCusto;
    final consumoMedio = (totalFuelLitros > 0 && totalKmReal > 0)
        ? totalKmReal / totalFuelLitros : 0.0;
    final custoPorKm   = (totalKmReal > 0) ? custoTotal / totalKmReal : 0.0;
    final resultadoLiq = totalFaturamento - custoTotal;
    final margemPct    = (totalFaturamento > 0)
        ? (resultadoLiq / totalFaturamento) * 100 : 0.0;
    final rankConsumo  = veicData
        .where((v) => _toDouble(v['consumoReal']) > 0).toList()
      ..sort((a, b) =>
          _toDouble(b['consumoReal']).compareTo(_toDouble(a['consumoReal'])));

    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/icon.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    final pdf         = pw.Document();
    final mesNome     = _nomeMes(mes);
    final dataGeracao = DateTime.now();

    // ========================================================
    // PÁGINA 1
    // ========================================================
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => [
        _buildCapa(empresaNome, mesNome, ano, dataGeracao, logo),
        pw.SizedBox(height: 22),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSumarioExecutivo(
                empresaNome, mesNome, ano, veicData.length,
                custoTotal, totalFaturamento, resultadoLiq, margemPct,
                consumoMedio, totalKmReal, totalFuelLitros,
                totalAbastecimentos, viagensComNota),
              pw.SizedBox(height: 20),
              _buildKpis(custoTotal, totalKmReal, totalFuelLitros,
                  consumoMedio, custoPorKm, totalManutencoes,
                  veicData.length, totalAbastecimentos),
              pw.SizedBox(height: 20),
              if (viagensComNota > 0) ...[
                _sectionTitle('RESULTADO FINANCEIRO',
                    'Demonstrativo de receitas e despesas operacionais'),
                pw.SizedBox(height: 10),
                _buildResultadoFinanceiro(totalFaturamento, custoTotal,
                    resultadoLiq, margemPct, viagensComNota),
                pw.SizedBox(height: 20),
              ],
              _sectionTitle('DESEMPENHO OPERACIONAL POR VEICULO',
                  'Custo total e participacao percentual no periodo'),
              pw.SizedBox(height: 10),
              _buildBarChart(veicData, custoTotal),
              pw.SizedBox(height: 20),
              _sectionTitle('ESTRUTURA DE CUSTOS',
                  'Distribuicao e proporcao das despesas operacionais'),
              pw.SizedBox(height: 10),
              _buildComposicao(totalFuelCusto, totalMaintCusto,
                  totalTireCusto, custoTotal, totalAbastecimentos,
                  totalManutencoes, totalPneus, totalTireQtd,
                  totalFuelLitros),
              pw.SizedBox(height: 20),
            ],
          ),
        ),
        _buildFooter(empresaNome, dataGeracao, 1, mesNome, ano),
      ],
    ));

    // ========================================================
    // PÁGINA 2
    // ========================================================
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => [
        _buildHeader(empresaNome, mesNome, ano),
        pw.SizedBox(height: 20),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (rankConsumo.isNotEmpty) ...[
                _sectionTitle('RANKING DE EFICIENCIA ENERGETICA',
                    'Classificacao por consumo de combustivel (km/L)'),
                pw.SizedBox(height: 10),
                _buildRanking(rankConsumo, consumoMedio),
                pw.SizedBox(height: 20),
              ],
              _sectionTitle('ANALISE INDIVIDUAL POR VEICULO',
                  'Indicadores completos de desempenho no periodo'),
              pw.SizedBox(height: 10),
              if (veicData.isNotEmpty)
                _buildTabela(veicData)
              else
                _buildVazio(mesNome, ano),
              pw.SizedBox(height: 20),
              if (veicData.isNotEmpty) ...[
                _sectionTitle('HISTORICO DE ABASTECIMENTOS',
                    'Registro detalhado de cada operacao no periodo'),
                pw.SizedBox(height: 10),
                ...veicData.map((v) {
                  final id   = v['id'].toString();
                  final hist = veicHist[id] ?? [];
                  final hMes = hist
                      .where((h) => h['isMesAtual'] == true)
                      .toList()
                    ..sort((a, b) => a['date']
                        .toString()
                        .compareTo(b['date'].toString()));
                  if (hMes.isEmpty) return pw.SizedBox();
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildHistoricoVeiculo(v, hMes),
                      pw.SizedBox(height: 12),
                    ],
                  );
                }),
              ],
              if (veicData.isNotEmpty && consumoMedio > 0) ...[
                pw.SizedBox(height: 4),
                _buildAlertas(veicData, consumoMedio),
                pw.SizedBox(height: 16),
              ],
            ],
          ),
        ),
        _buildFooter(empresaNome, dataGeracao, 2, mesNome, ano),
      ],
    ));

    // ========================================================
    // PÁGINA 3
    // ========================================================
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => [
        _buildHeader(empresaNome, mesNome, ano),
        pw.SizedBox(height: 20),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildAnaliseRecomendacoes(
                veicData, custoTotal, consumoMedio, custoPorKm,
                totalFaturamento, resultadoLiq, margemPct,
                viagensComNota, totalManutencoes, mesNome, ano),
              pw.SizedBox(height: 20),
              _buildMatrizPerformance(veicData, consumoMedio),
              pw.SizedBox(height: 20),
              _buildDeclaracao(empresaNome, dataGeracao),
            ],
          ),
        ),
        _buildFooter(empresaNome, dataGeracao, 3, mesNome, ano),
      ],
    ));

    return pdf.save();
  }

  // ========================================================
  // WIDGETS
  // ========================================================

  static pw.Widget _buildCapa(String empresa, String mesNome, int ano,
      DateTime dataGeracao, pw.MemoryImage? logo) {
    return pw.Container(
      width: double.infinity,
      height: 220,
      child: pw.Stack(children: [
        pw.Container(width: double.infinity, height: 220, color: _navyDark),
        pw.Positioned(right: 0, top: 0,
            child: pw.Container(width: 200, height: 220, color: _navy)),
        pw.Positioned(right: 0, top: 0,
            child: pw.Container(width: 100, height: 220, color: _navyMid)),
        pw.Positioned(left: 110, top: 0,
            child: pw.Container(width: 3, height: 220, color: _gold)),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) ...[
                pw.Container(
                  width: 56, height: 56,
                  decoration: pw.BoxDecoration(
                    color: _white,
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: _gold, width: 2)),
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Image(logo, fit: pw.BoxFit.contain))),
                pw.SizedBox(width: 24),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('RELATORIO EXECUTIVO DE GESTAO DE FROTA',
                      style: pw.TextStyle(color: _goldLight, fontSize: 9,
                          fontWeight: pw.FontWeight.bold, letterSpacing: 2.0)),
                    pw.SizedBox(height: 8),
                    pw.Text(empresa.toUpperCase(),
                      style: pw.TextStyle(color: _white, fontSize: 22,
                          fontWeight: pw.FontWeight.bold, letterSpacing: 1.0)),
                    pw.SizedBox(height: 6),
                    pw.Container(height: 1, width: 200, color: _gold),
                    pw.SizedBox(height: 10),
                    pw.Text('$mesNome DE $ano',
                      style: pw.TextStyle(color: _goldLight, fontSize: 16,
                          fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
                    pw.SizedBox(height: 14),
                    pw.Row(children: [
                      _badgeCapa('CONFIDENCIAL'),
                      pw.SizedBox(width: 8),
                      _badgeCapa('USO INTERNO'),
                    ]),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Emitido em: ${dataGeracao.day.toString().padLeft(2, '0')}/'
                      '${dataGeracao.month.toString().padLeft(2, '0')}/'
                      '${dataGeracao.year}  '
                      '${dataGeracao.hour.toString().padLeft(2, '0')}:'
                      '${dataGeracao.minute.toString().padLeft(2, '0')}',
                      style: const pw.TextStyle(color: _gray400, fontSize: 8)),
                  ])),
            ])),
      ]));
  }

  static pw.Widget _badgeCapa(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _gold, width: 1),
        borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Text(text, style: pw.TextStyle(
          color: _gold, fontSize: 7, fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.2)));
  }

  static pw.Widget _buildHeader(String empresa, String mesNome, int ano) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: const pw.BoxDecoration(
        color: _navyDark,
        border: pw.Border(bottom: pw.BorderSide(color: _gold, width: 2))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(children: [
            pw.Container(width: 3, height: 16, color: _gold,
                margin: const pw.EdgeInsets.only(right: 8)),
            pw.Text(empresa.toUpperCase(),
              style: pw.TextStyle(color: _white, fontSize: 9,
                  fontWeight: pw.FontWeight.bold, letterSpacing: 1.0)),
          ]),
          pw.Text('RELATORIO EXECUTIVO DE FROTA  |  $mesNome / $ano',
            style: const pw.TextStyle(color: _gray400, fontSize: 8)),
        ]));
  }

  static pw.Widget _sectionTitle(String title, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(children: [
          pw.Container(width: 4, height: 16, color: _gold,
              margin: const pw.EdgeInsets.only(right: 10)),
          pw.Text(title, style: pw.TextStyle(color: _navyDark, fontSize: 10,
              fontWeight: pw.FontWeight.bold, letterSpacing: 0.6)),
        ]),
        pw.SizedBox(height: 2),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 14),
          child: pw.Text(subtitle,
            style: const pw.TextStyle(color: _gray500, fontSize: 7.5))),
        pw.SizedBox(height: 6),
        pw.Container(height: 0.5, color: _divider),
      ]);
  }

  static pw.Widget _buildSumarioExecutivo(
    String empresa, String mes, int ano, int veiculos,
    double custo, double fat, double resultado, double margem,
    double consumo, double km, double litros, int abast, int viagens) {

    final isLucro = resultado >= 0;
    final analise = _gerarAnaliseTextual(
        custo, fat, resultado, margem, consumo, km, veiculos, abast, isLucro);

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _gold, width: 1)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Container(width: 3, height: 14, color: _goldLight,
                margin: const pw.EdgeInsets.only(right: 8)),
            pw.Text('SUMARIO EXECUTIVO',
              style: pw.TextStyle(color: _goldLight, fontSize: 9,
                  fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
            pw.Spacer(),
            pw.Text('$mes / $ano',
              style: const pw.TextStyle(color: _gray400, fontSize: 8)),
          ]),
          pw.SizedBox(height: 10),
          pw.Container(height: 0.5, color: _navyLight),
          pw.SizedBox(height: 10),
          pw.Text(analise,
            style: pw.TextStyle(color: _gray200, fontSize: 8.5,
                lineSpacing: 2.0, fontWeight: pw.FontWeight.normal)),
        ]));
  }

  static String _gerarAnaliseTextual(
    double custo, double fat, double resultado, double margem,
    double consumo, double km, int veiculos, int abast, bool isLucro) {

    final lucroStr = isLucro
        ? 'resultado positivo de ${_money(resultado)} (margem ${_fmt2(margem)}%)'
        : 'resultado negativo de ${_money(resultado.abs())} (margem ${_fmt2(margem.abs())}%)';

    final eficiencia = consumo > 3.0
        ? 'acima do benchmark setorial'
        : consumo > 2.0
            ? 'dentro dos parametros operacionais'
            : 'abaixo do parametro ideal, requerendo atencao';

    final fatStr = fat > 0
        ? 'O faturamento bruto do periodo atingiu ${_money(fat)}, com $lucroStr. '
        : '';

    return 'No periodo de referencia, a frota de $veiculos '
        'veiculo(s) ativo(s) realizou $abast abastecimento(s), '
        'percorrendo ${_fmtInt(km)} km com consumo medio de '
        '${_fmt2(consumo)} km/L, $eficiencia. '
        'O custo operacional total apurado foi de ${_money(custo)}. '
        '${fatStr}'
        'Os indicadores consolidados neste relatorio subsidiam a '
        'tomada de decisao da diretoria quanto a otimizacao da frota, '
        'renegociacao de contratos de manutencao e definicao de '
        'metas operacionais para o proximo periodo.';
  }

  static pw.Widget _buildKpis(
    double custo, double km, double litros, double consumo,
    double custoPorKm, int manut, int veiculos, int abast) {
    return pw.Column(children: [
      pw.Row(children: [
        pw.Expanded(child: _kpiBox('CUSTO OPERACIONAL TOTAL',
            _money(custo), 'Combustivel + Manutencao + Pneus',
            _navyDark, _goldLight, _gray300)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: _kpiBox('DISTANCIA PERCORRIDA',
            '${_fmtInt(km)} km', '$veiculos veiculos ativos no periodo',
            _navyMid, _white, _gray300)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: _kpiBox('COMBUSTIVEL CONSUMIDO',
            '${_fmt2(litros)} L', '$abast abastecimentos realizados',
            _navy, _white, _gray300)),
      ]),
      pw.SizedBox(height: 8),
      pw.Row(children: [
        pw.Expanded(child: _kpiBox('EFICIENCIA MEDIA DA FROTA',
            consumo > 0 ? '${_fmt2(consumo)} km/L' : '-',
            'Media ponderada de todos os veiculos',
            _gold, _navyDark, _navyDark, labelDark: true)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: _kpiBox('CUSTO MEDIO POR KM',
            custoPorKm > 0 ? _money(custoPorKm) : '-',
            'Custo total / distancia percorrida',
            _navyAccent, _goldLight, _gray300)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: _kpiBox('EVENTOS DE MANUTENCAO',
            '$manut', 'Registros no periodo',
            _navyDark, _white, _gray300)),
      ]),
    ]);
  }

  static pw.Widget _kpiBox(String label, String value, String caption,
      PdfColor bg, PdfColor valColor, PdfColor capColor,
      {bool labelDark = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: pw.BoxDecoration(
        color: bg, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(
              color: labelDark ? _navyDark : _goldLight,
              fontSize: 7, fontWeight: pw.FontWeight.bold, letterSpacing: 0.6)),
          pw.SizedBox(height: 5),
          pw.Text(value, style: pw.TextStyle(
              color: valColor, fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Text(caption, style: pw.TextStyle(color: capColor, fontSize: 6.5)),
        ]));
  }

  static pw.Widget _buildResultadoFinanceiro(
    double fat, double custo, double resultado, double margem, int viagens) {
    final isLucro = resultado >= 0;
    final pct     = fat > 0 ? (custo / fat) * 100 : 0.0;
    final barW    = 480.0 * min(1.0, fat > 0 ? custo / fat : 0);

    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: isLucro ? _gold : _redMid, width: 1.5)),
      child: pw.Column(children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const pw.BoxDecoration(
            color: _navyDark,
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(7),
              topRight: pw.Radius.circular(7))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('DEMONSTRATIVO DE RESULTADO OPERACIONAL',
                style: pw.TextStyle(color: _goldLight, fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: isLucro ? _greenProfit : _redLoss,
                  borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text(isLucro ? 'SUPERAVIT' : 'DEFICIT',
                  style: pw.TextStyle(color: _white, fontSize: 7,
                      fontWeight: pw.FontWeight.bold))),
            ])),
        pw.Padding(
          padding: const pw.EdgeInsets.all(14),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _gray100, borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: _gray300)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('RECEITA BRUTA', style: pw.TextStyle(
                      color: _gray600, fontSize: 7,
                      fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(_money(fat), style: pw.TextStyle(
                      color: _navyDark, fontSize: 15,
                      fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('$viagens viagem(ns)',
                    style: const pw.TextStyle(color: _gray500, fontSize: 7)),
                ]))),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _gray100, borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: _gray300)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('(-) DESPESAS OPERACIONAIS', style: pw.TextStyle(
                      color: _gray600, fontSize: 7,
                      fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(_money(custo), style: pw.TextStyle(
                      color: _redMid, fontSize: 15,
                      fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('${_fmt2(pct)}% da receita',
                    style: const pw.TextStyle(color: _gray500, fontSize: 7)),
                ]))),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: isLucro ? _greenLight : _redLight,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(
                    color: isLucro ? _greenMid : _redMid, width: 1.5)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isLucro ? 'RESULTADO LIQUIDO' : 'PREJUIZO APURADO',
                    style: pw.TextStyle(
                        color: isLucro ? _greenProfit : _redLoss,
                        fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(_money(resultado.abs()), style: pw.TextStyle(
                      color: isLucro ? _greenProfit : _redLoss,
                      fontSize: 15, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('Margem: ${_fmt2(margem)}%', style: pw.TextStyle(
                      color: isLucro ? _greenProfit : _redLoss,
                      fontSize: 7, fontWeight: pw.FontWeight.bold)),
                ]))),
          ])),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Proporcao de despesas sobre receita',
                    style: const pw.TextStyle(color: _gray500, fontSize: 7)),
                  pw.Text('${_fmt2(pct)}% em despesas',
                    style: pw.TextStyle(
                        color: isLucro ? _greenProfit : _redMid,
                        fontSize: 7, fontWeight: pw.FontWeight.bold)),
                ]),
              pw.SizedBox(height: 4),
              pw.Stack(children: [
                pw.Container(height: 7,
                  decoration: pw.BoxDecoration(color: _gray200,
                      borderRadius: pw.BorderRadius.circular(4))),
                pw.Container(height: 7, width: barW,
                  decoration: pw.BoxDecoration(
                    color: isLucro ? _greenMid : _redMid,
                    borderRadius: pw.BorderRadius.circular(4))),
              ]),
            ])),
      ]));
  }

  static pw.Widget _buildBarChart(
      List<Map<String, dynamic>> veicData, double custoTotal) {
    final top  = veicData.take(10).toList();
    if (top.isEmpty) return pw.SizedBox();
    final maxV = top.map((v) => _toDouble(v['total'])).reduce(max);
    const bW   = 270.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _gray50, borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _gray200)),
      child: pw.Column(children: [
        ...top.asMap().entries.map((e) {
          final i   = e.key;
          final v   = e.value;
          final tot = _toDouble(v['total']);
          final fu  = _toDouble(v['fuel']);
          final ma  = _toDouble(v['maint']);
          final ti  = _toDouble(v['tire']);
          final pct = custoTotal > 0 ? (tot / custoTotal) * 100 : 0.0;
          final fW  = maxV > 0 ? (fu / maxV) * bW : 0.0;
          final mW  = maxV > 0 ? (ma / maxV) * bW : 0.0;
          final tW  = maxV > 0 ? (ti / maxV) * bW : 0.0;
          final med = i == 0 ? _gold
              : (i == 1 ? _gray400 : (i == 2 ? _amberMid : _gray200));

          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(width: 20, height: 20,
                  decoration: pw.BoxDecoration(
                    color: med, shape: pw.BoxShape.circle),
                  child: pw.Center(child: pw.Text('${i + 1}',
                    style: pw.TextStyle(
                        color: i < 3 ? _white : _gray600,
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold)))),
                pw.SizedBox(width: 8),
                pw.SizedBox(width: 115,
                  child: pw.Text(v['nome'].toString(),
                    style: pw.TextStyle(color: _navyDark, fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold),
                    maxLines: 2)),
                pw.SizedBox(width: 6),
                pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Stack(children: [
                      pw.Container(height: 12,
                        decoration: pw.BoxDecoration(color: _gray200,
                            borderRadius: pw.BorderRadius.circular(3))),
                      pw.Container(width: fW, height: 12,
                        decoration: pw.BoxDecoration(color: _navyMid,
                            borderRadius: pw.BorderRadius.circular(3))),
                      if (mW > 0) pw.Positioned(left: fW,
                        child: pw.Container(
                            width: mW, height: 12, color: _amberMid)),
                      if (tW > 0) pw.Positioned(left: fW + mW,
                        child: pw.Container(
                            width: tW, height: 12, color: _redMid)),
                    ]),
                    pw.SizedBox(height: 2),
                    pw.Text('${_money(tot)}   ${_fmt2(pct)}% do total',
                      style: const pw.TextStyle(
                          color: _gray500, fontSize: 6.5)),
                  ])),
              ]));
        }),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(children: [
            pw.SizedBox(width: 149),
            _dot(_navyMid, 'Combustivel'),
            pw.SizedBox(width: 10),
            _dot(_amberMid, 'Manutencao'),
            pw.SizedBox(width: 10),
            _dot(_redMid, 'Pneus'),
          ])),
      ]));
  }

  static pw.Widget _dot(PdfColor c, String label) =>
    pw.Row(children: [
      pw.Container(width: 8, height: 8,
          decoration: pw.BoxDecoration(
              color: c, shape: pw.BoxShape.circle)),
      pw.SizedBox(width: 3),
      pw.Text(label,
          style: const pw.TextStyle(color: _gray600, fontSize: 7)),
    ]);

  static pw.Widget _buildComposicao(
    double fuel, double maint, double tire, double total,
    int abast, int manut, int pneus, int tireQtd, double litros) {
    final fp = total > 0 ? (fuel  / total) * 100 : 0.0;
    final mp = total > 0 ? (maint / total) * 100 : 0.0;
    final tp = total > 0 ? (tire  / total) * 100 : 0.0;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(flex: 3, child: pw.Column(children: [
          _composItem('COMBUSTIVEL E LUBRIFICANTES', fuel, fp, _navyMid,
              '$abast abastecimentos  /  ${_fmt2(litros)} L consumidos'),
          pw.SizedBox(height: 8),
          _composItem('MANUTENCAO E REPAROS', maint, mp, _amberMid,
              '$manut servico(s) realizado(s) no periodo'),
          pw.SizedBox(height: 8),
          _composItem('PNEUS E BORRACHARIA', tire, tp, _redMid,
              '$pneus troca(s)  /  $tireQtd unidade(s) substituida(s)'),
        ])),
        pw.SizedBox(width: 12),
        pw.Expanded(flex: 2, child: pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: _navyDark,
            borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('CUSTO TOTAL', style: pw.TextStyle(
                  color: _goldLight, fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold, letterSpacing: 1.0)),
              pw.SizedBox(height: 6),
              pw.Text(_money(total), style: pw.TextStyle(
                  color: _white, fontSize: 16,
                  fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Container(height: 0.5, color: _navyLight),
              pw.SizedBox(height: 10),
              _miniRow('Combustivel', '${_fmt2(fp)}%', _goldLight),
              pw.SizedBox(height: 5),
              _miniRow('Manutencao', '${_fmt2(mp)}%', _amberMid),
              pw.SizedBox(height: 5),
              _miniRow('Pneus', '${_fmt2(tp)}%', _redMid),
              pw.SizedBox(height: 10),
              pw.Container(height: 0.5, color: _navyLight),
              pw.SizedBox(height: 10),
              pw.Text('DISTRIBUICAO', style: pw.TextStyle(
                  color: _gray400, fontSize: 6.5, letterSpacing: 0.8)),
              pw.SizedBox(height: 6),
              pw.Container(
                height: 12,
                child: pw.Row(children: [
                  if (fp > 0) pw.Expanded(
                    flex: fp.round(),
                    child: pw.Container(
                      decoration: pw.BoxDecoration(color: _navyLight,
                        borderRadius: const pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(3),
                          bottomLeft: pw.Radius.circular(3))))),
                  if (mp > 0) pw.Expanded(
                    flex: mp.round(),
                    child: pw.Container(color: _amberMid)),
                  if (tp > 0) pw.Expanded(
                    flex: tp.round(),
                    child: pw.Container(
                      decoration: pw.BoxDecoration(color: _redMid,
                        borderRadius: const pw.BorderRadius.only(
                          topRight: pw.Radius.circular(3),
                          bottomRight: pw.Radius.circular(3))))),
                ])),
            ]))),
      ]);
  }

  static pw.Widget _composItem(String titulo, double valor, double pct,
      PdfColor cor, String desc) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _white, borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _gray200),
        boxShadow: [pw.BoxShadow(color: _gray200, blurRadius: 2)]),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(children: [
                pw.Container(width: 10, height: 10,
                  decoration: pw.BoxDecoration(
                      color: cor, shape: pw.BoxShape.circle)),
                pw.SizedBox(width: 6),
                pw.Text(titulo, style: pw.TextStyle(color: _navyDark,
                    fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(_money(valor), style: pw.TextStyle(
                      color: _navyDark, fontSize: 11,
                      fontWeight: pw.FontWeight.bold)),
                  pw.Text('${_fmt2(pct)}% do total', style: pw.TextStyle(
                      color: cor, fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold)),
                ]),
            ]),
          pw.SizedBox(height: 6),
          pw.Stack(children: [
            pw.Container(height: 5,
              decoration: pw.BoxDecoration(color: _gray200,
                  borderRadius: pw.BorderRadius.circular(3))),
            pw.Container(height: 5, width: 280 * (pct / 100),
              decoration: pw.BoxDecoration(color: cor,
                  borderRadius: pw.BorderRadius.circular(3))),
          ]),
          pw.SizedBox(height: 5),
          pw.Text(desc,
            style: const pw.TextStyle(color: _gray500, fontSize: 7)),
        ]));
  }

  static pw.Widget _miniRow(String label, String value, PdfColor cor) =>
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Row(children: [
        pw.Container(width: 6, height: 6,
          decoration: pw.BoxDecoration(
              color: cor, shape: pw.BoxShape.circle)),
        pw.SizedBox(width: 4),
        pw.Text(label,
          style: const pw.TextStyle(color: _gray300, fontSize: 7)),
      ]),
      pw.Text(value, style: pw.TextStyle(color: cor, fontSize: 7.5,
          fontWeight: pw.FontWeight.bold)),
    ]);

  static pw.Widget _buildRanking(
      List<Map<String, dynamic>> rank, double media) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _gray200)),
      child: pw.Column(children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: const pw.BoxDecoration(
            color: _navyDark,
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(7),
              topRight: pw.Radius.circular(7))),
          child: pw.Row(children: [
            pw.Expanded(flex: 1, child: pw.Text('#', style: pw.TextStyle(
                color: _goldLight, fontSize: 7.5,
                fontWeight: pw.FontWeight.bold))),
            pw.Expanded(flex: 5, child: pw.Text('VEICULO', style: pw.TextStyle(
                color: _goldLight, fontSize: 7.5,
                fontWeight: pw.FontWeight.bold))),
            pw.Expanded(flex: 2, child: pw.Text('km/L',
                textAlign: pw.TextAlign.right, style: pw.TextStyle(
                    color: _goldLight, fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold))),
            pw.Expanded(flex: 2, child: pw.Text('vs Media',
                textAlign: pw.TextAlign.right, style: pw.TextStyle(
                    color: _goldLight, fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold))),
            pw.Expanded(flex: 2, child: pw.Text('Status',
                textAlign: pw.TextAlign.right, style: pw.TextStyle(
                    color: _goldLight, fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold))),
            pw.Expanded(flex: 3, child: pw.Text('Indice',
                textAlign: pw.TextAlign.right, style: pw.TextStyle(
                    color: _goldLight, fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold))),
          ])),
        ...rank.asMap().entries.map((e) {
          final i       = e.key;
          final v       = e.value;
          final consumo = _toDouble(v['consumoReal']);
          final diff    = consumo - media;
          final isAcima = diff >= 0;
          final pctD    = media > 0 ? (diff / media) * 100 : 0.0;
          final status  = consumo >= media * 1.1 ? 'OTIMO'
              : consumo >= media * 0.9 ? 'REGULAR' : 'CRITICO';
          final sCor    = status == 'OTIMO'    ? _greenProfit
              : status == 'REGULAR' ? _amber : _redLoss;
          final sBg     = status == 'OTIMO'    ? _greenLight
              : status == 'REGULAR' ? _amberLight : _redLight;

          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: pw.BoxDecoration(
              color: i % 2 == 0 ? _white : _gray50,
              border: pw.Border(
                bottom: pw.BorderSide(color: _gray200),
                left:   pw.BorderSide(color: _gray200),
                right:  pw.BorderSide(color: _gray200))),
            child: pw.Row(children: [
              pw.Expanded(flex: 1, child: pw.Container(
                width: 18, height: 18,
                decoration: pw.BoxDecoration(
                  color: i == 0 ? _gold
                      : (i == 1 ? _gray400
                          : (i == 2 ? _amberMid : _gray200)),
                  shape: pw.BoxShape.circle),
                child: pw.Center(child: pw.Text('${i + 1}',
                  style: pw.TextStyle(
                      color: i < 3 ? _white : _gray600,
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold))))),
              pw.Expanded(flex: 5, child: pw.Text(v['nome'].toString(),
                style: pw.TextStyle(color: _navyDark, fontSize: 8,
                    fontWeight: pw.FontWeight.bold),
                maxLines: 2)),
              pw.Expanded(flex: 2, child: pw.Text(_fmt2(consumo),
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(color: _navyDark, fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 2, child: pw.Text(
                '${isAcima ? '+' : ''}${_fmt2(pctD)}%',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    color: isAcima ? _greenProfit : _redMid,
                    fontSize: 8, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 2, child: pw.Padding(
                padding: const pw.EdgeInsets.only(left: 4),
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: sBg,
                    borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Text(status,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(color: sCor, fontSize: 6.5,
                        fontWeight: pw.FontWeight.bold))))),
              pw.Expanded(flex: 3, child: pw.Padding(
                padding: const pw.EdgeInsets.only(left: 8),
                child: pw.Stack(children: [
                  pw.Container(height: 7,
                    decoration: pw.BoxDecoration(color: _gray200,
                        borderRadius: pw.BorderRadius.circular(4))),
                  pw.Container(height: 7,
                    width: 50 * min(1.0,
                        media > 0 ? consumo / (media * 1.5) : 0),
                    decoration: pw.BoxDecoration(
                      color: isAcima ? _greenMid : _redMid,
                      borderRadius: pw.BorderRadius.circular(4))),
                ]))),
            ]));
        }),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 14, vertical: 9),
          decoration: pw.BoxDecoration(
            color: _goldPale,
            border: pw.Border.all(color: _gold),
            borderRadius: const pw.BorderRadius.only(
              bottomLeft: pw.Radius.circular(7),
              bottomRight: pw.Radius.circular(7))),
          child: pw.Row(children: [
            pw.Expanded(flex: 8, child: pw.Text('MEDIA GERAL DA FROTA',
              style: pw.TextStyle(color: _navyDark, fontSize: 8,
                  fontWeight: pw.FontWeight.bold))),
            pw.Expanded(flex: 4, child: pw.Text(
              media > 0 ? '${_fmt2(media)} km/L' : '-',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(color: _navyDark, fontSize: 10,
                  fontWeight: pw.FontWeight.bold))),
            pw.Expanded(flex: 5, child: pw.SizedBox()),
          ])),
      ]));
  }

  static pw.Widget _buildTabela(List<Map<String, dynamic>> veicData) {
    return pw.Table(
      border: pw.TableBorder.all(color: _gray200, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2),
        5: const pw.FlexColumnWidth(2.5),
        6: const pw.FlexColumnWidth(2.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _navyDark),
          children: [
            _th('VEICULO'),
            _th('KM',        align: pw.TextAlign.right),
            _th('km/L',      align: pw.TextAlign.right),
            _th('R\$/km',    align: pw.TextAlign.right),
            _th('LITROS',    align: pw.TextAlign.right),
            _th('CUSTO',     align: pw.TextAlign.right),
            _th('RESULTADO', align: pw.TextAlign.right),
          ]),
        ...veicData.asMap().entries.map((e) {
          final i       = e.key;
          final v       = e.value;
          final consumo = _toDouble(v['consumoReal']);
          final custKm  = _toDouble(v['custoPorKm']);
          final lucro   = _toDouble(v['lucro']);
          final fat     = _toDouble(v['faturamento']);
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: i % 2 == 0 ? _white : _gray50),
            children: [
              _td(v['nome'].toString(), bold: true),
              _td(_fmtInt(_toDouble(v['kmReal'])),
                  align: pw.TextAlign.right),
              _td(consumo > 0 ? _fmt2(consumo) : '-',
                  align: pw.TextAlign.right),
              _td(custKm  > 0 ? _money(custKm) : '-',
                  align: pw.TextAlign.right),
              _td(_fmt2(_toDouble(v['litros'])),
                  align: pw.TextAlign.right),
              _td(_money(_toDouble(v['total'])), bold: true,
                  align: pw.TextAlign.right),
              _td(fat > 0 ? _money(lucro) : '-', bold: true,
                align: pw.TextAlign.right,
                color: fat > 0
                    ? (lucro >= 0 ? _greenProfit : _redMid)
                    : _gray500),
            ]);
        }),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _navyDark),
          children: [
            _th('TOTAL'),
            _th(_fmtInt(veicData.fold(
                0.0, (s, v) => s + _toDouble(v['kmReal']))),
                align: pw.TextAlign.right),
            _th('-', align: pw.TextAlign.right),
            _th('-', align: pw.TextAlign.right),
            _th(_fmt2(veicData.fold(
                0.0, (s, v) => s + _toDouble(v['litros']))),
                align: pw.TextAlign.right),
            _th(_money(veicData.fold(
                0.0, (s, v) => s + _toDouble(v['total']))),
                align: pw.TextAlign.right),
            _th('-', align: pw.TextAlign.right),
          ]),
      ]);
  }

  static pw.Widget _buildHistoricoVeiculo(
      Map<String, dynamic> veiculo,
      List<Map<String, dynamic>> hist) {
    if (hist.isEmpty) return pw.SizedBox();
    final validos   = hist.where((h) => _toDouble(h['consumo']) > 0).toList();
    final mediaVeic = validos.isEmpty
        ? 0.0
        : validos
                .map((h) => _toDouble(h['consumo']))
                .reduce((a, b) => a + b) /
            validos.length;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _gray200),
        borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: const pw.BoxDecoration(
              color: _navyMid,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(7),
                topRight: pw.Radius.circular(7))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(veiculo['nome'].toString(),
                  style: pw.TextStyle(color: _goldLight, fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  'Media: ${mediaVeic > 0 ? _fmt2(mediaVeic) + ' km/L' : '-'}'
                  '   ${hist.length} abastecimento(s)'
                  '   Total: ${_money(hist.fold(0.0, (s, h) => s + _toDouble(h['custo'])))}',
                  style: const pw.TextStyle(
                      color: _gray300, fontSize: 7.5)),
              ])),
          pw.Table(
            border: pw.TableBorder(
              horizontalInside:
                  pw.BorderSide(color: _gray200, width: 0.5),
              bottom: pw.BorderSide(color: _gray200, width: 0.5),
              left:   pw.BorderSide(color: _gray200, width: 0.5),
              right:  pw.BorderSide(color: _gray200, width: 0.5)),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _gray100),
                children: [
                  _thSm('DATA'),
                  _thSm('MOTORISTA'),
                  _thSm('LITROS', align: pw.TextAlign.right),
                  _thSm('KM',     align: pw.TextAlign.right),
                  _thSm('km/L',   align: pw.TextAlign.right),
                  _thSm('CUSTO',  align: pw.TextAlign.right),
                ]),
              ...hist.map((h) {
                DateTime? d;
                try {
                  d = DateTime.parse(h['date']?.toString() ?? '');
                } catch (_) {}
                final dataStr = d != null
                    ? '${d.day.toString().padLeft(2, '0')}/'
                      '${d.month.toString().padLeft(2, '0')}'
                    : '-';
                final consumo  = _toDouble(h['consumo']);
                final isAbaixo = mediaVeic > 0 &&
                    consumo > 0 &&
                    consumo < mediaVeic * 0.85;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isAbaixo ? _amberLight : _white),
                  children: [
                    _tdSm(dataStr),
                    _tdSm(h['motorista']?.toString() ?? '-'),
                    _tdSm(_fmt2(_toDouble(h['litros'])),
                        align: pw.TextAlign.right),
                    _tdSm(_fmtInt(_toDouble(h['km'])),
                        align: pw.TextAlign.right),
                    _tdSm(consumo > 0 ? _fmt2(consumo) : '-',
                      align: pw.TextAlign.right,
                      color: isAbaixo ? _amber : _gray700,
                      bold: isAbaixo),
                    _tdSm(_money(_toDouble(h['custo'])),
                        align: pw.TextAlign.right),
                  ]);
              }),
            ]),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: pw.Row(children: [
              pw.Text('Media do veiculo: ',
                style: const pw.TextStyle(
                    color: _gray600, fontSize: 7)),
              pw.Text(
                mediaVeic > 0 ? '${_fmt2(mediaVeic)} km/L' : '-',
                style: pw.TextStyle(color: _navyDark, fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold)),
              pw.Spacer(),
              pw.Text(
                'Fundo amarelo = consumo abaixo da media do veiculo',
                style: const pw.TextStyle(
                    color: _gray400, fontSize: 6.5)),
            ])),
        ]));
  }

  static pw.Widget _buildAlertas(
      List<Map<String, dynamic>> veicData, double media) {
    final alertas = veicData.where((v) {
      final c = _toDouble(v['consumoReal']);
      return c > 0 && media > 0 && c < media * 0.8;
    }).toList();
    if (alertas.isEmpty) return pw.SizedBox();

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _amberLight,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _amberMid, width: 1.5)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Container(width: 12, height: 12,
              decoration: pw.BoxDecoration(
                  color: _amberMid, shape: pw.BoxShape.circle)),
            pw.SizedBox(width: 6),
            pw.Text('ALERTAS DE EFICIENCIA CRITICA',
              style: pw.TextStyle(color: _amber, fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
          ]),
          pw.SizedBox(height: 7),
          pw.Text(
            'Os veiculos listados abaixo apresentaram consumo mais '
            'de 20% abaixo da media geral (${_fmt2(media)} km/L). '
            'Recomenda-se revisao tecnica preventiva urgente.',
            style: const pw.TextStyle(color: _gray700, fontSize: 7.5)),
          pw.SizedBox(height: 8),
          ...alertas.map((v) {
            final c    = _toDouble(v['consumoReal']);
            final diff = ((c - media) / media) * 100;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(children: [
                pw.Container(width: 5, height: 5,
                  decoration: pw.BoxDecoration(
                      color: _amberMid, shape: pw.BoxShape.circle),
                  margin: const pw.EdgeInsets.only(right: 6, top: 2)),
                pw.Text('${v['nome']}:', style: pw.TextStyle(
                    color: _navyDark, fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(width: 4),
                pw.Text(
                  '${_fmt2(c)} km/L  (${_fmt2(diff)}% vs media)',
                  style: pw.TextStyle(color: _redMid, fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold)),
              ]));
          }),
        ]));
  }

  // ============ PÁGINA 3 ============

  static pw.Widget _buildAnaliseRecomendacoes(
    List<Map<String, dynamic>> veicData,
    double custo, double consumo, double custKm,
    double fat, double resultado, double margem,
    int viagens, int manut, String mes, int ano) {

    final isLucro    = resultado >= 0;
    final efOtimos   = veicData.where((v) {
      final c = _toDouble(v['consumoReal']);
      return c > 0 && c >= consumo * 1.1;
    }).length;
    final efCriticos = veicData.where((v) {
      final c = _toDouble(v['consumoReal']);
      return c > 0 && c < consumo * 0.8;
    }).length;

    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _gray200)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: const pw.BoxDecoration(
              color: _navyDark,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(7),
                topRight: pw.Radius.circular(7))),
            child: pw.Text(
              'ANALISE ESTRATEGICA E RECOMENDACOES GERENCIAIS',
              style: pw.TextStyle(color: _goldLight, fontSize: 9,
                  fontWeight: pw.FontWeight.bold, letterSpacing: 0.8))),
          pw.Padding(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _subTitulo('1. DIAGNOSTICO OPERACIONAL'),
                pw.SizedBox(height: 8),
                pw.Row(children: [
                  pw.Expanded(child: _cardAnalise(
                    'Custo Operacional', _money(custo),
                    custo > 0 ? 'Periodo: $mes / $ano' : 'Sem dados',
                    _navyDark, _goldLight)),
                  pw.SizedBox(width: 8),
                  pw.Expanded(child: _cardAnalise(
                    'Eficiencia Media',
                    consumo > 0 ? '${_fmt2(consumo)} km/L' : '-',
                    consumo >= 3.0
                        ? 'Acima do benchmark'
                        : 'Abaixo do benchmark',
                    consumo >= 3.0 ? _greenProfit : _redLoss,
                    _white)),
                  pw.SizedBox(width: 8),
                  pw.Expanded(child: _cardAnalise(
                    'Veic. em Estado Critico', '$efCriticos',
                    'Abaixo de 80% da media',
                    efCriticos == 0 ? _greenProfit : _redLoss,
                    _white)),
                  pw.SizedBox(width: 8),
                  pw.Expanded(child: _cardAnalise(
                    'Veic. com Desempenho Otimo', '$efOtimos',
                    'Acima de 110% da media',
                    _greenProfit, _white)),
                ]),
                pw.SizedBox(height: 14),
                _subTitulo('2. RECOMENDACOES PRIORITARIAS'),
                pw.SizedBox(height: 8),
                if (efCriticos > 0) ...[
                  _recomendacao('ALTA', 'Manutencao Preventiva Urgente',
                    '$efCriticos veiculo(s) com consumo critico. '
                    'Agendar revisao completa imediatamente para evitar '
                    'agravamento dos custos operacionais.',
                    _redLoss, _redLight),
                  pw.SizedBox(height: 6),
                ],
                _recomendacao('MEDIA', 'Monitoramento de Combustivel',
                  'Implementar controle rigoroso por abastecimento. '
                  'Custo atual de ${custKm > 0 ? _money(custKm) : "-"}/km '
                  'deve ser monitorado mensalmente como KPI primario.',
                  _amber, _amberLight),
                pw.SizedBox(height: 6),
                if (viagens > 0 && !isLucro) ...[
                  _recomendacao('ALTA', 'Revisao de Precificacao',
                    'Margem negativa de ${_fmt2(margem.abs())}% indica que o '
                    'frete praticado nao cobre os custos operacionais. '
                    'Revisar tabela de fretes urgentemente.',
                    _redLoss, _redLight),
                  pw.SizedBox(height: 6),
                ] else if (viagens > 0 && isLucro) ...[
                  _recomendacao('BAIXA', 'Manutencao da Lucratividade',
                    'Margem de ${_fmt2(margem)}% dentro do esperado. '
                    'Manter estrategia atual e monitorar variacao de custos '
                    'de combustivel no mercado.',
                    _greenProfit, _greenLight),
                  pw.SizedBox(height: 6),
                ],
                _recomendacao('MEDIA', 'Padronizacao de Rotas',
                  'Analisar rotas de maior custo/km para identificar '
                  'oportunidades de otimizacao logistica e reducao '
                  'de consumo de combustivel.',
                  _navyMid, _gray100),
              ])),
        ]));
  }

  static pw.Widget _subTitulo(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(children: [
      pw.Container(width: 3, height: 12, color: _gold,
          margin: const pw.EdgeInsets.only(right: 6)),
      pw.Text(text, style: pw.TextStyle(color: _navyDark, fontSize: 8.5,
          fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
    ]));

  static pw.Widget _cardAnalise(String label, String value, String desc,
      PdfColor bg, PdfColor valColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bg, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(
              color: bg == _navyDark ? _goldLight : _gray500,
              fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text(value, style: pw.TextStyle(
              color: valColor, fontSize: 13,
              fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Text(desc, style: pw.TextStyle(
              color: bg == _navyDark ? _gray400 : _gray500,
              fontSize: 6.5)),
        ]));
  }

  static pw.Widget _recomendacao(String prioridade, String titulo,
      String texto, PdfColor corPri, PdfColor bgPri) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bgPri,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: corPri, width: 0.5)),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              color: corPri,
              borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text(prioridade, style: pw.TextStyle(
                color: _white, fontSize: 6.5,
                fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(titulo, style: pw.TextStyle(color: _navyDark,
                  fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text(texto, style: const pw.TextStyle(
                  color: _gray700, fontSize: 7.5)),
            ])),
        ]));
  }

  static pw.Widget _buildMatrizPerformance(
      List<Map<String, dynamic>> veicData, double mediaConsumo) {
    if (veicData.isEmpty) return pw.SizedBox();

    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _gray200)),
      child: pw.Column(children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          decoration: const pw.BoxDecoration(
            color: _navyDark,
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(7),
              topRight: pw.Radius.circular(7))),
          child: pw.Text('MATRIZ DE PERFORMANCE DA FROTA',
            style: pw.TextStyle(color: _goldLight, fontSize: 8.5,
                fontWeight: pw.FontWeight.bold, letterSpacing: 0.8))),
        pw.Padding(
          padding: const pw.EdgeInsets.all(14),
          child: pw.Column(children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: const pw.BoxDecoration(color: _gray100),
              child: pw.Row(children: [
                pw.Expanded(flex: 4, child: pw.Text('VEICULO',
                  style: pw.TextStyle(color: _gray600, fontSize: 7,
                      fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 2, child: pw.Text('CUSTO',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(color: _gray600, fontSize: 7,
                      fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 2, child: pw.Text('km/L',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(color: _gray600, fontSize: 7,
                      fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 2, child: pw.Text('ABAST.',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(color: _gray600, fontSize: 7,
                      fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 3, child: pw.Text('PERFORMANCE',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(color: _gray600, fontSize: 7,
                      fontWeight: pw.FontWeight.bold))),
              ])),
            ...veicData.asMap().entries.map((e) {
              final i       = e.key;
              final v       = e.value;
              final consumo = _toDouble(v['consumoReal']);
              final perf    = mediaConsumo > 0 && consumo > 0
                  ? consumo / mediaConsumo : 0.0;
              final cor     = perf >= 1.1 ? _greenMid
                  : perf >= 0.9 ? _amberMid : _redMid;
              final lbl     = perf >= 1.1 ? 'ACIMA DA MEDIA'
                  : perf >= 0.9 ? 'NA MEDIA' : 'ABAIXO DA MEDIA';

              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: pw.BoxDecoration(
                  color: i % 2 == 0 ? _white : _gray50,
                  border: pw.Border(
                    bottom: pw.BorderSide(color: _gray200),
                    left:   pw.BorderSide(color: _gray200),
                    right:  pw.BorderSide(color: _gray200))),
                child: pw.Row(children: [
                  pw.Expanded(flex: 4, child: pw.Text(
                    v['nome'].toString(),
                    style: pw.TextStyle(color: _navyDark, fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold),
                    maxLines: 1)),
                  pw.Expanded(flex: 2, child: pw.Text(
                    _money(_toDouble(v['total'])),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(color: _navyDark, fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text(
                    consumo > 0 ? _fmt2(consumo) : '-',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        color: _navyDark, fontSize: 7.5))),
                  pw.Expanded(flex: 2, child: pw.Text(
                    '${v['abast']}',
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(
                        color: _gray600, fontSize: 7.5))),
                  pw.Expanded(flex: 3, child: pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 6),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Stack(children: [
                          pw.Container(height: 6,
                            decoration: pw.BoxDecoration(
                                color: _gray200,
                                borderRadius:
                                    pw.BorderRadius.circular(3))),
                          pw.Container(height: 6,
                            width: 60 * min(1.0, perf / 1.5),
                            decoration: pw.BoxDecoration(
                                color: cor,
                                borderRadius:
                                    pw.BorderRadius.circular(3))),
                        ]),
                        pw.SizedBox(height: 2),
                        pw.Text(lbl, style: pw.TextStyle(
                            color: cor, fontSize: 6,
                            fontWeight: pw.FontWeight.bold)),
                      ]))),
                ]));
            }),
          ])),
      ]));
  }

  static pw.Widget _buildDeclaracao(String empresa, DateTime data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _gray50, borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _gray200)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('NOTA DE RESPONSABILIDADE',
            style: pw.TextStyle(color: _navyDark, fontSize: 8,
                fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
          pw.SizedBox(height: 6),
          pw.Text(
            'Este relatorio foi gerado automaticamente pelo sistema '
            'Gestor de Frota com base nos dados inseridos pelos '
            'usuarios autorizados de $empresa. As informacoes '
            'apresentadas refletem os registros do sistema na data '
            'de geracao e destinam-se exclusivamente ao uso interno '
            'da organizacao. Qualquer reproducao ou distribuicao '
            'nao autorizada e vedada.',
            style: const pw.TextStyle(color: _gray600, fontSize: 7.5,
                lineSpacing: 1.5)),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(height: 0.5, color: _gray400),
                pw.SizedBox(height: 4),
                pw.Text('Responsavel pelo Relatorio',
                  style: const pw.TextStyle(
                      color: _gray500, fontSize: 7)),
                pw.Text(empresa, style: pw.TextStyle(
                    color: _navyDark, fontSize: 8,
                    fontWeight: pw.FontWeight.bold)),
              ])),
            pw.SizedBox(width: 40),
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(height: 0.5, color: _gray400),
                pw.SizedBox(height: 4),
                pw.Text('Data de Emissao',
                  style: const pw.TextStyle(
                      color: _gray500, fontSize: 7)),
                pw.Text(
                  '${data.day.toString().padLeft(2, '0')}/'
                  '${data.month.toString().padLeft(2, '0')}/'
                  '${data.year}',
                  style: pw.TextStyle(color: _navyDark, fontSize: 8,
                      fontWeight: pw.FontWeight.bold)),
              ])),
          ]),
        ]));
  }

  static pw.Widget _buildVazio(String mes, int ano) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(24),
      decoration: pw.BoxDecoration(
        color: _gray100, borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _gray300)),
      child: pw.Center(child: pw.Text(
        'Nenhum lancamento encontrado para $mes / $ano.',
        style: const pw.TextStyle(color: _gray500, fontSize: 11,
            fontStyle: pw.FontStyle.italic))));
  }

  static pw.Widget _buildFooter(String empresa, DateTime data,
      int pagina, String mes, int ano) {
    return pw.Container(
      color: _navyDark,
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 32, vertical: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(empresa, style: pw.TextStyle(
                  color: _gold, fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold)),
              pw.Text(
                'Relatorio Executivo de Frota  $mes / $ano  |  Uso interno',
                style: const pw.TextStyle(
                    color: _gray500, fontSize: 6.5)),
            ]),
          pw.Row(children: [
            pw.Text(
              '${data.day.toString().padLeft(2, '0')}/'
              '${data.month.toString().padLeft(2, '0')}/'
              '${data.year}  '
              '${data.hour.toString().padLeft(2, '0')}:'
              '${data.minute.toString().padLeft(2, '0')}',
              style: const pw.TextStyle(
                  color: _gray500, fontSize: 7)),
            pw.SizedBox(width: 14),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _gold, width: 1),
                borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Text('Pag. $pagina',
                style: pw.TextStyle(color: _goldLight, fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold))),
          ]),
        ]));
  }

  // ============ CÉLULAS ============

  static pw.Widget _th(String text,
      {pw.TextAlign align = pw.TextAlign.left}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(text, textAlign: align,
        style: pw.TextStyle(color: _goldLight, fontSize: 7.5,
            fontWeight: pw.FontWeight.bold, letterSpacing: 0.4)));

  static pw.Widget _td(String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor color = _gray700,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: pw.Text(text, textAlign: align,
      style: pw.TextStyle(color: color, fontSize: 8,
          fontWeight: bold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal)));

  static pw.Widget _thSm(String text,
      {pw.TextAlign align = pw.TextAlign.left}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(text, textAlign: align,
        style: pw.TextStyle(color: _navyDark, fontSize: 7,
            fontWeight: pw.FontWeight.bold, letterSpacing: 0.4)));

  static pw.Widget _tdSm(String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor color = _gray600,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    child: pw.Text(text, textAlign: align,
      style: pw.TextStyle(color: color, fontSize: 7,
          fontWeight: bold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal)));
}