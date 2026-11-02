import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../logic/defaults.dart';
import '../logic/filters.dart';
import '../models/action_def.dart';
import '../models/draft.dart';
import '../models/settings.dart';

/// Dove vengono letti/scritti i dati (file sul telefono, memoria nei test).
abstract class StorageBackend {
  Future<String?> read();
  Future<void> write(String data);
}

class MemoryBackend implements StorageBackend {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String d) async => data = d;
}

final _rand = Random();
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rand.nextInt(1 << 20).toRadixString(36)}';

/// Stato dell'app: bozze, azioni e impostazioni, salvate in un unico JSON.
class AppStore extends ChangeNotifier {
  AppStore(this.backend, {this.saveDelay = const Duration(milliseconds: 600)});

  final StorageBackend backend;
  final Duration saveDelay;

  final List<Draft> drafts = [];
  final List<ActionDef> actions = [];
  AppSettings settings = AppSettings();
  bool loaded = false;

  /// Cambia solo quando cambia il tema, così l'app intera non si ricostruisce
  /// a ogni lettera digitata.
  final ValueNotifier<AppTheme> themeNotifier = ValueNotifier(AppTheme.system);
  Timer? _saveTimer;

  Future<void> load() async {
    try {
      final raw = await backend.read();
      if (raw != null && raw.trim().isNotEmpty) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        drafts
          ..clear()
          ..addAll(((j['drafts'] as List?) ?? const [])
              .map((e) => Draft.fromJson(e as Map<String, dynamic>)));
        actions
          ..clear()
          ..addAll(((j['actions'] as List?) ?? const [])
              .map((e) => ActionDef.fromJson(e as Map<String, dynamic>)));
        settings = AppSettings.fromJson(
            (j['settings'] as Map<String, dynamic>?) ?? const {});
      }
    } catch (e) {
      debugPrint('Errore caricamento dati: $e');
    }
    if (actions.isEmpty) actions.addAll(defaultActions());
    _purgeOldTrash();
    themeNotifier.value = settings.theme;
    loaded = true;
    notifyListeners();
  }

  String toJsonString() => const JsonEncoder.withIndent(' ').convert({
        'version': 1,
        'drafts': drafts.where((d) => !d.isEmpty).map((d) => d.toJson()).toList(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'settings': settings.toJson(),
      });

  /// Ripristina da un backup JSON (sostituisce tutto).
  void importJsonString(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final ds = ((j['drafts'] as List?) ?? const [])
        .map((e) => Draft.fromJson(e as Map<String, dynamic>))
        .toList();
    final acts = ((j['actions'] as List?) ?? const [])
        .map((e) => ActionDef.fromJson(e as Map<String, dynamic>))
        .toList();
    final existing = drafts.map((d) => d.id).toSet();
    drafts.addAll(ds.where((d) => !existing.contains(d.id)));
    final existingA = actions.map((a) => a.id).toSet();
    actions.addAll(acts.where((a) => !existingA.contains(a.id)));
    changed();
  }

  /// Da chiamare dopo ogni modifica: avvisa la UI e salva poco dopo.
  void changed() {
    notifyListeners();
    persist();
  }

  /// Salva poco dopo senza avvisare la UI.
  void persist() {
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, flush);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    try {
      await backend.write(toJsonString());
    } catch (e) {
      debugPrint('Errore salvataggio: $e');
    }
  }

  // ---------- Bozze ----------

  Draft createDraft([String text = '']) {
    final d = Draft(id: newId(), text: text);
    drafts.add(d);
    changed();
    return d;
  }

  Draft? byId(String id) {
    for (final d in drafts) {
      if (d.id == id) return d;
    }
    return null;
  }

  void updateText(Draft d, String text) {
    if (d.text == text) return;
    d.text = text;
    d.modified = DateTime.now();
    changed();
  }

  void moveTo(Draft d, DraftFolder f) {
    d.folder = f;
    d.modified = DateTime.now();
    changed();
  }

  void toggleFlag(Draft d) {
    d.flagged = !d.flagged;
    changed();
  }

  void addTag(Draft d, String raw) {
    final t = normalizeTag(raw);
    if (t.isEmpty || d.tags.contains(t)) return;
    d.tags.add(t);
    changed();
  }

  void removeTag(Draft d, String t) {
    d.tags.remove(t);
    changed();
  }

  void deleteForever(Draft d) {
    drafts.remove(d);
    changed();
  }

  void emptyTrash() {
    drafts.removeWhere((d) => d.folder == DraftFolder.trash);
    changed();
  }

  /// Le bozze vuote non si salvano; quelle nel cestino da oltre 30 giorni spariscono.
  void _purgeOldTrash() {
    final limit = DateTime.now().subtract(const Duration(days: 30));
    drafts.removeWhere((d) =>
        d.isEmpty || (d.folder == DraftFolder.trash && d.modified.isBefore(limit)));
  }

  // ---------- Azioni ----------

  void saveAction(ActionDef a) {
    final i = actions.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      actions[i] = a;
    } else {
      actions.add(a);
    }
    changed();
  }

  void deleteAction(ActionDef a) {
    actions.removeWhere((x) => x.id == a.id);
    changed();
  }

  void reorderAction(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final a = actions.removeAt(oldIndex);
    actions.insert(newIndex, a);
    changed();
  }

  void restoreDefaultActions() {
    final ids = actions.map((a) => a.id).toSet();
    actions.addAll(defaultActions().where((a) => !ids.contains(a.id)));
    changed();
  }

  void updateSettings(void Function(AppSettings s) f) {
    f(settings);
    themeNotifier.value = settings.theme;
    changed();
  }
}
