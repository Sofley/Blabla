# nexus_release — проверка перед публикацией в Google Play

```
cd tools/nexus_release && dart pub get && cd ../..
dart run tools/nexus_release/bin/nexus_release.dart \
  --project . --artifact build/app/outputs/bundle/release/app-release.aab \
  --previous-code 6
```

Проверяет: версию в сборке и pubspec (и что код версии вырос), подпись постоянным
ключом (SHA-256 83:E0:AA:…:8F, не отладочный ключ), targetSdk ≥ 35, что сборка не
отладочная, новые разрешения, формат AAB, наличие `android/key.properties` и что
ключи/пароли не попали в git. `--json` — машинный вывод.

Коды выхода: 0 — готово, 1 — есть ошибки, 64 — неверные аргументы, 78 — нет build-tools.
