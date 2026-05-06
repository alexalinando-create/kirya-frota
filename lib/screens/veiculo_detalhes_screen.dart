import 'package:flutter/material.dart';

class VeiculoDetalhesScreen extends StatelessWidget {
  final Map<String, dynamic> vehicle;

  const VeiculoDetalhesScreen({
    super.key,
    required this.vehicle,
  });

  String _s(dynamic v) => (v ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final placa = _s(vehicle['placa']);
    final modelo = _s(vehicle['modelo']);

    return Scaffold(
      appBar: AppBar(
        title: Text(placa.isEmpty ? 'Detalhes do Veículo' : placa),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Placa: ${placa.isEmpty ? "-" : placa}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Modelo: ${modelo.isEmpty ? "-" : modelo}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('ID: ${_s(vehicle['id']).isEmpty ? "-" : _s(vehicle['id'])}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Consumo: ${_s(vehicle['consumo']).isEmpty ? "-" : _s(vehicle['consumo'])}',
                    style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}