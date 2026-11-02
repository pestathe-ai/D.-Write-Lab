/// Cosa fa un'azione.
enum ActionKind {
  copy, // copia il risultato negli appunti
  share, // apre il menu Condividi di Android
  email, // apre la mail con oggetto = riga 1 del risultato
  url, // apre un link; i segnaposto vengono codificati per URL
  replace, // sostituisce il testo della bozza
  append, // aggiunge in fondo alla bozza
  newDraft, // crea una nuova bozza
  transform, // trasformazione di testo integrata
  ai, // manda il prompt all'AI
}

/// Dove va il risultato di un'azione AI.
enum AiOutput { replace, append, newDraft, show, copy }

class ActionDef {
  ActionDef({
    required this.id,
    required this.name,
    required this.kind,
    this.template = '[[bozza]]',
    this.transformId = '',
    this.aiOutput = AiOutput.show,
    this.icon = '⚡',
    this.builtIn = false,
    this.archiveAfter = false,
  });

  final String id;
  String name;
  ActionKind kind;

  /// Modello con segnaposto, es. "[[titolo]] – [[data]]".
  String template;

  /// Solo per [ActionKind.transform].
  String transformId;

  /// Solo per [ActionKind.ai].
  AiOutput aiOutput;

  String icon;
  bool builtIn;

  /// Sposta la bozza in Archivio dopo l'azione.
  bool archiveAfter;

  ActionDef copyWith({String? id, bool? builtIn, String? name}) => ActionDef(
        id: id ?? this.id,
        name: name ?? this.name,
        kind: kind,
        template: template,
        transformId: transformId,
        aiOutput: aiOutput,
        icon: icon,
        builtIn: builtIn ?? this.builtIn,
        archiveAfter: archiveAfter,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'template': template,
        'transformId': transformId,
        'aiOutput': aiOutput.name,
        'icon': icon,
        'builtIn': builtIn,
        'archiveAfter': archiveAfter,
      };

  factory ActionDef.fromJson(Map<String, dynamic> j) => ActionDef(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'Azione',
        kind: ActionKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => ActionKind.copy,
        ),
        template: (j['template'] as String?) ?? '[[bozza]]',
        transformId: (j['transformId'] as String?) ?? '',
        aiOutput: AiOutput.values.firstWhere(
          (k) => k.name == j['aiOutput'],
          orElse: () => AiOutput.show,
        ),
        icon: (j['icon'] as String?) ?? '⚡',
        builtIn: (j['builtIn'] as bool?) ?? false,
        archiveAfter: (j['archiveAfter'] as bool?) ?? false,
      );
}

/// Etichette italiane per l'interfaccia.
const actionKindLabels = <ActionKind, String>{
  ActionKind.copy: 'Copia negli appunti',
  ActionKind.share: 'Condividi',
  ActionKind.email: 'Invia per email',
  ActionKind.url: 'Apri link / app',
  ActionKind.replace: 'Sostituisci la bozza',
  ActionKind.append: 'Aggiungi in fondo',
  ActionKind.newDraft: 'Crea nuova bozza',
  ActionKind.transform: 'Trasforma il testo',
  ActionKind.ai: 'Chiedi all\'AI',
};

const aiOutputLabels = <AiOutput, String>{
  AiOutput.show: 'Mostra il risultato',
  AiOutput.replace: 'Sostituisci la bozza',
  AiOutput.append: 'Aggiungi in fondo',
  AiOutput.newDraft: 'Crea nuova bozza',
  AiOutput.copy: 'Copia negli appunti',
};
