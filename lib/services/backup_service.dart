import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

class BackupResult {
  final bool sucesso;
  final String mensagem;
  final int? totalRestaurados;
  final String? dataBackup;

  BackupResult({
    required this.sucesso,
    required this.mensagem,
    this.totalRestaurados,
    this.dataBackup,
  });
}

class BackupInfo {
  final String caminho;
  final String nome;
  final DateTime dataModificacao;
  final int tamanhoBytes;

  BackupInfo({
    required this.caminho,
    required this.nome,
    required this.dataModificacao,
    required this.tamanhoBytes,
  });

  String get tamanhoFormatado {
    if (tamanhoBytes < 1024) return '$tamanhoBytes B';
    if (tamanhoBytes < 1024 * 1024) {
      return '${(tamanhoBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(tamanhoBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class BackupService {
  static const String _ultimoBackupKey = 'ultimo_backup_auto';
  static const String _backupFolder = 'AKFleetBackup';

  static Future<String> _gerarBackupJson() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    final Map<String, dynamic> dados = {};
    for (final key in keys) {
      final value = prefs.get(key);
      if (value is bool) {
        dados[key] = {'tipo': 'bool', 'valor': value};
      } else if (value is int) {
        dados[key] = {'tipo': 'int', 'valor': value};
      } else if (value is double) {
        dados[key] = {'tipo': 'double', 'valor': value};
      } else if (value is String) {
        dados[key] = {'tipo': 'String', 'valor': value};
      } else if (value is List<String>) {
        dados[key] = {'tipo': 'List<String>', 'valor': value};
      }
    }

    final backup = {
      'app': 'Gestor de Frota',
      'versao': '1.0',
      'dataBackup': DateTime.now().toIso8601String(),
      'totalChaves': dados.length,
      'dados': dados,
    };

    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  /// Restaura todos os dados a partir de um JSON de backup
  static Future<BackupResult> _restaurarDoJson(String jsonStr) async {
    try {
      // Validação básica
      if (jsonStr.trim().isEmpty) {
        return BackupResult(
          sucesso: false,
          mensagem: 'Arquivo está vazio. Tente baixar o backup novamente.',
        );
      }

      // Tenta decodificar
      dynamic decoded;
      try {
        decoded = jsonDecode(jsonStr);
      } catch (e) {
        return BackupResult(
          sucesso: false,
          mensagem: 'Arquivo não é um JSON válido. Verifique se você selecionou o arquivo correto.',
        );
      }

      if (decoded is! Map<String, dynamic>) {
        return BackupResult(
          sucesso: false,
          mensagem: 'Formato do arquivo está incorreto.',
        );
      }

      final dados = decoded['dados'];
      if (dados is! Map<String, dynamic>) {
        return BackupResult(
          sucesso: false,
          mensagem: 'Arquivo não contém a seção "dados".',
        );
      }

      final dataBackup = decoded['dataBackup']?.toString();

      final prefs = await SharedPreferences.getInstance();
      int restaurados = 0;
      int falhas = 0;

      for (final entry in dados.entries) {
        final key = entry.key;
        final info = entry.value;
        if (info is! Map) {
          falhas++;
          continue;
        }

        final tipo = info['tipo']?.toString();
        final valor = info['valor'];

        try {
          if (tipo == 'bool' && valor is bool) {
            await prefs.setBool(key, valor);
            restaurados++;
          } else if (tipo == 'int' && valor is int) {
            await prefs.setInt(key, valor);
            restaurados++;
          } else if (tipo == 'int' && valor is num) {
            await prefs.setInt(key, valor.toInt());
            restaurados++;
          } else if (tipo == 'double' && valor is num) {
            await prefs.setDouble(key, valor.toDouble());
            restaurados++;
          } else if (tipo == 'String' && valor is String) {
            await prefs.setString(key, valor);
            restaurados++;
          } else if (tipo == 'List<String>' && valor is List) {
            await prefs.setStringList(
              key,
              valor.map((e) => e.toString()).toList(),
            );
            restaurados++;
          } else {
            falhas++;
          }
        } catch (_) {
          falhas++;
        }
      }

      if (restaurados == 0) {
        return BackupResult(
          sucesso: false,
          mensagem: 'Nenhum dado foi restaurado. Verifique o arquivo de backup.',
        );
      }

      String msg = 'Backup restaurado com sucesso!';
      if (falhas > 0) {
        msg += ' ($falhas chaves ignoradas)';
      }

      return BackupResult(
        sucesso: true,
        mensagem: msg,
        totalRestaurados: restaurados,
        dataBackup: dataBackup,
      );
    } catch (e) {
      return BackupResult(
        sucesso: false,
        mensagem: 'Erro ao processar arquivo: $e',
      );
    }
  }

  /// Exporta o backup e abre o seletor pra compartilhar
  static Future<bool> exportarBackup() async {
    try {
      final json = await _gerarBackupJson();

      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${dir.path}/gestor_frota_backup_$timestamp.json');
      await file.writeAsString(json);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Backup do Gestor de Frota',
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Importa o backup escolhido pelo usuário
  /// MELHORADO: usa withData=true que funciona melhor em Android 13+
  static Future<BackupResult> importarBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true, // 🔑 KEY: força carregar bytes na memória
      );

      if (result == null || result.files.isEmpty) {
        return BackupResult(
          sucesso: false,
          mensagem: 'Nenhum arquivo selecionado.',
        );
      }

      final file = result.files.first;

      // Tenta primeiro pelos bytes (mais confiável)
      String? content;

      if (file.bytes != null && file.bytes!.isNotEmpty) {
        try {
          content = utf8.decode(file.bytes!);
        } catch (e) {
          // Se UTF-8 falhar, tenta latin-1
          try {
            content = String.fromCharCodes(file.bytes!);
          } catch (_) {}
        }
      }

      // Fallback: tenta pelo path
      if (content == null && file.path != null) {
        try {
          final f = File(file.path!);
          if (await f.exists()) {
            content = await f.readAsString();
          }
        } catch (_) {}
      }

      if (content == null || content.trim().isEmpty) {
        return BackupResult(
          sucesso: false,
          mensagem: 'Não foi possível ler o conteúdo do arquivo.\n\n'
              'Dica: tente mover o backup pra pasta "Downloads" do celular antes de importar.',
        );
      }

      return await _restaurarDoJson(content);
    } catch (e) {
      return BackupResult(
        sucesso: false,
        mensagem: 'Erro: $e',
      );
    }
  }

  /// Faz backup automático local em Documents/AKFleetBackup
  static Future<String?> fazerBackupAutomatico() async {
    try {
      final json = await _gerarBackupJson();

      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/$_backupFolder');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${dir.path}/auto_backup_$timestamp.json');
      await file.writeAsString(json);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ultimoBackupKey, DateTime.now().toIso8601String());

      final backups = await listarBackupsAutomaticos();
      if (backups.length > 5) {
        for (var i = 5; i < backups.length; i++) {
          try {
            await File(backups[i].caminho).delete();
          } catch (_) {}
        }
      }

      return file.path;
    } catch (_) {
      return null;
    }
  }

  static Future<List<BackupInfo>> listarBackupsAutomaticos() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/$_backupFolder');
      if (!await dir.exists()) return [];

      final files = await dir.list().toList();
      final backups = <BackupInfo>[];

      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.json')) {
          final stat = await entity.stat();
          backups.add(BackupInfo(
            caminho: entity.path,
            nome: entity.path.split(Platform.pathSeparator).last,
            dataModificacao: stat.modified,
            tamanhoBytes: stat.size,
          ));
        }
      }

      backups.sort((a, b) => b.dataModificacao.compareTo(a.dataModificacao));
      return backups;
    } catch (_) {
      return [];
    }
  }

  static Future<BackupResult> restaurarBackupAutomatico(String caminho) async {
    try {
      final file = File(caminho);
      if (!await file.exists()) {
        return BackupResult(
          sucesso: false,
          mensagem: 'Arquivo não encontrado.',
        );
      }
      final content = await file.readAsString();
      return await _restaurarDoJson(content);
    } catch (e) {
      return BackupResult(
        sucesso: false,
        mensagem: 'Erro: $e',
      );
    }
  }

  static Future<void> verificarBackupAutomatico() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ultimo = prefs.getString(_ultimoBackupKey);

      if (ultimo == null) {
        await fazerBackupAutomatico();
        return;
      }

      final ultimoDt = DateTime.tryParse(ultimo);
      if (ultimoDt == null) {
        await fazerBackupAutomatico();
        return;
      }

      final agora = DateTime.now();
      if (agora.difference(ultimoDt).inHours >= 24) {
        await fazerBackupAutomatico();
      }
    } catch (_) {}
  }
}