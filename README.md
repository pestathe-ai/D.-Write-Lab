# D. Write Lab

**Scrivi subito, poi decidi dove mandare il testo.** Un'app Dom Studio per Android.

L'app si apre sempre su una pagina bianca: butti giù l'idea, poi con un tocco su **Azioni**
la copi, la condividi, la mandi per email o WhatsApp, la trasformi o la fai lavorare all'AI.

## Funzioni (v0.1)

- **Pagina pronta all'apertura**, salvataggio automatico; dopo 2 minuti di assenza riapre su una bozza nuova
- **Inbox, Preferiti, Archivio, Cestino** (il cestino si svuota da solo dopo 30 giorni)
- **Ricerca** in tutte le bozze e **tag**
- Scorri una bozza nella lista per archiviarla o cestinarla, con **Annulla**
- **Annulla / Ripeti** nell'editor, contatore di parole
- **Azioni pronte**: Copia, Condividi, Email, WhatsApp, Cerca su Google, Evento in calendario,
  Data e ora, Diario, Lista di controllo, Ordina righe, Togli duplicati, MAIUSCOLO
- **Azioni personalizzate** con segnaposto:
  `[[bozza]]` `[[titolo]]` `[[corpo]]` `[[selezione]]` `[[data]]` `[[data_iso]]` `[[ora]]` `[[tag]]` `[[parole]]`
  - tipi: copia, condividi, email, apri link/app, sostituisci, aggiungi in fondo, nuova bozza, trasforma, AI
  - opzione "archivia la bozza dopo", riordino trascinando, duplica
  - le trasformazioni si applicano solo al testo selezionato, se c'è una selezione
- **14 trasformazioni di testo** (maiuscolo, iniziali, ordina, inverti, elenchi puntati/numerati, checklist…)
- **Azioni AI**: Riassumi, Correggi, Traduci, Rendi formale, Estrai attività — o scrivi i tuoi prompt.
  Funziona con qualsiasi servizio compatibile OpenAI: OpenAI, OpenRouter, Groq, Ollama o OmniRoute sul PC
- **Temi** Come il telefono / Chiaro / Scuro / Seppia, dimensione testo, interlinea, carattere fisso
- **Esporta** tutte le bozze in Markdown, **backup** completo in JSON e ripristino

## Installazione

Scarica `app-arm64-v8a-release.apk` dall'ultima [release](../../releases/latest), aprilo e consenti
l'installazione da questa fonte.

## Limiti noti

- La chiave API dell'AI è salvata in chiaro nella memoria privata dell'app
- Il ripristino backup funziona incollando il contenuto del file JSON
- Non riceve ancora testo condiviso da altre app (in programma)
- Nessuna sincronizzazione tra dispositivi

## Sviluppo

Le cartelle `android/` e `ios/` vengono generate in CI da `tool/setup_platforms.sh`.
Ogni push su `main` compila, testa e pubblica l'APK nelle Release.

Carattere Sora: SIL Open Font License (vedi `assets/fonts/OFL.txt`).
