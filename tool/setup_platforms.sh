#!/usr/bin/env bash
# Genera le cartelle android/ e ios/ (non sono nel repository) e le configura.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create --project-name d_write_lab --org dev.dwritelab --platforms=android,ios .
rm -f test/widget_test.dart

MANIFEST=android/app/src/main/AndroidManifest.xml
# Internet per l'AI, traffico http per Ollama/OmniRoute sul PC di casa.
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"
fi
sed -i 's#<application#<application android:usesCleartextTraffic="true"#' "$MANIFEST"
# Nome visibile sotto l'icona.
sed -i 's#android:label="[^"]*"#android:label="D. Write Lab"#' "$MANIFEST"
# App che possono aprire link, mail e messaggi (visibilità pacchetti Android 11+).
if ! grep -q 'android.intent.action.SENDTO' "$MANIFEST"; then
  sed -i 's#</queries>#    <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n        <intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>\n        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="sms"/></intent>\n    </queries>#' "$MANIFEST"
fi

if [[ "$(uname)" == "Darwin" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName D. Write Lab" ios/Runner/Info.plist || true
fi

flutter pub get
dart run flutter_launcher_icons
echo "--- AndroidManifest ---"; cat "$MANIFEST"
