import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PortariaScreen extends StatefulWidget {
  const PortariaScreen({super.key});

  @override
  State<PortariaScreen> createState() => _PortariaScreenState();
}

class _PortariaScreenState extends State<PortariaScreen> {
  static const String _vehiclesKey = 'veiculos_v1';
  static const String _portariaKey = 'portaria_records_v1';

  static const Color _primaryColor = Color(0xFF546E7A);
  static const Color _softColor = Color(0xFFF1F6F8);
  static const Color _softBlue = Color(0xFFEFF6FF);
  static const Color _softGreen = Color(0xFFEEF9F1);
  static const Color _softAmber = Color(0xFFFFF8E8);
  static const Color _softRed = Color(0xFFFFF1F2);

  final _motoristaCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();
  final _kmSaidaCtrl = TextEditingController();
  final _kmChegadaCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _records = [];

  String? _selectedVehicleId;
  String? _selectedOpenTripId;

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _motoristaCtrl.dispose();
    _destinoCtrl.dispose();
    _kmSaidaCtrl.dispose();
    _kmChegadaCtrl.dispose();
    _obsCtrl.dispose();
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

    final rawRecords = prefs.getString(_portariaKey);
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
      final da = _parseDate(a['dataSaida']) ?? DateTime(2000);
      final db = _parseDate(b['dataSaida']) ?? DateTime(2000);
      return db.compareTo(da);
    });

    String? selectedVehicleId = _selectedVehicleId;
    if (selectedVehicleId == null && vehicles.isNotEmpty) {
      selectedVehicleId = _vehicleIdFromMap(vehicles.first);
    }

    String? selectedOpenTripId = _selectedOpenTripId;
    final openTrips = records.where((e) => !_isFinalizado(e)).toList();
    if ((selectedOpenTripId == null || selectedOpenTripId.isEmpty) &&
        openTrips.isNotEmpty) {
      selectedOpenTripId = (openTrips.first['id'] ?? '').toString();
    }

    if (!mounted) return;
    setState(() {
      _vehicles = vehicles;
      _records = records;
      _selectedVehicleId = selectedVehicleId;
      _selectedOpenTripId = selectedOpenTripId;
      _loading = false;
    });
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_portariaKey, jsonEncode(_records));
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

  bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  bool _isFinalizado(Map<String, dynamic> item) {
    return (item['status'] ?? '').toString() == 'finalizado';
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

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  String _fmtDateTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '${_fmtDate(d)} $hh:$min';
  }

  String _fmtKm(double v) {
    return '${v.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  List<Map<String, dynamic>> get _emRota =>
      _records.where((e) => !_isFinalizado(e)).toList();

  List<Map<String, dynamic>> get _historicoMesAtual {
    final now = DateTime.now();
    return _records.where((e) {
      final dt = _parseDate(e['dataSaida']);
      if (dt == null) return false;
      return _sameMonth(dt, now);
    }).toList();
  }

  int get _totalEmRota => _emRota.length;

  int get _totalFinalizadosMes =>
      _historicoMesAtual.where((e) => _isFinalizado(e)).length;

  double get _kmTotalMes {
    double total = 0.0;
    for (final item in _historicoMesAtual) {
      total += _toDouble(item['kmRodado']);
    }
    return total;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _clearSaidaForm() {
    _motoristaCtrl.clear();
    _destinoCtrl.clear();
    _kmSaidaCtrl.clear();
    _obsCtrl.clear();
    _selectedDate = DateTime.now();
  }

  void _clearChegadaForm() {
    _kmChegadaCtrl.clear();
  }

  Future<void> _registrarSaida() async {
    if (_saving) return;

    final vehicleId = _selectedVehicleId;
    if (vehicleId == null || vehicleId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um veículo.')),
      );
      return;
    }

    final kmSaida = _toDouble(_kmSaidaCtrl.text);
    if (kmSaida <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o KM de saída.')),
      );
      return;
    }

    final motorista = _motoristaCtrl.text.trim();
    final destino = _destinoCtrl.text.trim();

    if (motorista.isEmpty || destino.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe motorista e destino.')),
      );
      return;
    }

    final jaEmRota = _emRota.any(
      (e) => (e['vehicleId'] ?? '').toString() == vehicleId,
    );

    if (jaEmRota) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este veículo já possui uma saída aberta em rota.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final dataSaida = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      DateTime.now().hour,
      DateTime.now().minute,
    );

    final novo = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'vehicleId': vehicleId,
      'motorista': motorista,
      'destino': destino,
      'observacao': _obsCtrl.text.trim(),
      'kmSaida': kmSaida,
      'kmChegada': null,
      'kmRodado': 0.0,
      'dataSaida': dataSaida.toIso8601String(),
      'dataChegada': null,
      'status': 'em_rota',
    };

    _records.insert(0, novo);
    await _saveRecords();

    if (!mounted) return;
    setState(() {
      _selectedOpenTripId = novo['id']?.toString();
      _saving = false;
    });

    _clearSaidaForm();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Saída registrada com sucesso.')),
    );
  }

  Future<void> _registrarChegada() async {
    if (_saving) return;

    final tripId = _selectedOpenTripId;
    if (tripId == null || tripId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma viagem em rota.')),
      );
      return;
    }

    final kmChegada = _toDouble(_kmChegadaCtrl.text);
    if (kmChegada <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o KM de chegada.')),
      );
      return;
    }

    final index = _records.indexWhere((e) => (e['id'] ?? '').toString() == tripId);
    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viagem não encontrada.')),
      );
      return;
    }

    final item = _records[index];
    final kmSaida = _toDouble(item['kmSaida']);
    if (kmChegada < kmSaida) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O KM de chegada não pode ser menor que o KM de saída.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final kmRodado = kmChegada - kmSaida;
    _records[index] = {
      ...item,
      'kmChegada': kmChegada,
      'kmRodado': kmRodado,
      'dataChegada': DateTime.now().toIso8601String(),
      'status': 'finalizado',
    };

    await _saveRecords();

    final openTrips = _records.where((e) => !_isFinalizado(e)).toList();

    if (!mounted) return;
    setState(() {
      _selectedOpenTripId =
          openTrips.isNotEmpty ? (openTrips.first['id'] ?? '').toString() : null;
      _saving = false;
    });

    _clearChegadaForm();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Chegada registrada com sucesso.')),
    );
  }

  Future<void> _apagarRegistro(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Apagar registro'),
        content: const Text('Deseja apagar este registro da portaria?'),
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

    final openTrips = _records.where((e) => !_isFinalizado(e)).toList();

    if (!mounted) return;
    setState(() {
      _selectedOpenTripId =
          openTrips.isNotEmpty ? (openTrips.first['id'] ?? '').toString() : null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗑️ Registro apagado.')),
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
            _primaryColor.withOpacity(0.18),
            _softColor,
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
              Icons.security_rounded,
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
                  'Controle de Portaria',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Registre saída, chegada e histórico operacional dos veículos.',
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

  Widget _saidaFormCard(ColorScheme cs) {
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
              Icon(Icons.logout_rounded, color: _primaryColor),
              SizedBox(width: 8),
              Text(
                'Registrar saída',
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
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: _inputDecoration(
                label: 'Data da saída',
                icon: Icons.calendar_month_rounded,
              ),
              child: Text(_fmtDate(_selectedDate)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motoristaCtrl,
            decoration: _inputDecoration(
              label: 'Motorista',
              icon: Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _destinoCtrl,
            decoration: _inputDecoration(
              label: 'Destino',
              icon: Icons.location_on_outlined,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _kmSaidaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration(
              label: 'KM de saída',
              hint: 'Ex: 125000',
              icon: Icons.speed_outlined,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _obsCtrl,
            maxLines: 2,
            decoration: _inputDecoration(
              label: 'Observação (opcional)',
              icon: Icons.note_alt_outlined,
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
            onPressed: _saving ? null : _registrarSaida,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              _saving ? 'Salvando...' : 'Salvar saída',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chegadaFormCard(ColorScheme cs) {
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
              Icon(Icons.login_rounded, color: _primaryColor),
              SizedBox(width: 8),
              Text(
                'Registrar chegada',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedOpenTripId,
            decoration: _inputDecoration(label: 'Viagem em rota'),
            items: _emRota.map((item) {
              final id = (item['id'] ?? '').toString();
              final label =
                  '${_vehicleLabelById((item['vehicleId'] ?? '').toString())} • ${item['destino'] ?? '-'}';
              return DropdownMenuItem<String>(
                value: id,
                child: Text(label),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedOpenTripId = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _kmChegadaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration(
              label: 'KM de chegada',
              hint: 'Ex: 125130',
              icon: Icons.route_outlined,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F9D58),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: _emRota.isEmpty || _saving ? null : _registrarChegada,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              _saving ? 'Salvando...' : 'Salvar chegada',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rotaCard(Map<String, dynamic> item, ColorScheme cs) {
    final saida = _parseDate(item['dataSaida']);
    final label = _vehicleLabelById((item['vehicleId'] ?? '').toString());
    final motorista = (item['motorista'] ?? '').toString();
    final destino = (item['destino'] ?? '').toString();
    final kmSaida = _toDouble(item['kmSaida']);
    final id = (item['id'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softAmber,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.orange.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text('Motorista: $motorista'),
          Text('Destino: $destino'),
          Text('Saída: ${saida != null ? _fmtDateTime(saida) : '-'}'),
          Text('KM saída: ${_fmtKm(kmSaida)}'),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _apagarRegistro(id),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Apagar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historicoCard(Map<String, dynamic> item, ColorScheme cs) {
    final label = _vehicleLabelById((item['vehicleId'] ?? '').toString());
    final motorista = (item['motorista'] ?? '').toString();
    final destino = (item['destino'] ?? '').toString();
    final saida = _parseDate(item['dataSaida']);
    final chegada = _parseDate(item['dataChegada']);
    final kmSaida = _toDouble(item['kmSaida']);
    final kmChegada = _toDouble(item['kmChegada']);
    final kmRodado = _toDouble(item['kmRodado']);
    final obs = (item['observacao'] ?? '').toString().trim();
    final id = (item['id'] ?? '').toString();

    final finalizado = _isFinalizado(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: finalizado ? _softGreen : _softBlue,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: finalizado
              ? const Color(0xFF0F9D58).withOpacity(0.18)
              : Colors.blue.withOpacity(0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: finalizado
                      ? const Color(0xFF0F9D58).withOpacity(0.14)
                      : Colors.orange.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  finalizado ? 'Finalizado' : 'Em rota',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: finalizado
                        ? const Color(0xFF0F9D58)
                        : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Motorista: $motorista'),
          Text('Destino: $destino'),
          Text('Saída: ${saida != null ? _fmtDateTime(saida) : '-'}'),
          Text('Chegada: ${chegada != null ? _fmtDateTime(chegada) : '-'}'),
          Text('KM saída: ${_fmtKm(kmSaida)}'),
          Text('KM chegada: ${kmChegada > 0 ? _fmtKm(kmChegada) : '-'}'),
          Text('KM rodado: ${kmRodado > 0 ? _fmtKm(kmRodado) : '-'}'),
          if (obs.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Obs: $obs',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _apagarRegistro(id),
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
      backgroundColor: const Color(0xFFF9FBFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF9FBFC),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Portaria',
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
                        icon: Icons.local_shipping_outlined,
                        title: 'Em rota',
                        value: '$_totalEmRota',
                        bg: _softAmber,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statusCard(
                        icon: Icons.check_circle_outline_rounded,
                        title: 'Finalizados no mês',
                        value: '$_totalFinalizadosMes',
                        bg: _softGreen,
                        color: const Color(0xFF0F9D58),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _statusCard(
                  icon: Icons.route_outlined,
                  title: 'KM total rodado no mês',
                  value: _fmtKm(_kmTotalMes),
                  bg: _softBlue,
                  color: Colors.blue,
                ),
                const SizedBox(height: 18),
                _sectionTitle(
                  'Movimentação',
                  'Registre saída e chegada dos veículos.',
                  cs,
                ),
                const SizedBox(height: 12),
                _saidaFormCard(cs),
                const SizedBox(height: 12),
                _chegadaFormCard(cs),
                const SizedBox(height: 18),
                _sectionTitle(
                  'Veículos em rota',
                  'Saídas abertas aguardando chegada.',
                  cs,
                ),
                const SizedBox(height: 10),
                if (_emRota.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _primaryColor.withOpacity(0.10)),
                    ),
                    child: const Text('Nenhum veículo em rota no momento.'),
                  )
                else
                  Column(
                    children: _emRota.map((e) => _rotaCard(e, cs)).toList(),
                  ),
                const SizedBox(height: 18),
                _sectionTitle(
                  'Histórico do mês',
                  'Saídas e chegadas registradas no mês atual.',
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
                    child: const Text('Nenhum registro no mês atual.'),
                  )
                else
                  Column(
                    children:
                        _historicoMesAtual.map((e) => _historicoCard(e, cs)).toList(),
                  ),
              ],
            ),
    );
  }
}