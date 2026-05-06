import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyPrice {
  final double value;
  final double changePercent;
  final String? name;
  final bool fromCache;

  CurrencyPrice({
    required this.value,
    required this.changePercent,
    this.name,
    this.fromCache = false,
  });

  Map<String, dynamic> toJson() => {
        'value': value,
        'changePercent': changePercent,
        'name': name,
      };

  factory CurrencyPrice.fromJson(Map<String, dynamic> json) => CurrencyPrice(
        value: (json['value'] as num?)?.toDouble() ?? 0.0,
        changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0.0,
        name: json['name']?.toString(),
        fromCache: true,
      );
}

class CurrencyData {
  final CurrencyPrice? dolar;
  final CurrencyPrice? euro;
  final DateTime? ultimaAtualizacao;
  final bool offline;

  CurrencyData({
    this.dolar,
    this.euro,
    this.ultimaAtualizacao,
    this.offline = false,
  });
}

// Mantém o nome FuelPriceService pra não quebrar os imports do widget
class FuelPriceService {
  static const String _kDolar = 'currency_dolar_v1';
  static const String _kEuro = 'currency_euro_v1';
  static const String _kUltima = 'currency_ultima_v1';

  /// Busca as cotações em tempo real (Dólar e Euro)
  static Future<CurrencyData> buscarCotacoes() async {
    CurrencyPrice? dolar;
    CurrencyPrice? euro;
    bool offline = false;

    // Tenta buscar os 2 de uma vez (mais eficiente)
    try {
      final response = await http
          .get(Uri.parse(
              'https://economia.awesomeapi.com.br/json/last/USD-BRL,EUR-BRL'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          // Dólar
          final usd = decoded['USDBRL'];
          if (usd is Map<String, dynamic>) {
            final bid = double.tryParse(usd['bid']?.toString() ?? '') ?? 0.0;
            final pct =
                double.tryParse(usd['pctChange']?.toString() ?? '') ?? 0.0;
            if (bid > 0) {
              dolar = CurrencyPrice(
                value: bid,
                changePercent: pct,
                name: 'Dólar Americano',
              );
              await _salvarCache(_kDolar, dolar);
            }
          }

          // Euro
          final eur = decoded['EURBRL'];
          if (eur is Map<String, dynamic>) {
            final bid = double.tryParse(eur['bid']?.toString() ?? '') ?? 0.0;
            final pct =
                double.tryParse(eur['pctChange']?.toString() ?? '') ?? 0.0;
            if (bid > 0) {
              euro = CurrencyPrice(
                value: bid,
                changePercent: pct,
                name: 'Euro',
              );
              await _salvarCache(_kEuro, euro);
            }
          }
        }
      }
    } catch (_) {
      offline = true;
    }

    // Se falhou, tenta carregar do cache
    dolar ??= await _carregarCache(_kDolar);
    euro ??= await _carregarCache(_kEuro);

    if (dolar == null || euro == null) offline = true;

    final agora = DateTime.now();
    if (!offline) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUltima, agora.toIso8601String());
    }

    return CurrencyData(
      dolar: dolar,
      euro: euro,
      ultimaAtualizacao: agora,
      offline: offline,
    );
  }

  static Future<CurrencyData> carregarDoCache() async {
    final dolar = await _carregarCache(_kDolar);
    final euro = await _carregarCache(_kEuro);

    final prefs = await SharedPreferences.getInstance();
    final ultimaStr = prefs.getString(_kUltima);
    DateTime? ultima;
    if (ultimaStr != null) {
      try {
        ultima = DateTime.parse(ultimaStr);
      } catch (_) {}
    }

    return CurrencyData(
      dolar: dolar,
      euro: euro,
      ultimaAtualizacao: ultima,
      offline: true,
    );
  }

  static Future<void> _salvarCache(String chave, CurrencyPrice preco) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(chave, jsonEncode(preco.toJson()));
  }

  static Future<CurrencyPrice?> _carregarCache(String chave) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(chave);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CurrencyPrice.fromJson(decoded);
      }
    } catch (_) {}

    return null;
  }
}