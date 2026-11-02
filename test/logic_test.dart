import 'dart:convert';

import 'package:d_write_lab/data/store.dart';
import 'package:d_write_lab/logic/defaults.dart';
import 'package:d_write_lab/logic/filters.dart';
import 'package:d_write_lab/logic/template.dart';
import 'package:d_write_lab/logic/transforms.dart';
import 'package:d_write_lab/models/action_def.dart';
import 'package:d_write_lab/models/draft.dart';
import 'package:d_write_lab/models/settings.dart';
import 'package:d_write_lab/services/ai.dart';
import 'package:flutter_test/flutter_test.dart';

Draft d(String text, {List<String>? tags, DraftFolder f = DraftFolder.inbox, bool flag = false, int minutesAgo = 0}) =>
    Draft(
      id: text.hashCode.toString(),
      text: text,
      tags: tags,
      folder: f,
      flagged: flag,
      modified: DateTime.now().subtract(Duration(minutes: minutesAgo)),
    );

void main() {
  group('Draft', () {
    test('titolo e corpo', () {
      final x = d('\n\n# Spesa\nlatte\npane');
      expect(x.title, 'Spesa');
      expect(x.body, 'latte\npane');
      expect(x.wordCount, 4);
    });
    test('bozza vuota', () {
      final x = d('   \n ');
      expect(x.isEmpty, isTrue);
      expect(x.title, '');
      expect(x.body, '');
      expect(x.wordCount, 0);
    });
    test('json andata e ritorno', () {
      final x = d('ciao', tags: ['a'], f: DraftFolder.archive, flag: true);
      final y = Draft.fromJson(jsonDecode(jsonEncode(x.toJson())) as Map<String, dynamic>);
      expect(y.text, 'ciao');
      expect(y.tags, ['a']);
      expect(y.folder, DraftFolder.archive);
      expect(y.flagged, isTrue);
    });
  });

  group('Modelli', () {
    final now = DateTime(2026, 11, 2, 9, 5);
    final ctx = TemplateContext(draft: d('Titolo\nriga uno', tags: ['lavoro', 'idee']), now: now);

    test('segnaposto italiani e inglesi', () {
      expect(renderTemplate('[[titolo]]|[[corpo]]|[[data]]|[[ora]]', ctx), 'Titolo|riga uno|02/11/2026|09:05');
      expect(renderTemplate('[[title]] [[date]] [[tags]]', ctx), 'Titolo 2026-11-02 lavoro, idee');
      expect(renderTemplate('[[ Bozza ]]', ctx), 'Titolo\nriga uno');
    });
    test('segnaposto sconosciuto resta', () {
      expect(renderTemplate('[[boh]] ok', ctx), '[[boh]] ok');
    });
    test('codifica per link', () {
      expect(renderTemplate('https://wa.me/?text=[[titolo]]&x=[[corpo]]', ctx, urlEncode: true),
          'https://wa.me/?text=Titolo&x=riga%20uno');
    });
    test('selezione vuota = tutto il testo', () {
      expect(renderTemplate('[[selezione]]', ctx), 'Titolo\nriga uno');
      final c2 = TemplateContext(draft: ctx.draft, selection: 'riga', now: now);
      expect(renderTemplate('[[selezione]]', c2), 'riga');
    });
    test('mailto', () {
      final u = buildMailto('Oggetto bello\nCiao Luca,\na presto');
      expect(u.scheme, 'mailto');
      expect(u.toString(), contains('subject=Oggetto%20bello'));
      expect(u.toString(), contains('body=Ciao%20Luca%2C%0Aa%20presto'));
    });
  });

  group('Trasformazioni', () {
    String t(String id, String s) => transformById(id)!.apply(s);

    test('maiuscolo / iniziali', () {
      expect(t('upper', 'ciao è'), 'CIAO È');
      expect(t('title', "l'ape va a roma"), "L'Ape Va A Roma");
    });
    test('ordina, inverti, duplicati', () {
      expect(t('sort', 'pera\nAglio\nmela'), 'Aglio\nmela\npera');
      expect(t('sort_desc', 'b\na\nc'), 'c\nb\na');
      expect(t('reverse', '1\n2\n3'), '3\n2\n1');
      expect(t('dedupe', 'a\nb\na\n\n\nb'), 'a\nb\n\n');
    });
    test('elenchi', () {
      expect(t('bullets', 'a\n\nb'), '- a\n\n- b');
      expect(t('numbers', '- a\n- b'), '1. a\n2. b');
      expect(t('checklist', '1. latte\npane'), '- [ ] latte\n- [ ] pane');
      expect(t('unlist', '- [x] fatto\n2) due\n• tre'), 'fatto\ndue\ntre');
    });
    test('spazi e righe', () {
      expect(t('trim_spaces', '  a   b \n c'), 'a b\nc');
      expect(t('no_blank', 'a\n\n \nb'), 'a\nb');
      expect(t('one_line', 'a\n b\n\nc'), 'a b c');
    });
    test('spunta lista', () {
      expect(toggleChecklistLine('- [ ] a\n- [ ] b', 1), '- [ ] a\n- [x] b');
      expect(toggleChecklistLine('- [X] a', 0), '- [ ] a');
      expect(toggleChecklistLine('x', 5), 'x');
    });
    test('tutte le azioni predefinite di tipo trasformazione esistono', () {
      for (final a in defaultActions().where((a) => a.kind == ActionKind.transform)) {
        expect(transformById(a.transformId), isNotNull, reason: a.name);
      }
    });
  });

  group('Filtri', () {
    final list = [
      d('Spesa\nlatte', tags: ['casa'], minutesAgo: 5),
      d('Riunione\nbudget Q4', tags: ['lavoro'], flag: true, minutesAgo: 1),
      d('Vecchia idea', f: DraftFolder.archive, minutesAgo: 50),
      d('Da buttare', f: DraftFolder.trash),
      d('   '),
    ];
    test('viste', () {
      expect(filterDrafts(list).map((x) => x.title), ['Riunione', 'Spesa']);
      expect(filterDrafts(list, view: DraftView.flagged).single.title, 'Riunione');
      expect(filterDrafts(list, view: DraftView.archive).single.title, 'Vecchia idea');
      expect(filterDrafts(list, view: DraftView.trash).single.title, 'Da buttare');
      expect(filterDrafts(list, view: DraftView.all).length, 3);
    });
    test('ricerca e tag', () {
      expect(filterDrafts(list, query: 'BUDGET riunione').single.title, 'Riunione');
      expect(filterDrafts(list, query: 'lavoro').single.title, 'Riunione');
      expect(filterDrafts(list, tag: 'casa').single.title, 'Spesa');
      expect(filterDrafts(list, query: 'niente'), isEmpty);
    });
    test('tag', () {
      expect(allTags(list), ['casa', 'lavoro']);
      expect(normalizeTag('  ##Lavoro '), 'lavoro');
    });
    test('export markdown', () {
      final md = exportMarkdown(list);
      expect(md, contains('Riunione'));
      expect(md, contains('Tag: #casa'));
      expect(md, isNot(contains('Da buttare')));
    });
  });

  group('AI', () {
    test('url', () {
      expect(chatCompletionsUri('https://api.openai.com/v1/').toString(),
          'https://api.openai.com/v1/chat/completions');
      expect(chatCompletionsUri('http://x:1/v1/chat/completions').toString(),
          'http://x:1/v1/chat/completions');
    });
    test('corpo richiesta', () {
      final b = buildChatBody(' gpt ', 'ciao');
      expect(b['model'], 'gpt');
      expect((b['messages'] as List).last, {'role': 'user', 'content': 'ciao'});
    });
    test('risposta', () {
      expect(parseChatResponse('{"choices":[{"message":{"content":" ok "}}]}'), 'ok');
      expect(parseChatResponse('{"choices":[{"message":{"content":[{"type":"text","text":"a"},{"text":"b"}]}}]}'), 'ab');
      expect(() => parseChatResponse('{"error":{"message":"chiave errata"}}'),
          throwsA(isA<AiException>().having((e) => e.message, 'm', 'chiave errata')));
      expect(() => parseChatResponse('{"choices":[]}'), throwsA(isA<AiException>()));
    });
    test('non configurata', () async {
      final s = AppSettings(aiBaseUrl: '', aiModel: '');
      expect(s.aiConfigured, isFalse);
      expect(() => askAi(s, 'x'), throwsA(isA<AiException>()));
    });
  });

  group('Archivio dati', () {
    test('salva, ricarica e scarta bozze vuote', () async {
      final mem = MemoryBackend();
      final a = AppStore(mem, saveDelay: Duration.zero);
      await a.load();
      expect(a.actions.length, defaultActions().length);
      final x = a.createDraft('Ciao\nmondo');
      a.createDraft('');
      a.addTag(x, '#Prova');
      a.toggleFlag(x);
      a.updateSettings((s) => s.theme = AppTheme.sepia);
      await a.flush();

      final b = AppStore(mem);
      await b.load();
      expect(b.drafts.length, 1);
      expect(b.drafts.single.tags, ['prova']);
      expect(b.drafts.single.flagged, isTrue);
      expect(b.settings.theme, AppTheme.sepia);
      expect(b.themeNotifier.value, AppTheme.sepia);
    });
    test('cestino vecchio svuotato al caricamento', () async {
      final mem = MemoryBackend();
      final old = Draft(id: 'o', text: 'vecchia', folder: DraftFolder.trash,
          modified: DateTime.now().subtract(const Duration(days: 40)));
      final fresh = Draft(id: 'f', text: 'nuova', folder: DraftFolder.trash);
      mem.data = jsonEncode({'drafts': [old.toJson(), fresh.toJson()]});
      final s = AppStore(mem);
      await s.load();
      expect(s.drafts.map((x) => x.id), ['f']);
    });
    test('import unisce senza duplicare', () async {
      final a = AppStore(MemoryBackend(), saveDelay: Duration.zero);
      await a.load();
      a.createDraft('uno');
      final backup = a.toJsonString();
      a.importJsonString(backup);
      expect(a.drafts.length, 1);
      a.drafts.clear();
      a.importJsonString(backup);
      expect(a.drafts.single.text, 'uno');
    });
    test('riordino e ripristino azioni', () async {
      final a = AppStore(MemoryBackend(), saveDelay: Duration.zero);
      await a.load();
      final first = a.actions.first.id;
      a.reorderAction(0, 3);
      expect(a.actions[2].id, first);
      a.deleteAction(a.actions.first);
      a.restoreDefaultActions();
      expect(a.actions.length, defaultActions().length);
    });
    test('azioni json', () {
      final x = ActionDef(id: 'i', name: 'n', kind: ActionKind.ai, aiOutput: AiOutput.newDraft, archiveAfter: true);
      final y = ActionDef.fromJson(jsonDecode(jsonEncode(x.toJson())) as Map<String, dynamic>);
      expect(y.kind, ActionKind.ai);
      expect(y.aiOutput, AiOutput.newDraft);
      expect(y.archiveAfter, isTrue);
    });
  });
}
