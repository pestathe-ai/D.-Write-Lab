/// Trasformazioni di testo integrate (pura logica, testabile).
class TextTransform {
  const TextTransform(this.id, this.label, this.apply);
  final String id;
  final String label;
  final String Function(String) apply;
}

List<String> _lines(String s) => s.split('\n');

String _titleCase(String s) => s.replaceAllMapped(
      RegExp(r"(^|[\s\-'(])(\p{L})", unicode: true),
      (m) => '${m.group(1)}${m.group(2)!.toUpperCase()}',
    );

String _sortLines(String s, {bool reverse = false}) {
  final l = _lines(s)
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return (reverse ? l.reversed : l).join('\n');
}

String _dedupe(String s) {
  final seen = <String>{};
  return _lines(s).where((l) => l.trim().isEmpty || seen.add(l.trim())).join('\n');
}

final _bulletPrefix = RegExp(r'^\s*(?:[-*•]\s+(?:\[[ xX]\]\s+)?|\d+[.)]\s+)');

String _strip(String l) => l.replaceFirst(_bulletPrefix, '');

String _mapNonEmpty(String s, String Function(String line, int i) f) {
  var i = 0;
  return _lines(s).map((l) => l.trim().isEmpty ? l : f(_strip(l), ++i)).join('\n');
}

final List<TextTransform> textTransforms = [
  TextTransform('upper', 'MAIUSCOLO', (s) => s.toUpperCase()),
  TextTransform('lower', 'minuscolo', (s) => s.toLowerCase()),
  const TextTransform('title', 'Iniziali Maiuscole', _titleCase),
  TextTransform('sort', 'Ordina righe A→Z', (s) => _sortLines(s)),
  TextTransform('sort_desc', 'Ordina righe Z→A', (s) => _sortLines(s, reverse: true)),
  TextTransform('reverse', 'Inverti ordine righe', (s) => _lines(s).reversed.join('\n')),
  const TextTransform('dedupe', 'Togli righe duplicate', _dedupe),
  TextTransform('no_blank', 'Togli righe vuote',
      (s) => _lines(s).where((l) => l.trim().isNotEmpty).join('\n')),
  TextTransform('trim_spaces', 'Togli spazi doppi',
      (s) => _lines(s).map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim()).join('\n')),
  TextTransform('bullets', 'Elenco puntato', (s) => _mapNonEmpty(s, (l, _) => '- $l')),
  TextTransform('numbers', 'Elenco numerato', (s) => _mapNonEmpty(s, (l, i) => '$i. $l')),
  TextTransform('checklist', 'Lista di controllo', (s) => _mapNonEmpty(s, (l, _) => '- [ ] $l')),
  TextTransform('unlist', 'Togli elenchi', (s) => _lines(s).map(_strip).join('\n')),
  TextTransform('one_line', 'Unisci in una riga',
      (s) => _lines(s).map((l) => l.trim()).where((l) => l.isNotEmpty).join(' ')),
];

TextTransform? transformById(String id) {
  for (final t in textTransforms) {
    if (t.id == id) return t;
  }
  return null;
}

/// Spunta o toglie la spunta a "- [ ]" sulla riga [lineIndex].
String toggleChecklistLine(String text, int lineIndex) {
  final l = _lines(text);
  if (lineIndex < 0 || lineIndex >= l.length) return text;
  final line = l[lineIndex];
  if (line.contains('- [ ]')) {
    l[lineIndex] = line.replaceFirst('- [ ]', '- [x]');
  } else if (RegExp(r'- \[[xX]\]').hasMatch(line)) {
    l[lineIndex] = line.replaceFirst(RegExp(r'- \[[xX]\]'), '- [ ]');
  }
  return l.join('\n');
}
