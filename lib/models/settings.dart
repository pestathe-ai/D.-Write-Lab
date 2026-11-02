enum AppTheme { system, light, dark, sepia }

const appThemeLabels = <AppTheme, String>{
  AppTheme.system: 'Come il telefono',
  AppTheme.light: 'Chiaro',
  AppTheme.dark: 'Scuro',
  AppTheme.sepia: 'Seppia',
};

class AppSettings {
  AppSettings({
    this.theme = AppTheme.system,
    this.fontSize = 18,
    this.monospace = false,
    this.lineHeight = 1.5,
    this.aiBaseUrl = 'https://api.openai.com/v1',
    this.aiKey = '',
    this.aiModel = 'gpt-4o-mini',
    this.newDraftOnOpen = true,
  });

  AppTheme theme;
  double fontSize;
  bool monospace;
  double lineHeight;

  /// Qualsiasi servizio compatibile con l'API OpenAI
  /// (OpenAI, OpenRouter, Groq, Ollama, OmniRoute…).
  String aiBaseUrl;
  String aiKey;
  String aiModel;

  /// All'apertura mostra una bozza vuota (come Drafts).
  bool newDraftOnOpen;

  bool get aiConfigured => aiBaseUrl.trim().isNotEmpty && aiModel.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'fontSize': fontSize,
        'monospace': monospace,
        'lineHeight': lineHeight,
        'aiBaseUrl': aiBaseUrl,
        'aiKey': aiKey,
        'aiModel': aiModel,
        'newDraftOnOpen': newDraftOnOpen,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        theme: AppTheme.values.firstWhere(
          (t) => t.name == j['theme'],
          orElse: () => AppTheme.system,
        ),
        fontSize: ((j['fontSize'] as num?) ?? 18).toDouble(),
        monospace: (j['monospace'] as bool?) ?? false,
        lineHeight: ((j['lineHeight'] as num?) ?? 1.5).toDouble(),
        aiBaseUrl: (j['aiBaseUrl'] as String?) ?? 'https://api.openai.com/v1',
        aiKey: (j['aiKey'] as String?) ?? '',
        aiModel: (j['aiModel'] as String?) ?? 'gpt-4o-mini',
        newDraftOnOpen: (j['newDraftOnOpen'] as bool?) ?? true,
      );
}
