import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceitaScreen extends StatefulWidget {
  const ReceitaScreen({super.key});

  @override
  State<ReceitaScreen> createState() => _ReceitaScreenState();
}

class _ReceitaScreenState extends State<ReceitaScreen> {
  static const String _vehiclesKey = 'veiculos_v1';
  static const String _revenueKeyPrefix = 'revenue_records_';
  static const String _fuelKeyPrefix = 'fuel_records_';
  static const String _maintKeyPrefix = 'maintenance_records_';
  static const String _tireKeyPrefix = 'tire_records_';

  final TextEditingController _valorCtrl = TextEditingController();
  final TextEditingController _observacaoCtrl = TextEditingController();

  bool _loading = true;
  List<Map<String, dynamic>> _veiculos = [];
  String? _veiculoSelecionadoId;
  DateTime _dataSelecionada = DateTime.now();

  List<Map<String, dynamic>> _lancamentosMes = [];
  List<_ResultadoVeiculo> _resultados = [];

  double _receitaMes = 0.0;
  double _custoMes = 0.0;
  double _lucroMes = 0.0;
  double _kmMes = 0.0;
  double _lucroPorKm = 0.0;

  int _qtdLancamentosMes = 0;
  double _mediaDiariaReceita = 0.0;

  String _veiculoMaiorReceita = 'Nenhum';
  String _veiculoMaisLucrativo = 'Nenhum';
  String _veiculoComPrejuizo = 'Nenhum';

  static const Color _greenPrimary = Color(0xFF16A34A);
  static const Color _greenSoft = Color(0xFFEFFBF3);
  static const Color _redSoft = Color(0xFFFFF1F2);
  static const Color _purpleSoft = Color(0xFFF5F0FF);
  static const Color _blueSoft = Color(0xFFEFF6FF);
  static const Color _amberSoft = Color(0xFFFFF8EB);
  static const Color _tealSoft = Color(0xFFEEFDFC);

  DateTime get _mesAtual => DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    _carregarTudo();
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    _observacaoCtrl.dispose();
    super.dispose();
  }

  bool _sameMonth(DateTime d, DateTime m) => d.year == m.year && d.month == m.month;

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
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

  String _fmtMoney(double v) {
    return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  String _fmtKm(double v) {
    return '${v.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  String _vehicleIdFromMap(Map<String, dynamic> v) {
    return (v['id'] ?? v['vehicleId'] ?? v['placa'] ?? v['plate'] ?? '').toString();
  }

  String _vehiclePlateFromMap(Map<String, dynamic> v) {
    return (v['placa'] ?? v['plate'] ?? '').toString().trim();
  }

  String _vehicleTypeFromMap(Map<String, dynamic> v) {
    return (v['tipo'] ?? v['modelo'] ?? '').toString().trim();
  }

  String _vehicleLabel(Map<String, dynamic> v) {
    final placa = _vehiclePlateFromMap(v);
    final tipo = _vehicleTypeFromMap(v);

    if (placa.isNotEmpty && tipo.isNotEmpty) {
      return '$placa • $tipo';
    }
    if (placa.isNotEmpty) return placa;
    if (tipo.isNotEmpty) return tipo;
    return 'Veículo';
  }

  String _vehicleNameById(String vehicleId) {
    final veiculo = _veiculos.cast<Map<String, dynamic>?>().firstWhere(
          (v) => v != null && _vehicleIdFromMap(v) == vehicleId,
          orElse: () => null,
        );

    if (veiculo == null) return 'Veículo não encontrado';
    return _vehicleLabel(veiculo);
  }

  Future<List<Map<String, dynamic>>> _loadVehicles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_vehiclesKey);

    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadRevenueRecords(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_revenueKeyPrefix$vehicleId');

    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveRevenueRecords(String vehicleId, List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_revenueKeyPrefix$vehicleId', jsonEncode(list));
  }

  Future<List<Map<String, dynamic>>> _loadFuelRecords(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_fuelKeyPrefix$vehicleId');

    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadMaintRecords(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_maintKeyPrefix$vehicleId');

    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadTireRecords(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_tireKeyPrefix$vehicleId');

    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  double _distanceFromFuelRecord(Map<String, dynamic> r) {
    if (r.containsKey('distanciaKm')) return _toDouble(r['distanciaKm']);
    if (r.containsKey('distancia_km')) return _toDouble(r['distancia_km']);
    if (r.containsKey('distanciaTotal')) return _toDouble(r['distanciaTotal']);
    if (r.containsKey('distancia')) return _toDouble(r['distancia']);
    if (r.containsKey('distanciaIdaKm')) return _toDouble(r['distanciaIdaKm']) * 2.0;
    return 0.0;
  }

  Future<void> _carregarTudo() async {
    setState(() => _loading = true);

    final veiculos = await _loadVehicles();

    if (_veiculoSelecionadoId == null && veiculos.isNotEmpty) {
      _veiculoSelecionadoId = _vehicleIdFromMap(veiculos.first);
    }

    final List<Map<String, dynamic>> todosLancamentosMes = [];
    final List<_ResultadoVeiculo> resultados = [];

    double receitaMes = 0.0;
    double custoMes = 0.0;
    double kmMes = 0.0;

    final Set<String> diasComReceita = {};

    for (final v in veiculos) {
      final vehicleId = _vehicleIdFromMap(v);
      if (vehicleId.trim().isEmpty) continue;

      double receitaVeiculo = 0.0;
      double custoVeiculo = 0.0;
      double kmVeiculo = 0.0;

      final receitas = await _loadRevenueRecords(vehicleId);
      for (final r in receitas) {
        final dt = _parseDate(r['date']);
        if (dt == null) continue;
        if (!_sameMonth(dt, _mesAtual)) continue;

        final valor = _toDouble(r['valor']);
        receitaVeiculo += valor;
        receitaMes += valor;
        diasComReceita.add('${dt.year}-${dt.month}-${dt.day}');

        todosLancamentosMes.add({
          ...r,
          'vehicleId': vehicleId,
          'vehicleLabel': _vehicleLabel(v),
        });
      }

      final combustivel = await _loadFuelRecords(vehicleId);
      for (final r in combustivel) {
        final dt = _parseDate(r['date']);
        if (dt == null) continue;
        if (!_sameMonth(dt, _mesAtual)) continue;

        final custo = _toDouble(r['custoFinal']);
        final km = _distanceFromFuelRecord(r);

        custoVeiculo += custo;
        custoMes += custo;

        kmVeiculo += km;
        kmMes += km;
      }

      final manutencoes = await _loadMaintRecords(vehicleId);
      for (final r in manutencoes) {
        final dt = _parseDate(r['date']);
        if (dt == null) continue;
        if (!_sameMonth(dt, _mesAtual)) continue;

        final custo = _toDouble(r['custo']);
        custoVeiculo += custo;
        custoMes += custo;
      }

      final pneus = await _loadTireRecords(vehicleId);
      for (final r in pneus) {
        final dt = _parseDate(r['date']);
        if (dt == null) continue;
        if (!_sameMonth(dt, _mesAtual)) continue;

        final custo = _toDouble(r['custo']);
        custoVeiculo += custo;
        custoMes += custo;
      }

      final lucroVeiculo = receitaVeiculo - custoVeiculo;
      final lucroPorKmVeiculo = kmVeiculo > 0 ? lucroVeiculo / kmVeiculo : 0.0;

      if (receitaVeiculo > 0 || custoVeiculo > 0 || kmVeiculo > 0) {
        resultados.add(
          _ResultadoVeiculo(
            vehicleId: vehicleId,
            vehicleLabel: _vehicleLabel(v),
            receita: receitaVeiculo,
            custo: custoVeiculo,
            lucro: lucroVeiculo,
            km: kmVeiculo,
            lucroPorKm: lucroPorKmVeiculo,
          ),
        );
      }
    }

    todosLancamentosMes.sort((a, b) {
      final da = _parseDate(a['date']) ?? DateTime(2000);
      final db = _parseDate(b['date']) ?? DateTime(2000);
      return db.compareTo(da);
    });

    resultados.sort((a, b) => b.lucro.compareTo(a.lucro));

    final lucroMes = receitaMes - custoMes;
    final lucroPorKm = kmMes > 0 ? lucroMes / kmMes : 0.0;
    final qtdLancamentosMes = todosLancamentosMes.length;
    final mediaDiariaReceita =
        diasComReceita.isNotEmpty ? receitaMes / diasComReceita.length : 0.0;

    String veiculoMaiorReceita = 'Nenhum';
    if (resultados.isNotEmpty) {
      final ordenadoReceita = [...resultados]..sort((a, b) => b.receita.compareTo(a.receita));
      if (ordenadoReceita.first.receita > 0) {
        veiculoMaiorReceita = ordenadoReceita.first.vehicleLabel;
      }
    }

    String veiculoMaisLucrativo = 'Nenhum';
    if (resultados.isNotEmpty && resultados.first.lucro > 0) {
      veiculoMaisLucrativo = resultados.first.vehicleLabel;
    }

    String veiculoComPrejuizo = 'Nenhum';
    final comPrejuizo = resultados.where((e) => e.lucro < 0).toList()
      ..sort((a, b) => a.lucro.compareTo(b.lucro));
    if (comPrejuizo.isNotEmpty) {
      veiculoComPrejuizo = comPrejuizo.first.vehicleLabel;
    }

    if (!mounted) return;
    setState(() {
      _veiculos = veiculos;
      _lancamentosMes = todosLancamentosMes;
      _resultados = resultados;
      _receitaMes = receitaMes;
      _custoMes = custoMes;
      _lucroMes = lucroMes;
      _kmMes = kmMes;
      _lucroPorKm = lucroPorKm;
      _qtdLancamentosMes = qtdLancamentosMes;
      _mediaDiariaReceita = mediaDiariaReceita;
      _veiculoMaiorReceita = veiculoMaiorReceita;
      _veiculoMaisLucrativo = veiculoMaisLucrativo;
      _veiculoComPrejuizo = veiculoComPrejuizo;
      _loading = false;
    });
  }

  Future<void> _selecionarData() async {
    final hoje = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2023),
      lastDate: DateTime(hoje.year + 5),
    );

    if (picked != null) {
      setState(() {
        _dataSelecionada = picked;
      });
    }
  }

  Future<void> _salvarReceita() async {
    if (_veiculoSelecionadoId == null || _veiculoSelecionadoId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um veículo.')),
      );
      return;
    }

    final valor = _toDouble(_valorCtrl.text);
    if (valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor de receita válido.')),
      );
      return;
    }

    final vehicleId = _veiculoSelecionadoId!;
    final atuais = await _loadRevenueRecords(vehicleId);

    atuais.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'date': _dataSelecionada.toIso8601String(),
      'valor': valor,
      'observacao': _observacaoCtrl.text.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    });

    await _saveRevenueRecords(vehicleId, atuais);

    _valorCtrl.clear();
    _observacaoCtrl.clear();
    _dataSelecionada = DateTime.now();

    await _carregarTudo();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Receita lançada com sucesso!')),
    );
  }

  Future<void> _apagarReceita(Map<String, dynamic> item) async {
    final vehicleId = (item['vehicleId'] ?? '').toString();
    final id = (item['id'] ?? '').toString();

    if (vehicleId.isEmpty || id.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Apagar lançamento'),
        content: const Text('Deseja apagar este lançamento de receita?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final lista = await _loadRevenueRecords(vehicleId);
    lista.removeWhere((e) => (e['id'] ?? '').toString() == id);
    await _saveRevenueRecords(vehicleId, lista);

    await _carregarTudo();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗑️ Lançamento apagado.')),
    );
  }

  Widget _heroCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _greenPrimary.withOpacity(0.18),
            const Color(0xFFE9F9EE),
            Colors.white,
          ],
        ),
        border: Border.all(color: _greenPrimary.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            color: _greenPrimary.withOpacity(0.10),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.86),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.attach_money_rounded,
              size: 32,
              color: _greenPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Painel financeiro da frota',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Receita, custo, lucro e prejuízo por veículo no mês atual.',
                  style: TextStyle(
                    fontSize: 12.8,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.8,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _formCard(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: _greenPrimary.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            color: _greenPrimary.withOpacity(0.06),
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: _greenPrimary),
                SizedBox(width: 8),
                Text(
                  'Lançar receita',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _veiculoSelecionadoId,
              items: _veiculos.map((v) {
                final id = _vehicleIdFromMap(v);
                return DropdownMenuItem<String>(
                  value: id,
                  child: Text(_vehicleLabel(v)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _veiculoSelecionadoId = value;
                });
              },
              decoration: InputDecoration(
                labelText: 'Veículo',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: _greenSoft,
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _selecionarData,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Data',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  suffixIcon: const Icon(Icons.calendar_today),
                  filled: true,
                  fillColor: _greenSoft,
                ),
                child: Text(_fmtDate(_dataSelecionada)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _valorCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Valor da carga / receita',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                hintText: 'Ex: 2500,00',
                filled: true,
                fillColor: _greenSoft,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _observacaoCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Observação (opcional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                hintText: 'Ex: carga Fortaleza / cliente X',
                filled: true,
                fillColor: _greenSoft,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _greenPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _veiculos.isEmpty ? null : _salvarReceita,
              icon: const Icon(Icons.add),
              label: const Text(
                'Salvar receita',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (_veiculos.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Cadastre ao menos um veículo para lançar receitas.',
                style: TextStyle(
                  fontSize: 12.2,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultadoCard(_ResultadoVeiculo item, ColorScheme cs) {
    final bool positivo = item.lucro > 0;
    final bool negativo = item.lucro < 0;

    final Color color = positivo
        ? const Color(0xFF16A34A)
        : negativo
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);

    final Color bg = positivo
        ? const Color(0xFFEFFBF3)
        : negativo
            ? const Color(0xFFFFF1F2)
            : const Color(0xFFFFF8EB);

    final resultadoTexto = positivo
        ? 'Lucro'
        : negativo
            ? 'Prejuízo'
            : 'Empate';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            color: color.withOpacity(0.05),
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.vehicleLabel,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            runSpacing: 6,
            spacing: 12,
            children: [
              Text(
                'Receita: ${_fmtMoney(item.receita)}',
                style: const TextStyle(fontSize: 12.8, fontWeight: FontWeight.w700),
              ),
              Text(
                'Custo: ${_fmtMoney(item.custo)}',
                style: const TextStyle(fontSize: 12.8, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            runSpacing: 6,
            spacing: 12,
            children: [
              Text(
                '$resultadoTexto: ${_fmtMoney(item.lucro)}',
                style: TextStyle(
                  fontSize: 13.4,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                item.km > 0 ? 'KM: ${_fmtKm(item.km)}' : 'KM: sem dados',
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.km > 0
                ? 'Lucro por KM: ${_fmtMoney(item.lucroPorKm)} / km'
                : 'Lucro por KM: sem KM no mês',
            style: TextStyle(
              fontSize: 12.5,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lancamentosCard(ColorScheme cs) {
    if (_lancamentosMes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _greenPrimary.withOpacity(0.10)),
        ),
        child: const Text('Nenhuma receita lançada no mês atual.'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _greenPrimary.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            color: _greenPrimary.withOpacity(0.05),
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < _lancamentosMes.length; i++)
            Builder(
              builder: (_) {
                final item = _lancamentosMes[i];
                final dt = _parseDate(item['date']);
                final valor = _toDouble(item['valor']);
                final obs = (item['observacao'] ?? '').toString().trim();
                final vehicleLabel = (item['vehicleLabel'] ?? '').toString();

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: i == _lancamentosMes.length - 1
                        ? null
                        : Border(
                            bottom: BorderSide(
                              color: _greenPrimary.withOpacity(0.08),
                            ),
                          ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: _greenPrimary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.attach_money_rounded,
                          color: _greenPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicleLabel.isEmpty
                                  ? _vehicleNameById((item['vehicleId'] ?? '').toString())
                                  : vehicleLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dt == null ? 'Data inválida' : _fmtDate(dt),
                              style: TextStyle(
                                fontSize: 12.3,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _fmtMoney(valor),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: _greenPrimary,
                              ),
                            ),
                            if (obs.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                obs,
                                style: TextStyle(
                                  fontSize: 12.2,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Apagar',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _apagarReceita(item),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final resultadoMesColor = _lucroMes > 0
        ? const Color(0xFF16A34A)
        : _lucroMes < 0
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);

    final resultadoMesTitulo = _lucroMes > 0
        ? 'Lucro do mês'
        : _lucroMes < 0
            ? 'Prejuízo do mês'
            : 'Resultado do mês';

    return Scaffold(
      backgroundColor: const Color(0xFFFBFEFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFBFEFC),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Receita por veículo',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _carregarTudo,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _heroCard(cs),
                const SizedBox(height: 18),
                _sectionTitle(
                  'Indicadores financeiros',
                  'Receita, custo e resultado geral do mês.',
                  cs,
                ),
                const SizedBox(height: 12),
                _topCard(
                  icon: Icons.payments_outlined,
                  title: 'Receita total do mês',
                  value: _fmtMoney(_receitaMes),
                  color: _greenPrimary,
                  bgColor: _greenSoft,
                ),
                const SizedBox(height: 10),
                _topCard(
                  icon: Icons.money_off_csred_outlined,
                  title: 'Custo total do mês',
                  value: _fmtMoney(_custoMes),
                  color: const Color(0xFFEF4444),
                  bgColor: _redSoft,
                ),
                const SizedBox(height: 10),
                _topCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: resultadoMesTitulo,
                  value: _fmtMoney(_lucroMes),
                  color: resultadoMesColor,
                  bgColor: resultadoMesColor == const Color(0xFF16A34A)
                      ? _greenSoft
                      : resultadoMesColor == const Color(0xFFEF4444)
                          ? _redSoft
                          : _amberSoft,
                ),
                const SizedBox(height: 10),
                _topCard(
                  icon: Icons.route_outlined,
                  title: 'Lucro por KM',
                  value: _kmMes > 0
                      ? '${_fmtMoney(_lucroPorKm)} / km'
                      : 'Sem KM lançado no mês',
                  color: const Color(0xFF7C3AED),
                  bgColor: _purpleSoft,
                ),
                const SizedBox(height: 10),
                _topCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Lançamentos no mês',
                  value: '$_qtdLancamentosMes',
                  color: const Color(0xFF2563EB),
                  bgColor: _blueSoft,
                ),
                const SizedBox(height: 10),
                _topCard(
                  icon: Icons.calendar_month_outlined,
                  title: 'Média diária de receita',
                  value: _mediaDiariaReceita > 0
                      ? _fmtMoney(_mediaDiariaReceita)
                      : 'Sem dados',
                  color: const Color(0xFF9333EA),
                  bgColor: _purpleSoft,
                ),
                const SizedBox(height: 10),
                _topCard(
                  icon: Icons.emoji_events_outlined,
                  title: 'Veículo com maior receita',
                  value: _veiculoMaiorReceita,
                  color: const Color(0xFFF59E0B),
                  bgColor: _amberSoft,
                ),
                const SizedBox(height: 10),
                _topCard(
                  icon: Icons.trending_up_outlined,
                  title: 'Veículo mais lucrativo',
                  value: _veiculoMaisLucrativo,
                  color: const Color(0xFF0F766E),
                  bgColor: _tealSoft,
                ),
                const SizedBox(height: 10),
                _topCard(
                  icon: Icons.warning_amber_outlined,
                  title: 'Veículo com prejuízo',
                  value: _veiculoComPrejuizo,
                  color: const Color(0xFFDC2626),
                  bgColor: _redSoft,
                ),
                const SizedBox(height: 18),
                _sectionTitle(
                  'Lançamento diário',
                  'Registre a receita sem alterar combustível, manutenção ou pneus.',
                  cs,
                ),
                const SizedBox(height: 12),
                _formCard(cs),
                const SizedBox(height: 18),
                _sectionTitle(
                  'Resultado por veículo',
                  'Comparação direta entre receita, custo e resultado do mês.',
                  cs,
                ),
                const SizedBox(height: 10),
                if (_resultados.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _greenPrimary.withOpacity(0.10)),
                    ),
                    child: const Text(
                      'Sem dados suficientes neste mês para calcular resultado por veículo.',
                    ),
                  )
                else
                  Column(
                    children: _resultados.map((e) => _resultadoCard(e, cs)).toList(),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _sectionTitle(
                        'Lançamentos do mês atual',
                        'Histórico financeiro diário por veículo.',
                        cs,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _greenPrimary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$_qtdLancamentosMes',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _greenPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _lancamentosCard(cs),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _greenPrimary.withOpacity(0.08)),
                  ),
                  child: Text(
                    'Obs: esta aba não altera abastecimento, manutenção ou pneus. Ela registra a receita diária por veículo e cruza automaticamente com os custos do mês para mostrar lucro ou prejuízo.',
                    style: TextStyle(
                      fontSize: 12.2,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ResultadoVeiculo {
  final String vehicleId;
  final String vehicleLabel;
  final double receita;
  final double custo;
  final double lucro;
  final double km;
  final double lucroPorKm;

  _ResultadoVeiculo({
    required this.vehicleId,
    required this.vehicleLabel,
    required this.receita,
    required this.custo,
    required this.lucro,
    required this.km,
    required this.lucroPorKm,
  });
}