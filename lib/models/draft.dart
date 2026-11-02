/// Una bozza di testo.
enum DraftFolder { inbox, archive, trash }

class Draft {
  Draft({
    required this.id,
    this.text = '',
    List<String>? tags,
    this.flagged = false,
    this.folder = DraftFolder.inbox,
    DateTime? created,
    DateTime? modified,
  })  : tags = tags ?? <String>[],
        created = created ?? DateTime.now(),
        modified = modified ?? created ?? DateTime.now();

  final String id;
  String text;
  List<String> tags;
  bool flagged;
  DraftFolder folder;
  final DateTime created;
  DateTime modified;

  /// Prima riga non vuota, senza simboli Markdown iniziali.
  String get title {
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isNotEmpty) {
        return t.replaceFirst(RegExp(r'^#+\s*'), '');
      }
    }
    return '';
  }

  /// Tutto quello che segue la prima riga non vuota.
  String get body {
    final lines = text.split('\n');
    var i = 0;
    while (i < lines.length && lines[i].trim().isEmpty) {
      i++;
    }
    if (i >= lines.length) return '';
    return lines.sublist(i + 1).join('\n').trim();
  }

  bool get isEmpty => text.trim().isEmpty;

  int get wordCount =>
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'tags': tags,
        'flagged': flagged,
        'folder': folder.name,
        'created': created.toIso8601String(),
        'modified': modified.toIso8601String(),
      };

  factory Draft.fromJson(Map<String, dynamic> j) => Draft(
        id: j['id'] as String,
        text: (j['text'] as String?) ?? '',
        tags: ((j['tags'] as List?) ?? const []).cast<String>().toList(),
        flagged: (j['flagged'] as bool?) ?? false,
        folder: DraftFolder.values.firstWhere(
          (f) => f.name == j['folder'],
          orElse: () => DraftFolder.inbox,
        ),
        created: DateTime.tryParse((j['created'] as String?) ?? ''),
        modified: DateTime.tryParse((j['modified'] as String?) ?? ''),
      );
}
