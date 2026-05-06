import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrintResult {
  final bool sucesso;
  final String mensagem;
  PrintResult({required this.sucesso, required this.mensagem});
}

class VoucherData {
  final String empresa;
  final String veiculoLabel;
  final String motorista;
  final DateTime data;
  final double kmAtual;
  final double distanciaTotalKm;
  final double litros;
  final double precoLitro;
  final double custoTotal;
  final double valorNota;
  final double? precoTanque;
  final int numeroVale;

  VoucherData({
    required this.empresa,
    required this.veiculoLabel,
    required this.motorista,
    required this.data,
    required this.kmAtual,
    required this.distanciaTotalKm,
    required this.litros,
    required this.precoLitro,
    required this.custoTotal,
    required this.valorNota,
    this.precoTanque,
    required this.numeroVale,
  });
}

class VoucherPrintService {
  static const String _valeKey     = 'numero_vale';
  static const int    _valeInicial = 3127;

  // Retorna o próximo número e já incrementa
  static Future<int> proximoNumeroVale() async {
    final prefs  = await SharedPreferences.getInstance();
    final atual  = prefs.getInt(_valeKey) ?? _valeInicial;
    await prefs.setInt(_valeKey, atual + 1);
    return atual;
  }

  // Apenas consulta sem incrementar (para exibir na tela se quiser)
  static Future<int> verNumeroVale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_valeKey) ?? _valeInicial;
  }

  static Future<bool> bluetoothLigado() async {
    try { return await PrintBluetoothThermal.bluetoothEnabled; }
    catch (_) { return false; }
  }

  static Future<List<BluetoothInfo>> listarImpressoras() async {
    try { return await PrintBluetoothThermal.pairedBluetooths; }
    catch (_) { return []; }
  }

  static Future<bool> estaConectado() async {
    try { return await PrintBluetoothThermal.connectionStatus; }
    catch (_) { return false; }
  }

  static Future<bool> conectar(String macAddress) async {
    try {
      // Desconecta antes de tentar conectar — resolve erro na segunda impressão
      final jaConectado = await PrintBluetoothThermal.connectionStatus;
      if (jaConectado) {
        await PrintBluetoothThermal.disconnect;
        await Future.delayed(const Duration(milliseconds: 600));
      }
      return await PrintBluetoothThermal.connect(
          macPrinterAddress: macAddress);
    } catch (_) { return false; }
  }

  static Future<void> desconectar() async {
    try { await PrintBluetoothThermal.disconnect; } catch (_) {}
  }

  // Remove acentos para impressora térmica não quebrar
  static String _semAcento(String s) {
    const origem  = 'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖØòóôõöøÙÚÛÜùúûüÇçÑñ';
    const destino = 'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOOooooooUUUUuuuuCcNn';
    final buffer  = StringBuffer();
    for (final c in s.runes) {
      final char = String.fromCharCode(c);
      final idx  = origem.indexOf(char);
      buffer.write(idx >= 0 ? destino[idx] : char);
    }
    return buffer.toString();
  }

  static Future<PrintResult> imprimirVoucher({
    required BluetoothInfo impressora,
    required VoucherData voucher,
  }) async {
    try {
      final conectado = await conectar(impressora.macAdress);
      if (!conectado) {
        return PrintResult(sucesso: false,
            mensagem: 'Nao foi possivel conectar na impressora.');
      }

      final profile   = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      final nomeEmpresa = _semAcento(voucher.empresa.toUpperCase());

      bytes += generator.text('================================',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(nomeEmpresa,
          styles: const PosStyles(align: PosAlign.center, bold: true,
              height: PosTextSize.size2, width: PosTextSize.size2));
      bytes += generator.text('VOUCHER DE ABASTECIMENTO',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text(
          'Vale No: ${voucher.numeroVale}',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('================================',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);

      bytes += generator.text('Data: ${_fmtData(voucher.data)}',
          styles: const PosStyles(bold: true));
      bytes += generator.text('Hora: ${_fmtHora(voucher.data)}');
      bytes += generator.feed(1);

      bytes += generator.text('Veiculo: ${_semAcento(voucher.veiculoLabel)}',
          styles: const PosStyles(bold: true));
      bytes += generator.text(
          'Motorista: ${voucher.motorista.isEmpty ? "_______________________" : _semAcento(voucher.motorista)}');
      bytes += generator.text('--------------------------------');

      bytes += generator.text('KM atual: ${_fmtInt(voucher.kmAtual)}');
      bytes += generator.text(
          'Distancia: ${_fmt2(voucher.distanciaTotalKm)} km (ida e volta)');
      bytes += generator.text('Litros: ${_fmt2(voucher.litros)} L');
      bytes += generator.text('Preco/L: ${_money(voucher.precoLitro)}');

      bytes += generator.text('--------------------------------');

      bytes += generator.text('CUSTO TOTAL:',
          styles: const PosStyles(bold: true));
      bytes += generator.text(_money(voucher.custoTotal),
          styles: const PosStyles(align: PosAlign.right, bold: true,
              height: PosTextSize.size2, width: PosTextSize.size2));
      bytes += generator.feed(1);

      bytes += generator.text('================================',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(2);

      bytes += generator.text('CARIMBO / ASSINATURA',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.feed(4);
      bytes += generator.text('________________________________');
      bytes += generator.feed(1);
      bytes += generator.text('________________________________');
      bytes += generator.feed(2);

      bytes += generator.text('Documento gerado pelo',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(_semAcento(voucher.empresa),
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text(
          '${_fmtData(DateTime.now())} ${_fmtHora(DateTime.now())}',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('================================',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(3);

      final resultado = await PrintBluetoothThermal.writeBytes(bytes);

      return resultado
          ? PrintResult(sucesso: true, mensagem: 'Voucher impresso!')
          : PrintResult(sucesso: false,
              mensagem: 'Erro ao enviar para impressora.');
    } catch (e) {
      return PrintResult(sucesso: false, mensagem: 'Erro: $e');
    }
  }

  static String _fmtData(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/'
      '${d.month.toString().padLeft(2,'0')}/${d.year}';

  static String _fmtHora(DateTime d) =>
      '${d.hour.toString().padLeft(2,'0')}:'
      '${d.minute.toString().padLeft(2,'0')}';

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
}