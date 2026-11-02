import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/template.dart';
import '../logic/transforms.dart';
import '../models/action_def.dart';

/// Crea o modifica un'azione personalizzata.
class ActionEditorScreen extends StatefulWidget {
  const ActionEditorScreen({super.key, required this.store, this.action});
  final AppStore store;
  final ActionDef? action;

  @override
  State<ActionEditorScreen> createState() => _ActionEditorScreenState();
}

class _ActionEditorScreenState extends State<ActionEditorScreen> {
  late final ActionDef a;
  late final TextEditingController _name;
  late final TextEditingController _icon;
  late final TextEditingController _tpl;
  bool get _isNew => widget.action == null;

  @override
  void initState() {
    super.initState();
    // Lavoriamo su una copia: si salva solo con "Salva".
    a = widget.action?.copyWith() ??
        ActionDef(id: newId(), name: '', kind: ActionKind.copy, icon: '⚡');
    _name = TextEditingController(text: a.name);
    _icon = TextEditingController(text: a.icon);
    _tpl = TextEditingController(text: a.template);
  }

  @override
  void dispose() {
    _name.dispose();
    _icon.dispose();
    _tpl.dispose();
    super.dispose();
  }

  bool get _usesTemplate => a.kind != ActionKind.transform;

  String get _templateHint => switch (a.kind) {
        ActionKind.url => 'Es. https://wa.me/?text=[[bozza]]',
        ActionKind.ai => 'Es. Riassumi in 3 punti:\n\n[[bozza]]',
        ActionKind.email => 'Prima riga = oggetto, il resto = testo',
        _ => 'Es. [[titolo]] – [[data]]',
      };

  void _insert(String tag) {
    final sel = _tpl.selection;
    final t = _tpl.text;
    final start = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    _tpl.value = TextEditingValue(
      text: t.replaceRange(start, end, tag),
      selection: TextSelection.collapsed(offset: start + tag.length),
    );
  }

  void _save() {
    a
      ..name = _name.text.trim().isEmpty ? 'Azione' : _name.text.trim()
      ..icon = _icon.text.trim().isEmpty ? '⚡' : _icon.text.trim().characters.take(2).toString()
      ..template = _tpl.text;
    if (a.kind == ActionKind.transform && a.transformId.isEmpty) {
      a.transformId = textTransforms.first.id;
    }
    widget.store.saveAction(a);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Eliminare "${a.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Elimina')),
        ],
      ),
    );
    if (ok == true && mounted) {
      widget.store.deleteAction(a);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nuova azione' : 'Modifica azione'),
        actions: [
          if (!_isNew)
            IconButton(tooltip: 'Elimina', onPressed: _delete, icon: const Icon(Icons.delete_outline)),
          IconButton(tooltip: 'Duplica', onPressed: _isNew ? null : () {
            final copy = a.copyWith(id: newId(), builtIn: false, name: '${_name.text} (copia)');
            widget.store.saveAction(copy);
            Navigator.pop(context);
          }, icon: const Icon(Icons.copy_all_outlined)),
          TextButton(onPressed: _save, child: const Text('Salva')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _icon,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                    decoration: const InputDecoration(labelText: 'Icona', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ActionKind>(
              initialValue: a.kind,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Cosa fa', border: OutlineInputBorder()),
              items: [
                for (final k in ActionKind.values)
                  DropdownMenuItem(value: k, child: Text(actionKindLabels[k]!)),
              ],
              onChanged: (k) => setState(() => a.kind = k ?? a.kind),
            ),
            const SizedBox(height: 16),
            if (a.kind == ActionKind.transform)
              DropdownButtonFormField<String>(
                initialValue: transformById(a.transformId)?.id ?? textTransforms.first.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Trasformazione', border: OutlineInputBorder()),
                items: [
                  for (final t in textTransforms) DropdownMenuItem(value: t.id, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() => a.transformId = v ?? a.transformId),
              ),
            if (a.kind == ActionKind.transform)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Se selezioni una parte del testo, si applica solo a quella.',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              ),
            if (a.kind == ActionKind.ai) ...[
              DropdownButtonFormField<AiOutput>(
                initialValue: a.aiOutput,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Con la risposta…', border: OutlineInputBorder()),
                items: [
                  for (final o in AiOutput.values) DropdownMenuItem(value: o, child: Text(aiOutputLabels[o]!)),
                ],
                onChanged: (v) => setState(() => a.aiOutput = v ?? a.aiOutput),
              ),
              const SizedBox(height: 16),
            ],
            if (_usesTemplate) ...[
              TextField(
                controller: _tpl,
                minLines: 3,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: a.kind == ActionKind.ai ? 'Prompt' : 'Modello',
                  hintText: _templateHint,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text('Tocca per inserire:', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in templateHelp.entries)
                    Tooltip(
                      message: e.value,
                      child: ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(e.key),
                        onPressed: () => _insert(e.key),
                      ),
                    ),
                ],
              ),
              if (a.kind == ActionKind.url)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Nei link i segnaposto vengono codificati in automatico. Funzionano anche gli schemi delle app (es. tel:, sms:, geo:).',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Archivia la bozza dopo'),
              value: a.archiveAfter,
              onChanged: (v) => setState(() => a.archiveAfter = v),
            ),
          ],
        ),
      ),
    );
  }
}
