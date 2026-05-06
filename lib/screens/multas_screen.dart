import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MultasScreen extends StatefulWidget {
  const MultasScreen({super.key});

  @override
  State<MultasScreen> createState() => _MultasScreenState();
}

class _MultasScreenState extends State<MultasScreen> {
  static const String _vehiclesKey = 'veiculos_v1';
  static const String _finesKey = 'fine_records_v1';

  static const Color _primaryColor = Color(0xFFD32F2F);
  static const Color _softRed = Color(0xFFFFF1F2);
  static const Color _softAmber = Color(0xFFFFF8E8);
  static const Color _softGreen = Color(0xFFEEF9F1);
  static const Color _softBlue = Color(0xFFEFF6FF);

  final _descricaoCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _records = [];

  String? _selectedVehicleId;
  DateTime _dataMulta = DateTime.now();
  DateTime _vencimento = DateTime.now().add(const Duration(days: 10));

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();

    final rawVehicles = prefs.getString(_vehiclesKey);
    List<Map<String, dynamic>> vehicles = [];
    if (rawVehicles != null && rawVehicles.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawVehicles);
        if (decoded is List) {
          vehicles = decoded
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
        }
      } catch (_) {}
    }

    final rawRecords = prefs.getString(_finesKey);
    List<Map<String, dynamic>> records = [];
    if (rawRecords != null && rawRecords.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawRecords);
        if (decoded is List) {
          records = decoded
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
        }
      } catch (_) {}
    }

    records.sort((a, b) {
      final da = _parseDate(a['dataMulta']) ?? DateTime(2100);
      final db = _parseDate(b['dataMulta']) ?? DateTime(2100);
      return db.compareTo(da);
    });

    String? selectedVehicleId = _selectedVehicleId;
    if (selectedVehicleId == null && vehicles.isNotEmpty) {
      selectedVehicleId = _vehicleIdFromMap(vehicles.first);
    }

    if (!mounted) return;
    setState(() {
      _vehicles = vehicles;
      _records = records;
      _selectedVehicleId = selectedVehicleId;
      _loading = false;
    });
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_finesKey, jsonEncode(_records));
  }

  String _vehicleIdFromMap(Map<String, dynamic> v) {
    return (v['id'] ?? v['vehicleId'] ?? v['placa'] ?? '').toString();
  }

  String _vehicleLabelFromMap(Map<String, dynamic> v) {
    final placa = (v['placa'] ?? '').toString().trim();
    final tipo = (v['tipo'] ?? v['modelo'] ?? '').toString().trim();

    if (placa.isNotEmpty && tipo.isNotEmpty) return '$placa • $tipo';
    if (placa.isNotEmpty) return placa;
    if (tipo.isNotEmpty) return tipo;
    return 'Veículo';
  }

  String _vehicleLabelById(String? id) {
    if (id == null || id.trim().isEmpty) return 'Não selecionado';
    for (final v in _vehicles) {
      if (_vehicleIdFromMap(v) == id) {
        return _vehicleLabelFromMap(v);
      }
    }
    return id;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
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

  bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  bool _isPago(Map<String, dynamic> item) {
    return (item['status'] ?? '').toString() == 'pago';
  }

  bool _isVencida(Map<String, dynamic> item) {
    if (_isPago(item)) return false;
    final venc = _parseDate(item['vencimento']);
    if (venc == null) return false;

    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final vencSemHora = DateTime(venc.year, venc.month, venc.day);

    return vencSemHora.isBefore(hojeSemHora);
  }

  bool _venceEmBreve(Map<String, dynamic> item) {
    if (_isPago(item)) return false;
    final venc = _parseDate(item['vencimento']);
    if (venc == null) return false;

    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final vencSemHora = DateTime(venc.year, venc.month, venc.day);

    final diferenca = vencSemHora.difference(hojeSemHora).inDays;
    return diferenca >= 0 && diferenca <= 7;
  }

  List<Map<String, dynamic>> get _pendentes =>
      _records.where((e) => !_isPago(e)).toList();

  List<Map<String, dynamic>> get _vencidas =>
      _records.where((e) => _isVencida(e)).toList();

  List<Map<String, dynamic>> get _proximas =>
      _records.where((e) => _venceEmBreve(e)).toList();

  List<Map<String, dynamic>> get _historicoMesAtual {
    final now = DateTime.now();
    return _records.where((e) {
      final dt = _parseDate(e['dataMulta']);
      if (dt == null) return false;
      return _sameMonth(dt, now);
    }).toList();
  }

  double get _totalPendente {
    double total = 0.0;
    for (final item in _pendentes) {
      total += _toDouble(item['valor']);
    }
    return total;
  }

  double get _totalMes {
    double total = 0.0;
    for (final item in _historicoMesAtual) {
      total += _toDouble(item['valor']);
    }
    return total;
  }

  Future<void> _pickDataMulta() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataMulta,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() => _dataMulta = picked);
    }
  }

  Future<void> _pickVencimento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _vencimento,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() => _vencimento = picked);
    }
  }

  void _clearForm() {
    _descricaoCtrl.clear();
    _valorCtrl.clear();
    _dataMulta = DateTime.now();
    _vencimento = DateTime.now().add(const Duration(days: 10));
  }

  Future<void> _salvarMulta() async {
    if (_saving) return;

    final vehicleId = _selectedVehicleId;
    if (vehicleId == null || vehicleId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um veículo.')),
      );
      return;
    }

    final descricao = _descricaoCtrl.text.trim();
    final valor = _toDouble(_valorCtrl.text);

    if (descricao.isEmpty || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe a descrição e o valor da multa.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final novo = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'vehicleId': vehicleId,
      'descricao': descricao,
      'valor': valor,
      'dataMulta': _dataMulta.toIso8601String(),
      'vencimento': _vencimento.toIso8601String(),
      'status': 'pendente',
      'dataPagamento': null,
    };

    _records.add(novo);
    _records.sort((a, b) {
      final da = _parseDate(a['dataMulta']) ?? DateTime(2100);
      final db = _parseDate(b['dataMulta']) ?? DateTime(2100);
      return db.compareTo(da);
    });

    await _saveRecords();

    if (!mounted) return;
    setState(() => _saving = false);

    _clearForm();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Multa cadastrada com sucesso.')),
    );
  }

  Future<void> _marcarComoPaga(String id) async {
    final index = _records.indexWhere((e) => (e['id'] ?? '').toString() == id);
    if (index == -1) return;

    _records[index] = {
      ..._records[index],
      'status': 'pago',
      'dataPagamento': DateTime.now().toIso8601String(),
    };

    await _saveRecords();

    if (!mounted) return;
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Multa marcada como paga.')),
    );
  }

  Future<void> _apagarMulta(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Apagar multa'),
        content: const Text('Deseja apagar este registro de multa?'),
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

    _records.removeWhere((e) => (e['id'] ?? '').toString() == id);
    await _saveRecords();

    if (!mounted) return;
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗑️ Multa apagada.')),
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
            _primaryColor.withOpacity(0.16),
            _softRed,
            Colors.white,
          ],
        ),
        border: Border.all(color: _primaryColor.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            color: _primaryColor.withOpacity(0.08),
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
              Icons.warning_amber_rounded,
              size: 32,
              color: _primaryColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Controle de Multas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Acompanhe multas, vencimentos, pagamentos e alertas por veículo.',
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

  Widget _statusCard({
    required IconData icon,
    required String title,
    required String value,
    required Color bg,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
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

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: _primaryColor) : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _primaryColor.withOpacity(0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primaryColor, width: 1.4),
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
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.6,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _formCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _primaryColor.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            color: _primaryColor.withOpacity(0.05),
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: _primaryColor),
              SizedBox(width: 8),
              Text(
                'Cadastrar multa',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedVehicleId,
            decoration: _inputDecoration(label: 'Veículo'),
            items: _vehicles.map((v) {
              final id = _vehicleIdFromMap(v);
              return DropdownMenuItem<String>(
                value: id,
                child: Text(_vehicleLabelFromMap(v)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedVehicleId = value);
            },
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDataMulta,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: _inputDecoration(
                label: 'Data da multa',
                icon: Icons.calendar_month_rounded,
              ),
              child: Text(_fmtDate(_dataMulta)),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickVencimento,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: _inputDecoration(
                label: 'Vencimento',
                icon: Icons.event_available_rounded,
              ),
              child: Text(_fmtDate(_vencimento)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descricaoCtrl,
            decoration: _inputDecoration(
              label: 'Descrição',
              hint: 'Ex: avanço de sinal, excesso de velocidade...',
              icon: Icons.description_outlined,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valorCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration(
              label: 'Valor da multa',
              hint: 'Ex: 195,23',
              icon: Icons.attach_money_rounded,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: _saving ? null : _salvarMulta,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              _saving ? 'Salvando...' : 'Salvar multa',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _multaCard(Map<String, dynamic> item, ColorScheme cs) {
    final id = (item['id'] ?? '').toString();
    final vehicleLabel = _vehicleLabelById((item['vehicleId'] ?? '').toString());
    final descricao = (item['descricao'] ?? '').toString();
    final valor = _toDouble(item['valor']);
    final dataMulta = _parseDate(item['dataMulta']);
    final vencimento = _parseDate(item['vencimento']);
    final pago = _isPago(item);
    final vencida = _isVencida(item);
    final proxima = _venceEmBreve(item);

    Color bg = Colors.white;
    Color border = _primaryColor.withOpacity(0.12);
    Color statusColor = _primaryColor;

    String statusText = 'Pendente';
    if (pago) {
      bg = _softGreen;
      border = const Color(0xFF0F9D58).withOpacity(0.18);
      statusColor = const Color(0xFF0F9D58);
      statusText = 'Pago';
    } else if (vencida) {
      bg = _softRed;
      border = _primaryColor.withOpacity(0.22);
      statusColor = _primaryColor;
      statusText = 'Vencida';
    } else if (proxima) {
      bg = _softAmber;
      border = Colors.orange.withOpacity(0.22);
      statusColor = Colors.orange.shade800;
      statusText = 'Vence em breve';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  vehicleLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            descricao,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text('Valor: ${_fmtMoney(valor)}'),
          Text('Data: ${dataMulta != null ? _fmtDate(dataMulta) : '-'}'),
          Text('Vencimento: ${vencimento != null ? _fmtDate(vencimento) : '-'}'),
          const SizedBox(height: 12),
          if (!pago)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F9D58),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _marcarComoPaga(id),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Marcar paga'),
              ),
            ),
          if (!pago) const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _apagarMulta(id),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Apagar'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFFFBFB),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Multas',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loadAll,
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _statusCard(
                        icon: Icons.error_outline_rounded,
                        title: 'Vencidas',
                        value: '${_vencidas.length}',
                        bg: _softRed,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statusCard(
                        icon: Icons.access_time_rounded,
                        title: 'Vencem em breve',
                        value: '${_proximas.length}',
                        bg: _softAmber,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _statusCard(
                        icon: Icons.receipt_long_rounded,
                        title: 'Total pendente',
                        value: _fmtMoney(_totalPendente),
                        bg: _softBlue,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statusCard(
                        icon: Icons.calendar_month_rounded,
                        title: 'Total do mês',
                        value: _fmtMoney(_totalMes),
                        bg: _softGreen,
                        color: const Color(0xFF0F9D58),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _sectionTitle(
                  'Cadastro',
                  'Registre multas e acompanhe vencimentos e pagamentos.',
                  cs,
                ),
                const SizedBox(height: 12),
                _formCard(cs),
                const SizedBox(height: 18),
                _sectionTitle(
                  'Histórico do mês',
                  'Multas registradas no mês atual.',
                  cs,
                ),
                const SizedBox(height: 10),
                if (_historicoMesAtual.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _primaryColor.withOpacity(0.10)),
                    ),
                    child: const Text('Nenhuma multa registrada no mês atual.'),
                  )
                else
                  Column(
                    children:
                        _historicoMesAtual.map((e) => _multaCard(e, cs)).toList(),
                  ),
                const SizedBox(height: 18),
                _sectionTitle(
                  'Todas as multas',
                  'Use esta área para localizar e apagar multas antigas também.',
                  cs,
                ),
                const SizedBox(height: 10),
                if (_records.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _primaryColor.withOpacity(0.10)),
                    ),
                    child: const Text('Nenhuma multa cadastrada.'),
                  )
                else
                  Column(
                    children: _records.map((e) => _multaCard(e, cs)).toList(),
                  ),
              ],
            ),
    );
  }
}