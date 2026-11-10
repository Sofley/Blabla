# B2B Ledger — учет ВЭД-контрактов Back-to-Back

Кросс-платформенное приложение на Flutter (Android / iOS) для учета международных
торговых сделок по схеме Back-to-Back: два связанных, но строго раздельных контракта.

| Контракт | Стороны |
|---|---|
| **Контракт №1** | Покупатель (Buyer) ↔ Промежуточная компания (Intermediary) |
| **Контракт №2** | Промежуточная компания (Intermediary) ↔ Продавец / Завод (Seller) |

## Возможности

- **Раздельные контракты.** Каждый контракт — отдельная вкладка с собственной формой и своими
  полями: номер, дата заключения, участники, стоимость товара, логистика, агентские, НДС,
  примечания. Данные контрактов не смешиваются ни в модели, ни в UI.
- **Финансовый калькулятор** в каждом контракте:
  - стоимость закупа товара в валюте контракта (CNY, USD, EUR, RUB, UZS, KZT, AED) и курс на дату заключения;
  - логистика: транспорт, фрахт, портовые сборы (USD/EUR);
  - агентские услуги — по умолчанию 9%, редактируется;
  - НДС — по умолчанию 9%, редактируется или отключается (0%).
- **Калькулятор чистой прибыли** по сделке (все суммы — в USD по курсам на даты заключения):
  ```
  goods     = стоимость товара / курс
  logistics = (транспорт + фрахт + портовые сборы) / курс
  agency    = goods × агентские%
  net       = goods + logistics + agency
  vat       = net × НДС%
  total     = net + vat

  Оборот         = Контракт №1 total
  Чистая прибыль = Контракт №1 net (без НДС) − Контракт №2 total
  Маржа          = Чистая прибыль / Контракт №1 net
  ```
- **Комментарии / Примечания (Remarks / Notes)** в каждом контракте.
- **Трекер статусов:** Контракт подписан → Предоплата → Оплата заводу в CNY → В пути → Закрыт
  (с датами этапов; этап меняется нажатием).
- **Дашборд:** месячная аналитика — количество контрактов, оборот, чистая прибыль, маржа,
  график прибыли за 6 месяцев, распределение по статусам.
- **Дизайн «Financial Minimalism»**, светлая / темная / системная тема.
- **Локализация:** русский и английский (или язык системы).
- **Локальная БД Hive** — все данные хранятся только на устройстве.

## Структура

```
lib/
  main.dart                     инициализация Hive и запуск
  app.dart                      MaterialApp, темы, локализация, провайдеры
  core/
    l10n/app_strings.dart       строки RU/EN
    theme/app_theme.dart        светлая/темная тема, FinanceColors
    utils/formatters.dart       форматирование денег/дат, парсинг чисел
  data/
    models/                     Currency, ContractStage, TradeContract, Deal
    repositories/               DealRepository, SettingsRepository (Hive)
  domain/
    finance_calculator.dart     ContractFinancials, DealProfit
    analytics_service.dart      месячная аналитика
  state/                        DealsController, SettingsController (ChangeNotifier)
  ui/
    home_shell.dart             нижняя навигация
    dashboard/                  дашборд
    deals/                      список, карточка сделки, редактор, виджеты
    settings/                   настройки
test/                           unit- и widget-тесты
```

## Запуск

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Публикация

**Google Play**
1. Создайте ключ: `keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Создайте `android/key.properties` (не коммитится):
   ```
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/абсолютный/путь/upload-keystore.jks
   ```
3. `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`.

**App Store**
1. Откройте `ios/Runner.xcworkspace` в Xcode, укажите Team и Bundle Identifier.
2. `flutter build ipa --release`, загрузите через Xcode Organizer или Transporter.

Перед публикацией замените иконки приложения (`android/app/src/main/res/mipmap-*`,
`ios/Runner/Assets.xcassets/AppIcon.appiconset`) и при необходимости идентификатор
`com.b2bledger.b2b_contracts`.
