import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/store.dart';
import '../logic/template.dart';
import '../logic/transforms.dart';
import '../models/action_def.dart';
import '../models/draft.dart';
import '../models/settings.dart';
import '../services/ai.dart';
import 'ai_result_sheet.dart';

/// Risultato di un'azione per l'editor.
class ActionOutcome {
  const ActionOutcome({this.newText, this.openDraft, this.message});

  /// Nuovo testo della bozza corrente (null = invariato).
  final String? newText;

  /// Bozza da aprire nell'editor (es. "Crea nuova bozza").
  final Draft? openDraft;
  final String? message;
}

/// Esegue un'azione. [selStart]/[selEnd] indicano la selezione nell'editor.
Future<ActionOutcome> runAction(
  BuildContext context,
  AppStore store,
  Draft draft,
  ActionDef action, {
  int selStart = -1,
  int selEnd = -1,
}) async {
  final text = draft.text;
  final hasSel = selStart >= 0 && selEnd > selStart && selEnd <= text.length;
  final selection = hasSel ? text.substring(selStart, selEnd) : '';
  final ctx = TemplateContext(draft: draft, selection: selection);
  String render({bool url = false}) =>
      renderTemplate(action.template, ctx, urlEncode: url);

  switch (action.kind) {
    case ActionKind.copy:
      await Clipboard.setData(ClipboardData(text: render()));
      return const ActionOutcome(message: 'Copiato negli appunti');

    case ActionKind.share:
      await SharePlus.instance.share(ShareParams(text: render(), subject: draft.title));
      return const ActionOutcome();

    case ActionKind.email:
      {
        final ok = await _launch(buildMailto(render()));
        return ActionOutcome(message: ok ? null : 'Nessuna app email trovata');
      }

    case ActionKind.url:
      {
        final uri = Uri.tryParse(render(url: true));
        if (uri == null) return const ActionOutcome(message: 'Link non valido');
        final ok = await _launch(uri);
        return ActionOutcome(message: ok ? null : 'Impossibile aprire il link');
      }

    case ActionKind.replace:
      return ActionOutcome(newText: render());

    case ActionKind.append:
      return ActionOutcome(newText: text + render());

    case ActionKind.newDraft:
      return ActionOutcome(openDraft: store.createDraft(render()));

    case ActionKind.transform:
      {
        final t = transformById(action.transformId);
        if (t == null) return const ActionOutcome(message: 'Trasformazione sconosciuta');
        if (hasSel) {
          return ActionOutcome(
            newText: text.replaceRange(selStart, selEnd, t.apply(selection)),
          );
        }
        return ActionOutcome(newText: t.apply(text));
      }

    case ActionKind.ai:
      return _runAi(context, store, draft, action, render(), store.settings);
  }
}

Future<bool> _launch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

Future<ActionOutcome> _runAi(
  BuildContext context,
  AppStore store,
  Draft draft,
  ActionDef action,
  String prompt,
  AppSettings settings,
) async {
  if (!settings.aiConfigured) {
    return const ActionOutcome(message: 'Configura l\'AI in Impostazioni');
  }
  final navigator = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
  String result;
  try {
    result = await askAi(settings, prompt);
  } on AiException catch (e) {
    navigator.pop();
    return ActionOutcome(message: e.message);
  }
  navigator.pop();

  switch (action.aiOutput) {
    case AiOutput.replace:
      return ActionOutcome(newText: result, message: 'Testo sostituito (annulla con ↶)');
    case AiOutput.append:
      return ActionOutcome(newText: '${draft.text.trimRight()}\n\n$result');
    case AiOutput.newDraft:
      return ActionOutcome(openDraft: store.createDraft(result));
    case AiOutput.copy:
      await Clipboard.setData(ClipboardData(text: result));
      return const ActionOutcome(message: 'Risposta copiata');
    case AiOutput.show:
      if (!context.mounted) return const ActionOutcome();
      final choice = await showAiResultSheet(context, action.name, result);
      switch (choice) {
        case AiResultChoice.replace:
          return ActionOutcome(newText: result);
        case AiResultChoice.append:
          return ActionOutcome(newText: '${draft.text.trimRight()}\n\n$result');
        case AiResultChoice.newDraft:
          return ActionOutcome(openDraft: store.createDraft(result));
        case AiResultChoice.copy:
          await Clipboard.setData(ClipboardData(text: result));
          return const ActionOutcome(message: 'Risposta copiata');
        case null:
          return const ActionOutcome();
      }
  }
}
