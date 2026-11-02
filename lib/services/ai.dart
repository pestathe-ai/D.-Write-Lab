import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/settings.dart';

class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Costruisce l'URL di chat/completions accettando sia ".../v1" che l'URL completo.
Uri chatCompletionsUri(String baseUrl) {
  var b = baseUrl.trim();
  while (b.endsWith('/')) {
    b = b.substring(0, b.length - 1);
  }
  if (!b.endsWith('/chat/completions')) b = '$b/chat/completions';
  return Uri.parse(b);
}

Map<String, dynamic> buildChatBody(String model, String prompt) => {
      'model': model.trim(),
      'messages': [
        {
          'role': 'system',
          'content':
              'Sei un assistente di scrittura. Rispondi solo con il testo richiesto, senza introduzioni né commenti.',
        },
        {'role': 'user', 'content': prompt},
      ],
    };

/// Estrae il testo dalla risposta in formato OpenAI.
String parseChatResponse(String body) {
  final j = jsonDecode(body);
  if (j is Map && j['error'] != null) {
    final e = j['error'];
    throw AiException(e is Map ? '${e['message'] ?? e}' : '$e');
  }
  final choices = (j as Map)['choices'] as List?;
  if (choices == null || choices.isEmpty) {
    throw AiException('Risposta vuota dal servizio AI');
  }
  final msg = (choices.first as Map)['message'] as Map?;
  final content = msg?['content'];
  if (content is String) return content.trim();
  if (content is List) {
    return content
        .whereType<Map>()
        .map((p) => p['text'] ?? '')
        .join()
        .trim();
  }
  throw AiException('Formato di risposta non riconosciuto');
}

Future<String> askAi(AppSettings s, String prompt, {http.Client? client}) async {
  if (!s.aiConfigured) {
    throw AiException('Configura l\'AI in Impostazioni (indirizzo e modello).');
  }
  final c = client ?? http.Client();
  try {
    final res = await c
        .post(
          chatCompletionsUri(s.aiBaseUrl),
          headers: {
            'Content-Type': 'application/json',
            if (s.aiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${s.aiKey.trim()}',
          },
          body: jsonEncode(buildChatBody(s.aiModel, prompt)),
        )
        .timeout(const Duration(seconds: 90));
    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 400) {
      String detail = body;
      try {
        parseChatResponse(body);
      } on AiException catch (e) {
        detail = e.message;
      } catch (_) {}
      if (detail.length > 300) detail = '${detail.substring(0, 300)}…';
      throw AiException('Errore ${res.statusCode}: $detail');
    }
    return parseChatResponse(body);
  } on AiException {
    rethrow;
  } catch (e) {
    throw AiException('Connessione non riuscita: $e');
  } finally {
    if (client == null) c.close();
  }
}
