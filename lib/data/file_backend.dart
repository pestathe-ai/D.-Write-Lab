import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'store.dart';

/// Salva tutto in `write_lab.json` nella cartella privata dell'app,
/// scrivendo prima su un file temporaneo per non perdere dati.
class FileBackend implements StorageBackend {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/write_lab.json');
  }

  @override
  Future<String?> read() async {
    final f = await _file();
    if (await f.exists()) return f.readAsString();
    final bak = File('${f.path}.bak');
    if (await bak.exists()) return bak.readAsString();
    return null;
  }

  @override
  Future<void> write(String data) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    if (await f.exists()) await f.copy('${f.path}.bak');
    await tmp.rename(f.path);
  }
}
