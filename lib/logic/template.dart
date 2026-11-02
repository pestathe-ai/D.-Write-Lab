import '../models/draft.dart';

/// Contesto usato per riempire i segnaposto di un modello.
class TemplateContext {
  TemplateContext({
    required this.draft,
    this.selection = '',
    DateTime? now,
  }) : now = now ?? DateTime.now();

  final Draft draft;
  final String selection;
  final DateTime now;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Valori disponibili. Nomi italiani e inglesi sono equivalenti.
Map<String, String> templateValues(TemplateContext c) {
  final d = c.draft;
  final n = c.now;
  final sel = c.selection.isEmpty ? d.text : c.selection;
  final values = <String, String>{
    'bozza': d.text,
    'titolo': d.title,
    'corpo': d.body,
    'selezione': sel,
    'data': '${_two(n.day)}/${_two(n.month)}/${n.year}',
    'data_iso': '${n.year}-${_two(n.month)}-${_two(n.day)}',
    'ora': '${_two(n.hour)}:${_two(n.minute)}',
    'tag': d.tags.join(', '),
    'parole': d.wordCount.toString(),
    'caratteri': d.text.length.toString(),
  };
  const aliases = {
    'draft': 'bozza',
    'testo': 'bozza',
    'title': 'titolo',
    'body': 'corpo',
    'selection': 'selezione',
    'date': 'data_iso',
    'time': 'ora',
    'tags': 'tag',
    'words': 'parole',
  };
  aliases.forEach((alias, key) => values[alias] = values[key]!);
  return values;
}

final _tagPattern = RegExp(r'\[\[\s*([a-zA-Z_]+)\s*\]\]');

/// Sostituisce i segnaposto `[[nome]]`. Quelli sconosciuti restano com'erano.
/// Con [urlEncode] i valori vengono codificati per l'uso in un link.
String renderTemplate(
  String template,
  TemplateContext context, {
  bool urlEncode = false,
}) {
  final values = templateValues(context);
  return template.replaceAllMapped(_tagPattern, (m) {
    final key = m.group(1)!.toLowerCase();
    final v = values[key];
    if (v == null) return m.group(0)!;
    return urlEncode ? Uri.encodeComponent(v) : v;
  });
}

/// Elenco mostrato nell'editor delle azioni.
const templateHelp = <String, String>{
  '[[bozza]]': 'tutto il testo',
  '[[titolo]]': 'la prima riga',
  '[[corpo]]': 'tutto tranne la prima riga',
  '[[selezione]]': 'il testo selezionato (o tutto)',
  '[[data]]': 'data di oggi, es. 02/11/2026',
  '[[data_iso]]': 'data, es. 2026-11-02',
  '[[ora]]': 'ora, es. 15:20',
  '[[tag]]': 'i tag della bozza',
  '[[parole]]': 'numero di parole',
};

/// Mailto con oggetto = prima riga e corpo = resto.
Uri buildMailto(String text) {
  final lines = text.split('\n');
  final subject = lines.first.trim();
  final body = lines.length > 1 ? lines.sublist(1).join('\n').trim() : '';
  // Uri(queryParameters:) codifica gli spazi con "+", che molte app mail
  // mostrano così com'è: costruiamo la query a mano con %20.
  final q = 'subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}';
  return Uri.parse('mailto:?$q');
}
