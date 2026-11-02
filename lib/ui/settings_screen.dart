import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/store.dart';
import '../logic/filters.dart';
import '../models/settings.dart';
import '../services/ai.dart';
import 'actions_manage_screen.dart';
import 'theme.dart';

class _Preset {
  const _Preset(this.label, this.url, this.model);
  final String label;
  final String url;
  final String model;
}

const _presets = [
  _Preset('OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini'),
  _Preset('OpenRouter', 'https://openrouter.ai/api/v1', 'openai/gpt-4o-mini'),
  _Preset('Groq', 'https://api.groq.com/openai/v1', 'llama-3.3-70b-versatile'),
  _Preset('Ollama (PC)', 'http://192.168.1.10:11434/v1', 'llama3.2'),
  _Preset('OmniRoute (PC)', 'http://192.168.1.10:20128/v1', 'auto'),
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppStore get store => widget.store;
  AppSettings get s => store.settings;
  late final _url = TextEditingController(text: s.aiBaseUrl);
  late final _key = TextEditingController(text: s.aiKey);
  late final _model = TextEditingController(text: s.aiModel);
  bool _showKey = false;
  bool _testing = false;

  @override
  void dispose() {
    _saveAi();
    _url.dispose();
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  /// Non avvisa la UI: può essere chiamato anche in dispose().
  void _saveAi() {
    s
      ..aiBaseUrl = _url.text.trim()
      ..aiKey = _key.text.trim()
      ..aiModel = _model.text.trim();
    store.persist();
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _testAi() async {
    _saveAi();
    setState(() => _testing = true);
    try {
      final r = await askAi(s, 'Rispondi solo con la parola: funziona');
      _snack('Risposta: $r');
    } on AiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _shareFile(String name, String content) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsString(content);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], subject: name));
  }

  String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}';
  }

  Future<void> _import() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ripristina backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Incolla qui il contenuto del file di backup (.json). Le bozze già presenti restano.'),
            const SizedBox(height: 12),
            TextField(controller: c, maxLines: 6, decoration: const InputDecoration(border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ripristina')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      store.importJsonString(c.text);
      _snack('Backup ripristinato');
    } catch (e) {
      _snack('Backup non valido');
    }
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(t, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _section('Aspetto'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in AppTheme.values)
                    ChoiceChip(
                      label: Text(appThemeLabels[t]!),
                      selected: s.theme == t,
                      onSelected: (_) => setState(() => store.updateSettings((x) => x.theme = t)),
                    ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Dimensione testo'),
              subtitle: Slider(
                value: s.fontSize,
                min: 13,
                max: 30,
                divisions: 17,
                label: s.fontSize.round().toString(),
                onChanged: (v) => setState(() => store.updateSettings((x) => x.fontSize = v)),
              ),
            ),
            ListTile(
              title: const Text('Interlinea'),
              subtitle: Slider(
                value: s.lineHeight,
                min: 1.1,
                max: 2.0,
                divisions: 9,
                label: s.lineHeight.toStringAsFixed(1),
                onChanged: (v) => setState(() => store.updateSettings((x) => x.lineHeight = v)),
              ),
            ),
            SwitchListTile(
              title: const Text('Carattere a larghezza fissa'),
              subtitle: const Text('Comodo per elenchi e codice'),
              value: s.monospace,
              onChanged: (v) => setState(() => store.updateSettings((x) => x.monospace = v)),
            ),
            _section('Comportamento'),
            SwitchListTile(
              title: const Text('Apri su una bozza vuota'),
              subtitle: const Text('All\'avvio e dopo 2 minuti di assenza'),
              value: s.newDraftOnOpen,
              onChanged: (v) => setState(() => store.updateSettings((x) => x.newDraftOnOpen = v)),
            ),
            ListTile(
              leading: const Icon(Icons.bolt_rounded),
              title: const Text('Gestisci azioni'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => ActionsManageScreen(store: store))),
            ),
            _section('Intelligenza artificiale'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Funziona con qualsiasi servizio compatibile con le API di OpenAI. La chiave resta solo su questo telefono.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in _presets)
                    ActionChip(
                      label: Text(p.label),
                      onPressed: () => setState(() {
                        _url.text = p.url;
                        _model.text = p.model;
                        _saveAi();
                      }),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Indirizzo API', border: OutlineInputBorder()),
                onEditingComplete: _saveAi,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _key,
                obscureText: !_showKey,
                decoration: InputDecoration(
                  labelText: 'Chiave API',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showKey = !_showKey),
                  ),
                ),
                onEditingComplete: _saveAi,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _model,
                decoration: const InputDecoration(labelText: 'Modello', border: OutlineInputBorder()),
                onEditingComplete: _saveAi,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _testAi,
                  icon: _testing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_tethering),
                  label: const Text('Prova connessione'),
                ),
              ),
            ),
            _section('Dati'),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Esporta tutte le bozze (Markdown)'),
              onTap: () => _shareFile('bozze-${_stamp()}.md', exportMarkdown(store.drafts)),
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Crea backup completo'),
              subtitle: const Text('Bozze, azioni e impostazioni (.json)'),
              onTap: () {
                store.flush();
                _shareFile('write-lab-backup-${_stamp()}.json', store.toJsonString());
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Ripristina backup'),
              onTap: _import,
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  const Text('D. Write Lab',
                      style: TextStyle(fontFamily: 'Sora', fontVariations: [FontVariation('wght', 800)], fontSize: 18, color: Brand.orange)),
                  const SizedBox(height: 4),
                  Text('un\'app Dom Studio', style: TextStyle(fontFamily: 'Sora', fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
