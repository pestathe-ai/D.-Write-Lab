import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/action_def.dart';
import 'action_editor_screen.dart';
import 'actions_manage_screen.dart';

/// Griglia di azioni. Restituisce l'azione scelta.
/// Tieni premuto su un'azione per modificarla.
Future<ActionDef?> showActionsSheet(BuildContext context, AppStore store) {
  return showModalBottomSheet<ActionDef>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ActionsSheet(store: store),
  );
}

class _ActionsSheet extends StatefulWidget {
  const _ActionsSheet({required this.store});
  final AppStore store;

  @override
  State<_ActionsSheet> createState() => _ActionsSheetState();
}

class _ActionsSheetState extends State<_ActionsSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final scheme = Theme.of(context).colorScheme;
    final h = MediaQuery.of(context).size.height;
    final list = store.actions
        .where((a) => _q.isEmpty || a.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: h * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Cerca azione',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _q = v),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gestisci azioni',
                    icon: const Icon(Icons.tune),
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ActionsManageScreen(store: store)));
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  mainAxisExtent: 92,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final a = list[i];
                  return Material(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.pop(context, a),
                      onLongPress: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ActionEditorScreen(store: store, action: a)));
                        if (mounted) setState(() {});
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(a.icon, style: const TextStyle(fontSize: 26)),
                            const SizedBox(height: 6),
                            Text(
                              a.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
