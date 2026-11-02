import 'package:flutter/material.dart';

enum AiResultChoice { replace, append, newDraft, copy }

/// Mostra la risposta dell'AI e chiede cosa farne.
Future<AiResultChoice?> showAiResultSheet(
  BuildContext context,
  String title,
  String result,
) {
  return showModalBottomSheet<AiResultChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final h = MediaQuery.of(ctx).size.height;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: h * 0.85),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: SelectableText(result,
                        style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(height: 1.5)),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, AiResultChoice.replace),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Sostituisci'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, AiResultChoice.append),
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Aggiungi'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, AiResultChoice.newDraft),
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text('Nuova bozza'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, AiResultChoice.copy),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copia'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
