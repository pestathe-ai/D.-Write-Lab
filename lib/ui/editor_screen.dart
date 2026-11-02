import 'dart:async';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/action_def.dart';
import '../models/draft.dart';
import 'action_runner.dart';
import 'actions_sheet.dart';
import 'drafts_list_screen.dart';
import 'settings_screen.dart';
import 'tags_sheet.dart';
import 'theme.dart';

/// Schermata principale: una pagina pronta per scrivere.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WidgetsBindingObserver {
  AppStore get store => widget.store;
  late Draft draft;
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final List<String> _undo = [];
  final List<String> _redo = [];
  DateTime _lastSnapshot = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    draft = _initialDraft();
    _controller.text = draft.text;
    _controller.addListener(_onTextChanged);
  }

  Draft _initialDraft() {
    if (!store.settings.newDraftOnOpen) {
      final recent = store.drafts.where((d) => d.folder == DraftFolder.inbox && !d.isEmpty).toList()
        ..sort((a, b) => b.modified.compareTo(a.modified));
      if (recent.isNotEmpty) return recent.first;
    }
    return store.createDraft();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
      unawaited(store.flush());
    } else if (state == AppLifecycleState.resumed) {
      final away = _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      // Come in Drafts: dopo un po' di assenza riapri su una pagina bianca.
      if (store.settings.newDraftOnOpen && away > const Duration(minutes: 2) && !draft.isEmpty) {
        _open(store.createDraft());
      }
    }
  }

  void _onTextChanged() {
    final t = _controller.text;
    if (t == draft.text) return;
    final now = DateTime.now();
    if (now.difference(_lastSnapshot) > const Duration(seconds: 2)) {
      _pushUndo(draft.text);
      _lastSnapshot = now;
    }
    store.updateText(draft, t);
    setState(() {});
  }

  void _pushUndo(String t) {
    if (_undo.isNotEmpty && _undo.last == t) return;
    _undo.add(t);
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
  }

  void _setText(String t, {bool undoable = true}) {
    if (undoable) _pushUndo(draft.text);
    _lastSnapshot = DateTime.now();
    _controller.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
    store.updateText(draft, t);
    setState(() {});
  }

  void _undoAction() {
    if (_undo.isEmpty) return;
    _redo.add(draft.text);
    final t = _undo.removeLast();
    _controller.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
    store.updateText(draft, t);
    _lastSnapshot = DateTime.now();
    setState(() {});
  }

  void _redoAction() {
    if (_redo.isEmpty) return;
    _undo.add(draft.text);
    final t = _redo.removeLast();
    _controller.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
    store.updateText(draft, t);
    _lastSnapshot = DateTime.now();
    setState(() {});
  }

  void _open(Draft d) {
    // Una bozza vuota lasciata indietro non serve a nessuno.
    if (draft.isEmpty && draft.id != d.id) store.drafts.remove(draft);
    _controller.removeListener(_onTextChanged);
    setState(() {
      draft = d;
      _undo.clear();
      _redo.clear();
      _controller.value = TextEditingValue(
        text: d.text,
        selection: TextSelection.collapsed(offset: d.text.length),
      );
    });
    _controller.addListener(_onTextChanged);
  }

  void _newDraft() {
    if (draft.isEmpty) {
      _focus.requestFocus();
      return;
    }
    _open(store.createDraft());
    _focus.requestFocus();
  }

  void _snack(String msg, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), action: action, duration: const Duration(seconds: 3)));
  }

  void _moveAndNext(DraftFolder f, String label) {
    if (draft.isEmpty) return;
    final d = draft;
    final old = d.folder;
    store.moveTo(d, f);
    _open(store.createDraft());
    _snack(label,
        action: SnackBarAction(
          label: 'Annulla',
          onPressed: () {
            store.moveTo(d, old);
            _open(d);
          },
        ));
  }

  Future<void> _openList() async {
    _focus.unfocus();
    final picked = await Navigator.of(context).push<Draft>(
      MaterialPageRoute(builder: (_) => DraftsListScreen(store: store, currentId: draft.id)),
    );
    if (!mounted) return;
    if (picked != null) {
      _open(picked);
    } else if (store.byId(draft.id) == null) {
      _open(store.createDraft());
    } else {
      setState(() {});
    }
  }

  Future<void> _openActions() async {
    final sel = _controller.selection;
    _focus.unfocus();
    final action = await showActionsSheet(context, store);
    if (action == null || !mounted) return;
    await _run(action, sel);
  }

  Future<void> _run(ActionDef action, TextSelection sel) async {
    if (draft.isEmpty && action.kind != ActionKind.newDraft) {
      _snack('La bozza è vuota');
      return;
    }
    final outcome = await runAction(
      context,
      store,
      draft,
      action,
      selStart: sel.isValid ? sel.start : -1,
      selEnd: sel.isValid ? sel.end : -1,
    );
    if (!mounted) return;
    if (outcome.newText != null) _setText(outcome.newText!);
    if (action.archiveAfter && !draft.isEmpty) {
      store.moveTo(draft, DraftFolder.archive);
      _open(store.createDraft());
    }
    if (outcome.openDraft != null) _open(outcome.openDraft!);
    if (outcome.message != null) _snack(outcome.message!);
  }

  @override
  Widget build(BuildContext context) {
    final s = store.settings;
    final scheme = Theme.of(context).colorScheme;
    final inbox = store.drafts.where((d) => d.folder == DraftFolder.inbox && !d.isEmpty).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Bozze',
          onPressed: _openList,
          icon: Badge(
            isLabelVisible: inbox > 0,
            label: Text('$inbox'),
            backgroundColor: Brand.orange,
            child: const Icon(Icons.notes_rounded),
          ),
        ),
        title: Text(
          draft.isEmpty ? 'D. Write Lab' : '${draft.wordCount} parole',
          style: draft.isEmpty
              ? null
              : TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
        actions: [
          IconButton(
            tooltip: 'Annulla',
            onPressed: _undo.isEmpty ? null : _undoAction,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Ripeti',
            onPressed: _redo.isEmpty ? null : _redoAction,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            tooltip: draft.flagged ? 'Togli dai preferiti' : 'Preferito',
            onPressed: () => setState(() => store.toggleFlag(draft)),
            icon: Icon(draft.flagged ? Icons.star_rounded : Icons.star_outline_rounded,
                color: draft.flagged ? Brand.orange : null),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'tags':
                  await showTagsSheet(context, store, draft);
                  if (mounted) setState(() {});
                case 'settings':
                  await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SettingsScreen(store: store)));
                  if (mounted) setState(() {});
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'tags', child: Text('Tag')),
              PopupMenuItem(value: 'settings', child: Text('Impostazioni')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (draft.tags.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final t in draft.tags)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: Text('#$t'),
                          onPressed: () async {
                            await showTagsSheet(context, store, draft);
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: draft.isEmpty,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(
                  fontSize: s.fontSize,
                  height: s.lineHeight,
                  fontFamily: s.monospace ? 'monospace' : null,
                  color: scheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Scrivi qualcosa…',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                ),
              ),
            ),
            _BottomBar(
              onActions: _openActions,
              onArchive: draft.isEmpty ? null : () => _moveAndNext(DraftFolder.archive, 'Archiviata'),
              onTrash: draft.isEmpty ? null : () => _moveAndNext(DraftFolder.trash, 'Spostata nel cestino'),
              onNew: _newDraft,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onActions,
    required this.onArchive,
    required this.onTrash,
    required this.onNew,
  });

  final VoidCallback onActions;
  final VoidCallback? onArchive;
  final VoidCallback? onTrash;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: onActions,
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('Azioni'),
          ),
          IconButton(tooltip: 'Archivia', onPressed: onArchive, icon: const Icon(Icons.archive_outlined)),
          IconButton(tooltip: 'Cestina', onPressed: onTrash, icon: const Icon(Icons.delete_outline)),
          const Spacer(),
          Flexible(
            child: Text(
              'un\'app Dom Studio',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 11,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Nuova bozza',
            onPressed: onNew,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
