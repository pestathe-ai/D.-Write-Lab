import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/filters.dart';
import '../models/draft.dart';
import 'theme.dart';

/// Elenco delle bozze con viste, ricerca e tag. Restituisce la bozza scelta.
class DraftsListScreen extends StatefulWidget {
  const DraftsListScreen({super.key, required this.store, required this.currentId});
  final AppStore store;
  final String currentId;

  @override
  State<DraftsListScreen> createState() => _DraftsListScreenState();
}

class _DraftsListScreenState extends State<DraftsListScreen> {
  DraftView _view = DraftView.inbox;
  String _q = '';
  String? _tag;

  AppStore get store => widget.store;

  String _when(DateTime d) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '${two(d.hour)}:${two(d.minute)}';
    }
    if (d.year == now.year) return '${two(d.day)}/${two(d.month)}';
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  void _snack(String m, VoidCallback undo) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m),
        action: SnackBarAction(label: 'Annulla', onPressed: undo),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final tags = allTags(store.drafts);
        if (_tag != null && !tags.contains(_tag)) _tag = null;
        final list = filterDrafts(store.drafts, view: _view, query: _q, tag: _tag);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Bozze'),
            actions: [
              if (_view == DraftView.trash && list.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Svuotare il cestino?'),
                        content: const Text('Le bozze verranno eliminate per sempre.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
                          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Svuota')),
                        ],
                      ),
                    );
                    if (ok == true) store.emptyTrash();
                  },
                  child: const Text('Svuota'),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Cerca nelle bozze',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final v in DraftView.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(draftViewLabels[v]!),
                            selected: _view == v,
                            onSelected: (_) => setState(() => _view = v),
                          ),
                        ),
                    ],
                  ),
                ),
                if (tags.isNotEmpty)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final t in tags)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FilterChip(
                              label: Text('#$t'),
                              selected: _tag == t,
                              onSelected: (s) => setState(() => _tag = s ? t : null),
                            ),
                          ),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              _q.isNotEmpty || _tag != null
                                  ? 'Nessuna bozza trovata'
                                  : 'Qui non c\'è ancora niente',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                          itemBuilder: (context, i) => _tile(list[i], scheme),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'D. Write Lab · un\'app Dom Studio',
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 11,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tile(Draft d, ColorScheme scheme) {
    final inTrash = d.folder == DraftFolder.trash;
    final body = d.body.replaceAll(RegExp(r'\s+'), ' ');

    // Scorri a destra: archivia (o ripristina). A sinistra: cestino (o elimina).
    final rightLabel = inTrash || d.folder == DraftFolder.archive ? 'Ripristina' : 'Archivia';
    final leftLabel = inTrash ? 'Elimina' : 'Cestino';

    Widget bg(Color c, IconData icon, String label, Alignment a) => Container(
          color: c,
          alignment: a,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(icon, color: Colors.white), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white))],
          ),
        );

    return Dismissible(
      // La cartella fa parte della chiave: nelle viste "Tutte"/"Preferiti" la
      // bozza resta visibile dopo lo spostamento e serve un widget nuovo.
      key: ValueKey('${d.id}-${d.folder.name}'),
      background: bg(Brand.blue, Icons.archive_outlined, rightLabel, Alignment.centerLeft),
      secondaryBackground: bg(Colors.red.shade700, Icons.delete_outline, leftLabel, Alignment.centerRight),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.endToStart && inTrash) {
          return await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Eliminare per sempre?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Elimina')),
                  ],
                ),
              ) ??
              false;
        }
        return true;
      },
      onDismissed: (dir) {
        final old = d.folder;
        if (dir == DismissDirection.startToEnd) {
          final to = old == DraftFolder.inbox ? DraftFolder.archive : DraftFolder.inbox;
          store.moveTo(d, to);
          _snack(to == DraftFolder.archive ? 'Archiviata' : 'Ripristinata', () => store.moveTo(d, old));
        } else if (inTrash) {
          store.deleteForever(d);
        } else {
          store.moveTo(d, DraftFolder.trash);
          _snack('Nel cestino', () => store.moveTo(d, old));
        }
      },
      child: ListTile(
        selected: d.id == widget.currentId,
        title: Row(
          children: [
            if (d.flagged)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.star_rounded, size: 16, color: Brand.orange),
              ),
            Expanded(
              child: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Text(_when(d.modified), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body.isNotEmpty) Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (d.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(d.tags.map((t) => '#$t').join(' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: scheme.primary)),
              ),
          ],
        ),
        onTap: () {
          if (inTrash) store.moveTo(d, DraftFolder.inbox);
          Navigator.pop(context, d);
        },
      ),
    );
  }
}
