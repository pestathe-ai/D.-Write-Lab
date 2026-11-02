import 'package:flutter/material.dart';

import 'data/file_backend.dart';
import 'data/store.dart';
import 'ui/editor_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore(FileBackend());
  await store.load();
  runApp(WriteLabApp(store: store));
}

class WriteLabApp extends StatelessWidget {
  const WriteLabApp({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: store.themeNotifier,
      builder: (context, appTheme, _) {
        final (theme, dark, mode) = themesFor(appTheme);
        return MaterialApp(
          title: 'D. Write Lab',
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: dark,
          themeMode: mode,
          home: EditorScreen(store: store),
        );
      },
    );
  }
}
