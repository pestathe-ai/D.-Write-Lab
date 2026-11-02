import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/filters.dart';
import '../models/draft.dart';

/// Aggiunge o toglie i tag di una bozza.
Future<void> showTagsSheet(BuildContext context, AppStore store, Draft draft) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _TagsSheet(store: store, draft: draft),
  );
}

class _TagsSheet extends StatefulWidget {
  const _TagsSheet({required this.store, required this.draft});
  final AppStore store;
  final Draft draft;

  @override
  State<_TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends State<_TagsSheet> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _add() {
    widget.store.addTag(widget.draft, _c.text);
    _c.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final others = allTags(widget.store.drafts).where((t) => !d.tags.contains(t)).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tag', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Nuovo tag',
              prefixText: '#',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: _add),
            ),
            onSubmitted: (_) => _add(),
          ),
          const SizedBox(height: 12),
          if (d.tags.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in d.tags)
                  InputChip(
                    label: Text('#$t'),
                    onDeleted: () => setState(() => widget.store.removeTag(d, t)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (others.isNotEmpty) ...[
            Text('Già usati', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in others)
                  ActionChip(
                    label: Text('#$t'),
                    onPressed: () => setState(() => widget.store.addTag(d, t)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
