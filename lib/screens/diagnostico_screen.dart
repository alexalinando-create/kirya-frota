import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiagnosticoScreen extends StatefulWidget {
  const DiagnosticoScreen({super.key});

  @override
  State<DiagnosticoScreen> createState() => _DiagnosticoScreenState();
}

class _DiagnosticoScreenState extends State<DiagnosticoScreen> {
  List<String> _linhas = ['Clique em CARREGAR para começar'];
  bool _loading = false;

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _linhas = ['⏳ Carregando...'];
    });

    List<String> resultado = [];

    try {
      final prefs = await SharedPreferences.getInstance();
      final chaves = prefs.getKeys().toList()..sort();

      resultado.add('✅ Total de chaves: ${chaves.length}');
      resultado.add('');

      for (final chave in chaves) {
        resultado.add('━━━━━━━━━━━━━━━━━━━━━━');
        resultado.add('🔑 $chave');

        try {
          final s = prefs.getString(chave);
          if (s != null) {
            resultado.add('TIPO: String');
            resultado.add('TAMANHO: ${s.length} caracteres');
            if (s.length > 500) {
              resultado.add('VALOR (primeiros 500):');
              resultado.add(s.substring(0, 500));
              resultado.add('... (truncado)');
            } else {
              resultado.add('VALOR:');
              resultado.add(s);
            }
            continue;
          }
        } catch (_) {}

        try {
          final b = prefs.getBool(chave);
          if (b != null) {
            resultado.add('TIPO: Bool');
            resultado.add('VALOR: $b');
            continue;
          }
        } catch (_) {}

        try {
          final i = prefs.getInt(chave);
          if (i != null) {
            resultado.add('TIPO: Int');
            resultado.add('VALOR: $i');
            continue;
          }
        } catch (_) {}

        try {
          final d = prefs.getDouble(chave);
          if (d != null) {
            resultado.add('TIPO: Double');
            resultado.add('VALOR: $d');
            continue;
          }
        } catch (_) {}

        resultado.add('TIPO: Desconhecido');
      }
    } catch (e) {
      resultado.add('❌ ERRO: $e');
    }

    setState(() {
      _linhas = resultado;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔬 Diagnóstico Simples'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _carregar,
                icon: const Icon(Icons.refresh),
                label: Text(_loading ? 'Carregando...' : 'CARREGAR DADOS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                child: SelectableText(
                  _linhas.join('\n'),
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}