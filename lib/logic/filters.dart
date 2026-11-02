import '../models/draft.dart';

/// Le viste della lista.
enum DraftView { inbox, flagged, archive, trash, all }

const draftViewLabels = <DraftView, String>{
  DraftView.inbox: 'Inbox',
  DraftView.flagged: 'Preferiti',
  DraftView.archive: 'Archivio',
  DraftView.trash: 'Cestino',
  DraftView.all: 'Tutte',
};

bool _inView(Draft d, DraftView v) => switch (v) {
      DraftView.inbox => d.folder == DraftFolder.inbox,
      DraftView.flagged => d.flagged && d.folder != DraftFolder.trash,
      DraftView.archive => d.folder == DraftFolder.archive,
      DraftView.trash => d.folder == DraftFolder.trash,
      DraftView.all => d.folder != DraftFolder.trash,
    };

/// Filtra per vista, tag e testo; ordina dalla più recente.
/// La ricerca ignora maiuscole e accetta più parole (tutte devono esserci).
List<Draft> filterDrafts(
  Iterable<Draft> drafts, {
  DraftView view = DraftView.inbox,
  String query = '',
  String? tag,
}) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final out = drafts.where((d) {
    if (d.isEmpty) return false;
    if (!_inView(d, view)) return false;
    if (tag != null && !d.tags.contains(tag)) return false;
    if (words.isEmpty) return true;
    final hay = '${d.text}\n${d.tags.join(' ')}'.toLowerCase();
    return words.every(hay.contains);
  }).toList()
    ..sort((a, b) => b.modified.compareTo(a.modified));
  return out;
}

/// Tutti i tag usati, in ordine alfabetico.
List<String> allTags(Iterable<Draft> drafts) {
  final s = <String>{};
  for (final d in drafts) {
    if (d.folder != DraftFolder.trash) s.addAll(d.tags);
  }
  return s.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// Normalizza un tag scritto dall'utente: minuscolo, senza # e spazi ai lati.
String normalizeTag(String raw) =>
    raw.trim().replaceFirst(RegExp(r'^#+'), '').trim().toLowerCase();

/// Esporta tutte le bozze (non nel cestino) in un unico testo Markdown.
String exportMarkdown(Iterable<Draft> drafts) {
  final list = drafts.where((d) => !d.isEmpty && d.folder != DraftFolder.trash).toList()
    ..sort((a, b) => b.modified.compareTo(a.modified));
  final b = StringBuffer();
  for (final d in list) {
    b.writeln(d.text.trim());
    if (d.tags.isNotEmpty) b.writeln('\nTag: ${d.tags.map((t) => '#$t').join(' ')}');
    b.writeln('\n---\n');
  }
  return b.toString().trim();
}
