import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/action_def.dart';
import 'action_editor_screen.dart';

/// Elenco delle azioni: riordina, modifica, aggiungi.
class ActionsManageScreen extends StatelessWidget {
  const ActionsManageScreen({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Azioni'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'restore') {
                  store.restoreDefaultActions();
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Azioni predefinite ripristinate')));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'restore', child: Text('Ripristina azioni predefinite')),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ActionEditorScreen(store: store))),
          icon: const Icon(Icons.add),
          label: const Text('Nuova azione'),
        ),
        body: SafeArea(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: store.actions.length,
            onReorder: store.reorderAction,
            itemBuilder: (context, i) {
              final a = store.actions[i];
              return ListTile(
                key: ValueKey(a.id),
                leading: Text(a.icon, style: const TextStyle(fontSize: 24)),
                title: Text(a.name),
                subtitle: Text(actionKindLabels[a.kind]!),
                trailing: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle),
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ActionEditorScreen(store: store, action: a))),
              );
            },
          ),
        ),
      ),
    );
  }
}
