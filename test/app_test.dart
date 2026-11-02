import 'package:d_write_lab/data/store.dart';
import 'package:d_write_lab/main.dart';
import 'package:d_write_lab/models/draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppStore> _store() async {
  final s = AppStore(MemoryBackend(), saveDelay: Duration.zero);
  await s.load();
  return s;
}

void main() {
  testWidgets('scrivo, trasformo, annullo', (tester) async {
    final store = await _store();
    await tester.pumpWidget(WriteLabApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('D. Write Lab'), findsOneWidget);
    expect(find.text('un\'app Dom Studio'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'latte\npane\nlatte');
    await tester.pump();
    expect(find.text('3 parole'), findsOneWidget);

    await tester.tap(find.text('Azioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Togli duplicati'));
    await tester.pumpAndSettle();

    final draft = store.drafts.firstWhere((d) => !d.isEmpty);
    expect(draft.text, 'latte\npane');

    await tester.tap(find.byTooltip('Annulla'));
    await tester.pump();
    expect(draft.text, 'latte\npane\nlatte');
  });

  testWidgets('archivio, lista e ripristino', (tester) async {
    final store = await _store();
    await tester.pumpWidget(WriteLabApp(store: store));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Idea geniale\ncon dettagli');
    await tester.pump();
    await tester.tap(find.byTooltip('Archivia'));
    await tester.pump();
    expect(store.drafts.where((d) => d.folder == DraftFolder.archive).length, 1);

    await tester.tap(find.byTooltip('Bozze'));
    await tester.pumpAndSettle();
    expect(find.text('Qui non c\'è ancora niente'), findsOneWidget);
    await tester.tap(find.text('Archivio'));
    await tester.pumpAndSettle();
    expect(find.text('Idea geniale'), findsOneWidget);
    await tester.tap(find.text('Idea geniale'));
    await tester.pumpAndSettle();

    // Tornati all'editor con la bozza aperta.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Idea geniale\ncon dettagli');
  });

  testWidgets('impostazioni, editor azioni e gestione si aprono', (tester) async {
    final store = await _store();
    await tester.pumpWidget(WriteLabApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Impostazioni'));
    await tester.pumpAndSettle();
    expect(find.text('Aspetto'), findsOneWidget);

    await tester.tap(find.text('Seppia'));
    await tester.pumpAndSettle();
    expect(store.settings.theme.name, 'sepia');

    await tester.scrollUntilVisible(
      find.text('Gestisci azioni'),
      200,
      scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(find.text('Gestisci azioni'));
    await tester.pumpAndSettle();
    expect(find.text('Nuova azione'), findsOneWidget);
    await tester.tap(find.text('Nuova azione'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Prova mia');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    expect(store.actions.last.name, 'Prova mia');
  });
}
