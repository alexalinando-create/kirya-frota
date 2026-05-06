import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const String _vehiclesKey = 'veiculos_v1';
  static const String _fuelKeyPrefix = 'fuel_records_';
  static const String _maintKeyPrefix = 'maintenance_records_';
  static const String _tireKeyPrefix = 'tire_records_';

  // ============ DARK NEON ============
  static const Color _background = Color(0xFF0A0E1A);
  static const Color _surface = Color(0xFF0F1420);
  static const Color _surfaceLight = Color(0xFF1A1F2E);
  static const Color _neonCyan = Color(0xFF00E5FF);
  static const Color _neonPurple = Color(0xFFB388FF);
  static const Color _neonOrange = Color(0xFFFF6B35);
  static const Color _neonGreen = Color(0xFF00FF88);
  static const Color _neonPink = Color(0xFFFF4D6D);
  static const Color _textMain = Color(0xFFE8ECF4);
  static const Color _textMuted = Color(0xFF8A93A8);

  bool _loading = true;

  List<Map<String, dynamic>> _vehicles = [];

  double _totalFuelLitros = 0;
  double _totalFuelCusto = 0;
  double _totalMaintCusto = 0;
  double _totalTireCusto = 0;
  int _totalTireQuantidade = 0;

  double _totalKmReal = 0;
  int _totalAbastecimentos = 0;

  double _totalFaturamento = 0;
  double _totalLucro = 0;
  int _viagensComNota = 0;

  List<Map<String, dynamic>> _rankingVeiculos = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return 0.0;
    return double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ??
        double.tryParse(s.replaceAll(',', '.')) ??
        0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  String _fmt2(double v) {
    final s = v.toStringAsFixed(2);
    final partes = s.split('.');
    final inteiro = partes[0];
    final decimal = partes[1];
    final negativo = inteiro.startsWith('-');
    final numeros = negativo ? inteiro.substring(1) : inteiro;
    final buffer = StringBuffer();
    for (int i = 0; i < numeros.length; i++) {
      if (i > 0 && (numeros.length - i) % 3 == 0) buffer.write('.');
      buffer.write(numeros[i]);
    }
    return '${negativo ? '-' : ''}${buffer.toString()},$decimal';
  }

  String _fmtInt(double v) {
    final inteiro = v.toInt().toString();
    final negativo = inteiro.startsWith('-');
    final numeros = negativo ? inteiro.substring(1) : inteiro;
    final buffer = StringBuffer();
    for (int i = 0; i < numeros.length; i++) {
      if (i > 0 && (numeros.length - i) % 3 == 0) buffer.write('.');
      buffer.write(numeros[i]);
    }
    return '${negativo ? '-' : ''}${buffer.toString()}';
  }

  String _money(double v) => 'R\$ ${_fmt2(v)}';

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_vehiclesKey);
    List<Map<String, dynamic>> vehicles = [];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          vehicles = decoded
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
        }
      } catch (_) {}
    }

    double totalFuelLitros = 0;
    double totalFuelCusto = 0;
    double totalMaintCusto = 0;
    double totalTireCusto = 0;
    int totalTireQuantidade = 0;

    double totalKmReal = 0;
    int totalAbastecimentos = 0;

    double totalFaturamento = 0;
    double totalLucro = 0;
    int viagensComNota = 0;

    final ranking = <Map<String, dynamic>>[];

    for (final v in vehicles) {
      final id = (v['id'] ?? '').toString();
      if (id.isEmpty) continue;

      final placa = (v['placa'] ?? '').toString();
      final tipo = (v['tipo'] ?? v['modelo'] ?? '').toString();
      final nome = tipo.isEmpty ? placa : '$placa - $tipo';

      // Combustível
      final fuelRaw = prefs.getString('$_fuelKeyPrefix$id');
      List<Map<String, dynamic>> fuelRecords = [];
      if (fuelRaw != null && fuelRaw.trim().isNotEmpty) {
        try {
          final dec = jsonDecode(fuelRaw);
          if (dec is List) {
            fuelRecords = dec
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList();
          }
        } catch (_) {}
      }

      double veicFuelLitros = 0;
      double veicFuelCusto = 0;
      double veicKmReal = 0;
      double veicFaturamento = 0;
      double veicLucro = 0;

      for (final r in fuelRecords) {
        final litros = _toDouble(r['litrosFinal']);
        final custo = _toDouble(r['custoFinal']);
        final kmRodado = _toDouble(r['kmRodadoReal']);
        final valorNota = _toDouble(r['valorNota']);

        veicFuelLitros += litros;
        veicFuelCusto += custo;
        if (kmRodado > 0) veicKmReal += kmRodado;

        if (valorNota > 0) {
          veicFaturamento += valorNota;
          veicLucro += (valorNota - custo);
          viagensComNota++;
        }

        totalAbastecimentos++;
      }

      totalFuelLitros += veicFuelLitros;
      totalFuelCusto += veicFuelCusto;
      totalKmReal += veicKmReal;
      totalFaturamento += veicFaturamento;
      totalLucro += veicLucro;

      // Manutenção
      final maintRaw = prefs.getString('$_maintKeyPrefix$id');
      double veicMaintCusto = 0;
      if (maintRaw != null && maintRaw.trim().isNotEmpty) {
        try {
          final dec = jsonDecode(maintRaw);
          if (dec is List) {
            for (final r in dec.whereType<Map>()) {
              veicMaintCusto += _toDouble(r['custo']);
            }
          }
        } catch (_) {}
      }
      totalMaintCusto += veicMaintCusto;

      // Pneus
      final tireRaw = prefs.getString('$_tireKeyPrefix$id');
      double veicTireCusto = 0;
      int veicTireQtd = 0;
      if (tireRaw != null && tireRaw.trim().isNotEmpty) {
        try {
          final dec = jsonDecode(tireRaw);
          if (dec is List) {
            for (final r in dec.whereType<Map>()) {
              veicTireCusto += _toDouble(r['custo']);
              veicTireQtd += _toInt(r['quantidade']);
            }
          }
        } catch (_) {}
      }
      totalTireCusto += veicTireCusto;
      totalTireQuantidade += veicTireQtd;

      final veicCustoTotal = veicFuelCusto + veicMaintCusto + veicTireCusto;
      final veicConsumoReal =
          (veicFuelLitros > 0 && veicKmReal > 0) ? (veicKmReal / veicFuelLitros) : 0.0;

      ranking.add({
        'nome': nome,
        'fuel': veicFuelCusto,
        'maint': veicMaintCusto,
        'tire': veicTireCusto,
        'total': veicCustoTotal,
        'kmReal': veicKmReal,
        'litros': veicFuelLitros,
        'consumoReal': veicConsumoReal,
        'faturamento': veicFaturamento,
        'lucro': veicLucro,
      });
    }

    ranking.sort(
        (a, b) => _toDouble(b['total']).compareTo(_toDouble(a['total'])));

    if (!mounted) return;
    setState(() {
      _vehicles = vehicles;
      _totalFuelLitros = totalFuelLitros;
      _totalFuelCusto = totalFuelCusto;
      _totalMaintCusto = totalMaintCusto;
      _totalTireCusto = totalTireCusto;
      _totalTireQuantidade = totalTireQuantidade;
      _totalKmReal = totalKmReal;
      _totalAbastecimentos = totalAbastecimentos;
      _totalFaturamento = totalFaturamento;
      _totalLucro = totalLucro;
      _viagensComNota = viagensComNota;
      _rankingVeiculos = ranking;
      _loading = false;
    });
  }

  double get _consumoMedioFrota {
    if (_totalFuelLitros > 0 && _totalKmReal > 0) {
      return _totalKmReal / _totalFuelLitros;
    }
    return 0;
  }

  double get _custoTotal => _totalFuelCusto + _totalMaintCusto + _totalTireCusto;

  double get _custoPorKmFrota {
    if (_totalKmReal > 0 && _custoTotal > 0) {
      return _custoTotal / _totalKmReal;
    }
    return 0;
  }

  double get _resultadoLiquido => _totalFaturamento - _custoTotal;

  double get _margemLiquidaPct {
    if (_totalFaturamento <= 0) return 0;
    return (_resultadoLiquido / _totalFaturamento) * 100;
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required String? caption,
    required IconData icon,
    required Color color,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? color.withOpacity(0.18) : _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(highlight ? 0.6 : 0.3),
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(highlight ? 0.2 : 0.08),
            blurRadius: highlight ? 18 : 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: _textMain,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption,
              style: const TextStyle(color: _textMuted, fontSize: 10.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _composicaoCustosChart() {
    final total = _custoTotal;
    if (total <= 0) {
      return _emptyMsg('Sem dados de custos para exibir.');
    }

    final pComb = (_totalFuelCusto / total) * 100;
    final pMan = (_totalMaintCusto / total) * 100;
    final pPneu = (_totalTireCusto / total) * 100;

    Widget linha(String titulo, double valor, double pct, Color cor) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(titulo,
                        style: const TextStyle(
                            color: _textMain,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                Text(
                  '${_money(valor)} (${_fmt2(pct)}%)',
                  style: TextStyle(
                      color: cor, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                LayoutBuilder(builder: (context, constraints) {
                  return Container(
                    height: 8,
                    width: constraints.maxWidth * (pct / 100),
                    decoration: BoxDecoration(
                      color: cor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neonPurple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.pie_chart_outline_rounded,
                  color: _neonPurple, size: 20),
              SizedBox(width: 8),
              Text('Composição dos custos',
                  style: TextStyle(
                      color: _textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          linha('Combustível', _totalFuelCusto, pComb, _neonCyan),
          linha('Manutenção', _totalMaintCusto, pMan, _neonOrange),
          linha('Pneus', _totalTireCusto, pPneu, _neonGreen),
        ],
      ),
    );
  }

  Widget _rankingChart() {
    final ativos =
        _rankingVeiculos.where((e) => _toDouble(e['total']) > 0).toList();

    if (ativos.isEmpty) return _emptyMsg('Sem custos lançados para exibir ranking.');

    final maxValue = ativos
        .map((e) => _toDouble(e['total']))
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neonPink.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.bar_chart_rounded, color: _neonPink, size: 20),
              SizedBox(width: 8),
              Text('Ranking por custo total',
                  style: TextStyle(
                      color: _textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Veículos mais caros (todos os custos somados).',
              style: TextStyle(color: _textMuted, fontSize: 11)),
          const SizedBox(height: 12),
          SizedBox(
            height: ativos.length * 32.0 + 20,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue * 1.15,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= ativos.length) {
                          return const SizedBox.shrink();
                        }
                        final nome = ativos[i]['nome'].toString();
                        final partes = nome.split(' - ');
                        final placa = partes.first;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            placa.length > 7 ? placa.substring(0, 7) : placa,
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(ativos.length, (i) {
                  final total = _toDouble(ativos[i]['total']);
                  final cor = i == 0
                      ? _neonPink
                      : i == 1
                          ? _neonOrange
                          : i == 2
                              ? _neonPurple
                              : _neonCyan;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: total,
                        color: cor,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _veiculosListItem(int idx, Map<String, dynamic> v) {
    final nome = v['nome'].toString();
    final total = _toDouble(v['total']);
    final consumo = _toDouble(v['consumoReal']);
    final faturamento = _toDouble(v['faturamento']);
    final lucro = _toDouble(v['lucro']);

    Color medalha;
    if (idx == 0) {
      medalha = _neonPink;
    } else if (idx == 1) {
      medalha = _neonOrange;
    } else if (idx == 2) {
      medalha = _neonPurple;
    } else {
      medalha = _neonCyan;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: medalha.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: medalha.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('${idx + 1}',
                  style: TextStyle(
                    color: medalha,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  )),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome,
                    style: const TextStyle(
                        color: _textMain,
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(_money(total),
                        style: const TextStyle(
                            color: _neonGreen,
                            fontWeight: FontWeight.w900,
                            fontSize: 13)),
                    if (consumo > 0) ...[
                      const SizedBox(width: 8),
                      Text('${_fmt2(consumo)} km/L',
                          style: const TextStyle(
                              color: _textMuted, fontSize: 11)),
                    ],
                  ],
                ),
                if (faturamento > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Lucro: ${_money(lucro)}',
                      style: TextStyle(
                          color: lucro >= 0 ? _neonGreen : _neonPink,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyMsg(String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _textMuted.withOpacity(0.2)),
      ),
      child: Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _textMuted, fontStyle: FontStyle.italic)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        colorScheme: const ColorScheme.dark(
          primary: _neonPurple,
          surface: _surface,
          onPrimary: _background,
          onSurface: _textMain,
        ),
      ),
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          foregroundColor: _textMain,
          elevation: 0,
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_neonPurple, _neonCyan],
            ).createShader(bounds),
            child: const Text(
              'DASHBOARD',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: Colors.white,
              ),
            ),
          ),
          iconTheme: const IconThemeData(color: _neonPurple),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: _neonPurple),
              onPressed: _loading ? null : _loadAll,
              tooltip: 'Atualizar',
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _neonPurple))
            : RefreshIndicator(
                onRefresh: _loadAll,
                color: _neonPurple,
                backgroundColor: _surface,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _neonPurple.withOpacity(0.2),
                            _neonCyan.withOpacity(0.08),
                          ],
                        ),
                        border: Border.all(color: _neonPurple.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 54,
                            width: 54,
                            decoration: BoxDecoration(
                              color: _neonPurple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.analytics_outlined,
                                color: _neonPurple, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Visão geral da frota',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: _textMain)),
                                const SizedBox(height: 4),
                                Text(
                                  '${_vehicles.length} veículo(s) · $_totalAbastecimentos abastecimento(s)',
                                  style: const TextStyle(
                                      fontSize: 12, color: _textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.4,
                      children: [
                        _kpiCard(
                          label: 'CUSTO TOTAL',
                          value: _money(_custoTotal),
                          caption: 'Combustível + Manut. + Pneus',
                          icon: Icons.payments_outlined,
                          color: _neonPink,
                        ),
                        _kpiCard(
                          label: 'KM RODADOS',
                          value: '${_fmtInt(_totalKmReal)} km',
                          caption: 'Soma de todos os veículos',
                          icon: Icons.route_outlined,
                          color: _neonCyan,
                        ),
                        _kpiCard(
                          label: 'CONSUMO MÉDIO',
                          value: _consumoMedioFrota > 0
                              ? '${_fmt2(_consumoMedioFrota)} km/L'
                              : '-',
                          caption: 'Eficiência geral da frota',
                          icon: Icons.local_gas_station_outlined,
                          color: _neonOrange,
                        ),
                        _kpiCard(
                          label: 'CUSTO/KM',
                          value: _custoPorKmFrota > 0
                              ? _money(_custoPorKmFrota)
                              : '-',
                          caption: 'Custo médio por quilômetro',
                          icon: Icons.speed_outlined,
                          color: _neonPurple,
                        ),
                      ],
                    ),

                    if (_viagensComNota > 0) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _kpiCard(
                              label: 'FATURAMENTO',
                              value: _money(_totalFaturamento),
                              caption: '$_viagensComNota viagem(ns)',
                              icon: Icons.trending_up,
                              color: _neonGreen,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _kpiCard(
                              label: _resultadoLiquido >= 0
                                  ? 'LUCRO LÍQUIDO'
                                  : 'PREJUÍZO',
                              value: _money(_resultadoLiquido.abs()),
                              caption:
                                  'Margem: ${_fmt2(_margemLiquidaPct)}%',
                              icon: _resultadoLiquido >= 0
                                  ? Icons.savings_outlined
                                  : Icons.warning_amber_rounded,
                              color: _resultadoLiquido >= 0
                                  ? _neonGreen
                                  : _neonPink,
                              highlight: true,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    _composicaoCustosChart(),
                    const SizedBox(height: 16),
                    _rankingChart(),
                    const SizedBox(height: 16),

                    if (_rankingVeiculos
                        .where((e) => _toDouble(e['total']) > 0)
                        .isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _neonCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: _neonCyan.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.list_alt_outlined,
                                color: _neonCyan, size: 18),
                            SizedBox(width: 8),
                            Text('Detalhamento por veículo',
                                style: TextStyle(
                                    color: _textMain,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._rankingVeiculos
                          .where((e) => _toDouble(e['total']) > 0)
                          .toList()
                          .asMap()
                          .entries
                          .map((entry) =>
                              _veiculosListItem(entry.key, entry.value)),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}