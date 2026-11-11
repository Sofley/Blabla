import 'package:flutter/widgets.dart';

import '../../data/models/account.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/logistics_route.dart';
import '../theme/app_theme.dart';
import 'app_lang.dart';
import 'translit.dart';
import 'tr_sr.dart';
import 'tr_uz.dart';
import 'tr_zh.dart';
import 'tr_v3.dart';
import '../../data/models/app_user.dart';
import '../../data/models/contract_stage.dart';
import '../../data/models/deal.dart';
import '../../data/models/trade_contract.dart';

part 'strings_v3.dart';

/// Localization without code generation. Russian and English are written
/// inline; Uzbek, Serbian and Chinese come from dictionaries keyed by the
/// English text (see tr_*.dart). Uzbek Latin and Serbian Cyrillic are
/// produced by transliteration, so both alphabets always match.
class AppStrings {
  AppStrings(this.locale) : lang = AppLang.fromLocale(locale);

  final Locale locale;
  final AppLang lang;

  static final supportedLocales = [for (final l in AppLang.values) l.locale];

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      AppStrings(const Locale('en'));

  static final _uz = {...trUz, ...trUzV3};
  static final _sr = {...trSr, ...trSrV3};
  static final _zh = {...trZh, ...trZhV3};

  Map<String, String> get _dict => switch (lang) {
    AppLang.uzCyrl || AppLang.uzLatn => _uz,
    AppLang.srLatn || AppLang.srCyrl => _sr,
    AppLang.zh => _zh,
    _ => const {},
  };

  /// Converts a finished translation to the selected alphabet.
  String script(String text) => switch (lang) {
    AppLang.uzLatn => uzCyrlToLatn(text),
    AppLang.srCyrl => srLatnToCyrl(text),
    _ => text,
  };

  String _t(String ru, String en) => switch (lang) {
    AppLang.ru => ru,
    AppLang.en => en,
    _ => script(_dict[en] ?? en),
  };

  /// Like [_t] for templates with {0}, {1}… placeholders. Arguments are
  /// inserted after transliteration, so names and numbers stay intact.
  String _f(String ru, String en, List<Object> args) {
    var out = _t(ru, en);
    for (var i = 0; i < args.length; i++) {
      out = out.replaceAll('{$i}', '${args[i]}');
    }
    return out;
  }

  // App & navigation
  String get appTitle => 'NexusTrade';
  String get navDashboard => _t('Дашборд', 'Dashboard');
  String get navDeals => _t('Сделки', 'Deals');
  String get navSettings => _t('Настройки', 'Settings');

  // Common
  String get save => _t('Сохранить', 'Save');
  String get cancel => _t('Отмена', 'Cancel');
  String get delete => _t('Удалить', 'Delete');
  String get edit => _t('Редактировать', 'Edit');
  String get close => _t('Закрыть', 'Close');
  String get search =>
      _t('Поиск по номеру или компании', 'Search by number or company');
  String get all => _t('Все', 'All');
  String get required => _t('Обязательное поле', 'Required field');
  String get invalidNumber => _t('Неверное число', 'Invalid number');
  String get notSpecified => _t('не указано', 'not specified');

  // Deals
  String get newDeal => _t('Новая сделка', 'New deal');
  String get editDeal => _t('Редактирование сделки', 'Edit deal');
  String get dealDetails => _t('Сделка', 'Deal');
  String get noDeals => _t('Сделок пока нет', 'No deals yet');
  String get noDealsHint => _t(
    'Создайте первую сделку Back-to-Back: два раздельных контракта с покупателем и продавцом.',
    'Create your first back-to-back deal: two separate contracts with the buyer and the seller.',
  );
  String get noDealsForFilter => _t('Ничего не найдено', 'Nothing found');
  String get deleteDealQuestion => _t('Удалить сделку?', 'Delete this deal?');
  String get deleteDealHint => _t(
    'Оба контракта и все примечания будут удалены без возможности восстановления.',
    'Both contracts and all notes will be permanently deleted.',
  );
  String get dealSaved => _t('Сделка сохранена', 'Deal saved');
  String get discardChanges => _t('Отменить изменения?', 'Discard changes?');
  String get discard => _t('Отменить', 'Discard');
  String get keepEditing => _t('Продолжить', 'Keep editing');
  String fillContractNumber(String contract) =>
      _f('Укажите номер: {0}', 'Enter the number: {0}', [contract]);

  // Contracts
  String contractTitle(ContractSide side) => switch (side) {
    ContractSide.buyer => _t('Контракт №1', 'Contract #1'),
    ContractSide.seller => _t('Контракт №2', 'Contract #2'),
  };
  String contractParties(ContractSide side) => switch (side) {
    ContractSide.buyer => _t('Покупатель ↔ Посредник', 'Buyer ↔ Intermediary'),
    ContractSide.seller => _t('Посредник ↔ Продавец', 'Intermediary ↔ Seller'),
  };
  String counterpartyLabel(ContractSide side) => switch (side) {
    ContractSide.buyer => _t('Покупатель (Buyer)', 'Buyer'),
    ContractSide.seller => _t(
      'Продавец / Завод-производитель (Seller)',
      'Seller / Manufacturer',
    ),
  };
  String get intermediary =>
      _t('Промежуточная компания (Intermediary)', 'Intermediary company');
  String get requisites => _t('Реквизиты', 'Requisites');
  String get parties => _t('Участники', 'Parties');
  String get contractNumber => _t('Номер контракта', 'Contract number');
  String get contractDate => _t('Дата заключения', 'Signing date');
  String get summary => _t('Итог', 'Summary');

  // Finance inputs
  String get goodsSection => _t('Товар и стоимость', 'Goods and cost');
  String get goodsCost => _t('Сумма за товар', 'Goods amount');
  String get contractCurrency => _t('Валюта контракта', 'Contract currency');
  String ratePerUsd(String code) =>
      _f('Курс: 1 USD = ? {0}', 'Rate: 1 USD = ? {0}', [code]);
  String get rateHint => _t(
    'Курс на дату заключения контракта',
    'Exchange rate on the contract signing date',
  );
  String get logisticsSection => _t('Логистика (Logistics)', 'Logistics');
  String get transport => _t('Транспорт', 'Transport');
  String get freight => _t('Фрахт', 'Freight');
  String get portFees => _t('Портовые сборы', 'Port fees');
  String get logisticsCurrency => _t('Валюта логистики', 'Logistics currency');
  String get feesSection => _t('Агентские услуги и НДС', 'Agency fee & VAT');
  String get agencyFee =>
      _t('Агентские услуги (Agency Fee), %', 'Agency fee, %');
  String get vatEnabled => _t('Начислять НДС (VAT)', 'Charge VAT');
  String get vatDisabledHint => _t('НДС отключен (0%)', 'VAT disabled (0%)');
  String get vatPercent => _t('НДС (VAT), %', 'VAT, %');
  String get resetDefault => _t('По умолчанию', 'Default');
  String get notesSection =>
      _t('Комментарии / Примечания (Remarks / Notes)', 'Remarks / Notes');
  String get notesHint => _t(
    'Нюансы отгрузки, договоренности с партнерами, специфика платежей…',
    'Shipment details, agreements with partners, payment specifics…',
  );

  // Calculator
  String get calculator => _t('Расчет контракта', 'Contract calculation');
  String get goods => _t('Товар', 'Goods');
  String get logistics => _t('Логистика', 'Logistics');
  String get agency => _t('Агентские', 'Agency fee');
  String get vat => _t('НДС', 'VAT');
  String get netAmount => _t('Сумма без НДС', 'Amount excl. VAT');
  String get contractTotal => _t('Итого по контракту', 'Contract total');
  String get inContractCurrency =>
      _t('в валюте контракта', 'in contract currency');

  // Profit
  String get profitCalculator =>
      _t('Калькулятор чистой прибыли', 'Net profit calculator');
  String get revenue => _t('Выручка (Контракт №1)', 'Revenue (Contract #1)');
  String get outputVat => _t('НДС к уплате с продажи', 'Output VAT payable');
  String get expenses => _t('Расходы (Контракт №2)', 'Expenses (Contract #2)');
  String get netProfit => _t('Чистая прибыль', 'Net profit');
  String get margin => _t('Маржа', 'Margin');
  String get profitFormula => _t(
    'Чистая прибыль = выручка от покупателя (без НДС) − выплата заводу − логистика − агентские + НДС-бонус (только если включён его переключатель). Все суммы в USD по курсам на даты заключения.',
    'Net profit = revenue from buyer (excl. VAT) − payment to factory − logistics − agent fee + VAT bonus (only when its switch is on). All amounts in USD at signing-date rates.',
  );

  // Stages
  String get status => _t('Статус', 'Status');
  String get statusTracker => _t('Этапы выполнения', 'Execution stages');
  String stage(ContractStage s) => switch (s) {
    ContractStage.signed => _t('Подписание', 'Signing'),
    ContractStage.prepayment => _t('Предоплата', 'Prepayment'),
    ContractStage.loading => _t('Загрузка', 'Loading'),
    ContractStage.payment => _t('Оплата', 'Payment'),
    ContractStage.closed => _t('Закрыт', 'Closed'),
  };

  /// Names of stages recorded before v3.0 (kept in the deal history).
  String legacyStage(String name) => switch (name) {
    'factoryPaymentCny' => _t('Оплата заводу в CNY', 'Factory payment (CNY)'),
    'inTransit' => _t('В пути', 'In transit'),
    _ => name,
  };
  String get moveToNextStage => _t('Следующий этап', 'Next stage');
  String get tapStageHint => _t(
    'Нажмите на этап, чтобы изменить статус',
    'Tap a stage to change status',
  );

  // Dashboard
  String get monthlyAnalytics => _t('Месячная аналитика', 'Monthly analytics');
  String get contractsCount => _t('Контрактов', 'Contracts');
  String get turnover => _t('Оборот', 'Turnover');
  String get last6Months =>
      _t('Чистая прибыль за 6 месяцев', 'Net profit, last 6 months');
  String get stagesBreakdown => _t('Статусы за месяц', 'Statuses this month');
  String get recentDeals => _t('Сделки месяца', 'Deals this month');
  String get noDealsThisMonth =>
      _t('В этом месяце сделок нет', 'No deals this month');
  String get allValuesInUsd => _t(
    'Все суммы в USD по курсам на дату сделки',
    'All amounts in USD at deal-date rates',
  );

  // Settings
  String get appearance => _t('Оформление', 'Appearance');
  String get themeSystem => _t('Авто', 'Auto');
  String get themeLight => _t('Светлая', 'Light');
  String get themeDark => _t('Темная', 'Dark');
  String get language => _t('Язык', 'Language');
  String get languageSystem => _t('Авто', 'Auto');
  String get defaults => _t('Значения по умолчанию', 'Defaults');
  String get defaultsHint =>
      _t('Применяются к новым контрактам', 'Applied to new contracts');
  String get myCompany =>
      _t('Моя компания (Intermediary)', 'My company (Intermediary)');
  String get about => _t('О приложении', 'About');
  String get aboutText => _t(
    'NexusTrade — учёт ВЭД-контрактов по схеме Back-to-Back: Покупатель ⇄ Посредник ⇄ Продавец. Все данные хранятся только на устройстве.',
    'Back-to-back foreign trade contract ledger. All data is stored on this device only.',
  );

  // ---------- Navigation (v2) ----------
  String get navPrice => _t('Цена', 'Price');
  String get yes => _t('Да', 'Yes');
  String get no => _t('Нет', 'No');
  String get total => _t('Итого', 'Total');
  String get currency => _t('Валюта', 'Currency');

  // ---------- Auth ----------
  String get registerTitle => _t('Создайте аккаунт', 'Create your account');
  String get registerSubtitle => _t(
    'Вход по почте или номеру телефона и паролю',
    'Sign in with e-mail or phone number and a password',
  );
  String get byEmail => _t('Почта', 'E-mail');
  String get byPhone => _t('Телефон', 'Phone');
  String get email => _t('Электронная почта', 'E-mail');
  String get phone => _t('Номер телефона', 'Phone number');
  String get invalidEmail =>
      _t('Введите корректный адрес почты', 'Enter a valid e-mail');
  String get invalidPhone => _t(
    'Введите номер с кодом страны (7–15 цифр)',
    'Enter the number with country code (7–15 digits)',
  );
  String get yourName => _t('Ваше имя (необязательно)', 'Your name (optional)');
  String get password => _t('Пароль', 'Password');
  String get confirmPassword => _t('Повторите пароль', 'Repeat password');
  String get passwordRules => _t(
    'Не менее 6 символов, буквы и цифры',
    'At least 6 characters, letters and digits',
  );
  String get passwordsDontMatch =>
      _t('Пароли не совпадают', 'Passwords do not match');
  String get createAccount => _t('Зарегистрироваться', 'Create account');
  String get localAccountNote => _t(
    'Аккаунт и все данные хранятся только на этом устройстве в зашифрованном виде. Делайте резервные копии в Настройках.',
    'The account and all data are stored encrypted on this device only. Make backups in Settings.',
  );
  String get quickUnlockTitle => _t('Быстрый вход', 'Quick unlock');
  String get quickUnlockSubtitle => _t(
    'Выберите, как открывать приложение. Пароль всегда остаётся запасным способом.',
    'Choose how to open the app. Your password always remains a fallback.',
  );
  String get pin4 => _t('PIN-код из 4 цифр', '4-digit PIN');
  String get pin4Hint => _t('Быстро и просто', 'Quick and simple');
  String get pin6 => _t('PIN-код из 6 цифр', '6-digit PIN');
  String get pin6Hint => _t('Надёжнее', 'More secure');
  String get patternLock => _t('Графический ключ', 'Pattern');
  String get patternHint =>
      _t('Соедините минимум 4 точки', 'Connect at least 4 dots');
  String get passwordOnly => _t('Только пароль', 'Password only');
  String get passwordOnlyHint =>
      _t('Вводить пароль при каждом входе', 'Type the password every time');
  String quickUnlockName(QuickUnlock q) => switch (q) {
    QuickUnlock.none => passwordOnly,
    QuickUnlock.pin4 => pin4,
    QuickUnlock.pin6 => pin6,
    QuickUnlock.pattern => patternLock,
  };
  String enterNewPin(int n) =>
      _f('Придумайте PIN из {0} цифр', 'Create a {0}-digit PIN', [n]);
  String get repeatPin => _t('Повторите PIN-код', 'Repeat the PIN');
  String get drawNewPattern =>
      _t('Нарисуйте графический ключ', 'Draw your pattern');
  String get repeatPattern =>
      _t('Повторите графический ключ', 'Repeat the pattern');
  String get codesDontMatch =>
      _t('Не совпадает, попробуйте снова', 'Does not match, try again');
  String get patternTooShort =>
      _t('Нужно минимум 4 точки', 'Use at least 4 dots');
  String get quickUnlockSaved =>
      _t('Способ входа сохранён', 'Unlock method saved');
  String welcomeBack(String name) =>
      _f('С возвращением, {0}', 'Welcome back, {0}', [name]);
  String get enterPin => _t('Введите PIN-код', 'Enter your PIN');
  String get drawPattern =>
      _t('Нарисуйте графический ключ', 'Draw your pattern');
  String get enterPassword =>
      _t('Введите логин и пароль', 'Enter login and password');
  String get signIn => _t('Войти', 'Sign in');
  String get signInWithPassword =>
      _t('Войти по паролю', 'Sign in with password');
  String get usePin => _t('Войти по PIN-коду', 'Use PIN');
  String get usePattern => _t('Войти графическим ключом', 'Use pattern');
  String get wrongCredentials => _t('Неверные данные', 'Wrong credentials');
  String attemptsLeft(int n) =>
      _f('осталось попыток: {0}', '{0} attempts left', [n]);
  String tooManyAttempts(int sec) => _f(
    'Слишком много попыток. Подождите {0} с',
    'Too many attempts. Wait {0} s',
    [sec],
  );
  String get forgotPassword => _t('Забыли пароль?', 'Forgot password?');
  String get forgotPasswordText => _t(
    'Аккаунт хранится только на этом устройстве, поэтому восстановить пароль нельзя. Можно сбросить приложение: будут удалены аккаунт и ВСЕ данные. После этого можно зарегистрироваться заново и восстановить данные из резервной копии.',
    'The account exists only on this device, so the password cannot be recovered. You can reset the app: the account and ALL data will be deleted. Then register again and restore data from a backup.',
  );
  String get resetApp => _t('Сбросить всё', 'Reset everything');
  String get account => _t('Аккаунт', 'Account');
  String get changePassword => _t('Сменить пароль', 'Change password');
  String get currentPassword => _t('Текущий пароль', 'Current password');
  String get newPassword => _t('Новый пароль', 'New password');
  String get passwordChanged => _t('Пароль изменён', 'Password changed');
  String get wrongCurrentPassword =>
      _t('Неверный текущий пароль', 'Wrong current password');
  String get lockNow => _t('Заблокировать сейчас', 'Lock now');
  String get deleteAccount =>
      _t('Удалить аккаунт и данные', 'Delete account and data');
  String get deleteAccountText => _t(
    'Будут безвозвратно удалены аккаунт, все сделки, расчёты цен и настройки. Сначала сделайте резервную копию.',
    'The account, all deals, price calculations and settings will be permanently deleted. Make a backup first.',
  );

  // ---------- Goods per unit ----------
  String get productName => _t('Наименование товара', 'Product');
  String get unitPrice => _t('Цена за единицу', 'Unit price');
  String get quantity => _t('Количество', 'Quantity');
  String get unitLabel => _t('Ед. изм.', 'Unit');
  String get unitHint => _t('шт, кг, т', 'pcs, kg, t');
  String get perUnitShort => _t('за ед.', 'per unit');
  String get perUnitTotal => _t('Итого за единицу', 'Total per unit');
  String get rateCheckHint => _t(
    'Подставлен примерный курс — проверьте курс на дату контракта!',
    'An indicative rate was filled in — check the rate on the contract date!',
  );

  // ---------- VAT refund ----------
  String get vatRefund => _t('Возврат НДС', 'VAT refund');
  String get vatRefundToIntermediary =>
      _t('Возврат НДС (посреднику)', 'VAT refund (to intermediary)');
  String get includeVatRefund =>
      _t('Учитывать возврат НДС', 'Include VAT refund');
  String get vatRefundExplain => _t(
    'Сумма, которую возвращают нашей компании-посреднику. Добавляется к прибыли.',
    'Amount paid back to our intermediary company. Added to profit.',
  );
  String get vatRefundRate => _t('Возврат НДС, %', 'VAT refund, %');
  String get refundBase => _t('База расчёта', 'Base');
  String refundBaseLabel(VatRefundBase b) => switch (b) {
    VatRefundBase.goods => _t('Стоимость товара', 'Goods cost'),
    VatRefundBase.contractTotal => _t('Итого по контракту', 'Contract total'),
  };
  String get vatRefundReceived =>
      _t('Возврат НДС получен', 'VAT refund received');
  String get refundReceivedHint =>
      _t('Деньги поступили на счёт', 'Money has arrived');
  String get refundPendingHint =>
      _t('Ожидается поступление', 'Awaiting payment');
  String get markup =>
      _t('Наценка (прибыль в цене)', 'Markup (profit in price)');
  String get markupPlusRefund =>
      _t('наценка + возврат НДС', 'markup + VAT refund');
  String get pending => _t('ожидается', 'pending');
  String get allReceived => _t('всё получено', 'all received');
  String get ofExw => _t('от цены закупки', 'of purchase price');

  // ---------- Price calculator ----------
  String get priceCalculator => _t('Калькулятор цены', 'Price calculator');
  String get quoteShort => _t('Расчёт цены', 'Price quote');
  String get newQuote => _t('Новый расчёт', 'New calculation');
  String get noQuotes => _t('Расчётов пока нет', 'No calculations yet');
  String get noQuotesHint => _t(
    'Соберите свою цену: закупка EXW + логистика + агентские + ваша прибыль, и учтите возврат НДС.',
    'Build your price: EXW purchase + logistics + agent fee + your profit, with VAT refund.',
  );
  String get goodsAndTerms => _t('Товар и условия', 'Goods and terms');
  String get buyerOptional =>
      _t('Покупатель (необязательно)', 'Buyer (optional)');
  String get incoterms => _t('Инкотермс', 'Incoterms');
  String get pricePerUnitStructure =>
      _t('Структура цены за единицу', 'Price structure per unit');
  String get exwPrice => _t('Цена товара', 'Goods price');
  String get logisticsPerUnit =>
      _t('Логистика / доставка', 'Logistics / delivery');
  String get logisticsShort => _t('Логистика', 'Logistics');
  String get agentFee => _t('Агенту', 'Agent');
  String get agentShort => _t('Агент', 'Agent');
  String get agentPercentOfPurchase =>
      _t('Агенту, % от закупки', 'Agent, % of purchase');
  String get agentPercentShort => _t('Агенту, %', 'Agent, %');
  String get agentAmount => _t('= агенту', '= agent');
  String get ourProfit => _t('Наша прибыль', 'Our profit');
  String get ourProfitShort => _t('Прибыль', 'Profit');
  String get ourProfitMarkup =>
      _t('Наша прибыль (наценка)', 'Our profit (markup)');
  String get salePrice =>
      _t('Цена продажи покупателю', 'Selling price to buyer');
  String get forWholeBatch => _t('На всю партию', 'For the whole batch');
  String get saleAmount => _t('Сумма продажи', 'Sale amount');
  String get saleAmountContract1 =>
      _t('Сумма продажи (Контракт №1)', 'Sale amount (Contract #1)');
  String get purchaseAmount => _t('Закупка', 'Purchase');
  String get purchaseAmountContract2 =>
      _t('Закупка (Контракт №2)', 'Purchase (Contract #2)');
  String get totalProfit => _t('Итого прибыль', 'Total profit');
  String get totalProfitIntermediary =>
      _t('Итого прибыль посредника', 'Total intermediary profit');
  String get profitPerUnit => _t('Прибыль на единицу', 'Profit per unit');
  String get marginOfSale => _t('Маржа от продажи', 'Margin on sale');
  String get component => _t('Статья', 'Component');
  String get perUnit => _t('За единицу', 'Per unit');
  String get share => _t('Доля', 'Share');
  String get enterExwPrice =>
      _t('Укажите цену товара', 'Enter the goods price');
  String get quoteSaved => _t('Расчёт сохранён', 'Calculation saved');
  String get deleteQuoteQuestion =>
      _t('Удалить расчёт?', 'Delete this calculation?');
  String get createDealFromQuote =>
      _t('Создать сделку из расчёта', 'Create deal from calculation');
  String get createDealHint => _t(
    'Цены и количество перенесутся в Контракт №1 и Контракт №2',
    'Prices and quantity will be filled into Contract #1 and Contract #2',
  );

  // ---------- Export & backup ----------
  String get exportTitle => _t('Экспорт и отправка', 'Export & share');
  String get exportMonth =>
      _t('Экспорт отчёта за месяц', 'Export monthly report');
  String get exportRegistry => _t('Экспорт реестра', 'Export registry');
  String get exportAllDeals => _t('Экспорт всех сделок', 'Export all deals');
  String get saveToFile => _t('Сохранить', 'Save');
  String get shareAction => _t('Поделиться', 'Share');
  String fileSaved(String name) =>
      _f('Файл сохранён: {0}', 'File saved: {0}', [name]);
  String get exportFailed =>
      _t('Не удалось создать файл', 'Could not create the file');
  String get dealsRegistry => _t('Реестр сделок', 'Deals registry');
  String get allDeals => _t('все сделки', 'all deals');
  String get generatedOn => _t('Сформировано', 'Generated');
  String contractShort(ContractSide side) => side == ContractSide.buyer
      ? _t('Контракт №1', 'Contract #1')
      : _t('Контракт №2', 'Contract #2');
  String contractPartiesPlain(ContractSide side) => switch (side) {
    ContractSide.buyer => _t('Покупатель - Посредник', 'Buyer - Intermediary'),
    ContractSide.seller => _t('Посредник - Продавец', 'Intermediary - Seller'),
  };
  String get buyerShort => _t('Покупатель', 'Buyer');
  String get sellerShort => _t('Продавец', 'Seller');
  String get dataSection => _t('Данные и резервные копии', 'Data & backups');
  String get backupSave => _t('Сохранить резервную копию', 'Save backup');
  String get backupHint => _t(
    'Все сделки и расчёты в одном файле',
    'All deals and calculations in one file',
  );
  String get backupShare => _t('Отправить резервную копию', 'Share backup');
  String get restore => _t('Восстановить из копии', 'Restore from backup');
  String get restoreHint =>
      _t('Заменит текущие данные', 'Replaces current data');
  String get restoreQuestion => _t('Восстановить данные?', 'Restore data?');
  String restoreText(int deals, int quotes) => _f(
    'В копии: сделок — {0}, расчётов — {1}. Текущие данные будут заменены.',
    'Backup contains {0} deals and {1} calculations. Current data will be replaced.',
    [deals, quotes],
  );
  String get restoreDone => _t('Данные восстановлены', 'Data restored');
  String get invalidBackup => _t(
    'Файл не является резервной копией NexusTrade',
    'Not a NexusTrade backup file',
  );

  // ---------- Price steps (v1.2) ----------
  String get priceSteps => _t('Расчёт цены по шагам', 'Price, step by step');
  String get stepGoodsPrice => _t('Цена за товар', 'Goods price');
  String get stepQuantity => _t('Количество / объём', 'Quantity / volume');
  String get quantityVolume => _t('Количество / объём', 'Quantity / volume');
  String get stepLogistics => _t('Логистика', 'Logistics');
  String get stepAgent => _t('Агентская комиссия', 'Agent commission');
  String get stepVat => _t('НДС', 'VAT');
  String get stepMyProfit =>
      _t('Моя прибыль / мои комиссионные', 'My profit / my commission');
  String get myProfit => _t('Моя прибыль / комиссия', 'My profit / commission');
  String get myProfitShort => _t('Моя прибыль', 'My profit');
  String get perUnitMode => _t('За единицу', 'Per unit');
  String get wholeBatchMode => _t('За всю партию', 'Whole batch');
  String get forBatchShort => _t('за партию', 'per batch');
  String get vatInPrice => _t('Включить НДС в цену', 'Include VAT in price');
  String get vatInPriceHint => _t(
    'От суммы: товар + логистика + агентская комиссия',
    'On: goods + logistics + agent commission',
  );
  String get vatAmount => _t('= НДС', '= VAT');
  String get amountPerUnit => _t('Сумма за ед.', 'Amount per unit');
  String get commissionPercent => _t('% комиссии', 'Commission %');
  String get myProfitPerUnit =>
      _t('Моя прибыль за единицу', 'My profit per unit');
  String get myCommissionPercent =>
      _t('Мои комиссионные, %', 'My commission, %');
  String get ofCost => _t('от себестоимости', 'of cost');

  // ---------- NexusTrade v2 ----------
  String get navHome => _t('Главная', 'Home');
  String get navRates => _t('Курсы', 'Rates');
  String get navChat => _t('Чат', 'Chat');
  String get intermediaryShort => _t('Посредник', 'Intermediary');
  String get clear => _t('Очистить', 'Clear');
  String get confirm => _t('Подтвердить', 'Confirm');
  String get refresh => _t('Обновить', 'Refresh');
  String get amount => _t('Сумма', 'Amount');

  // Rates
  String get ratesAndTariffs => _t('Курсы и тарифы', 'Rates & tariffs');
  String get exchangeRates => _t('Курсы валют', 'Exchange rates');
  String get logisticsTariffs => _t('Тарифы логистики', 'Logistics tariffs');
  String get cbuTitle =>
      _t('ЦБ Республики Узбекистан (CBU)', 'Central Bank of Uzbekistan (CBU)');
  String get pbocTitle =>
      _t('Народный банк Китая (PBOC)', "People's Bank of China (PBOC)");
  String get pbocHint => _t(
    'У PBOC нет открытого API: введите центральный паритет вручную (pbc.gov.cn / chinamoney.com.cn) или возьмите кросс-курс CBU.',
    'PBOC has no open API: enter the central parity by hand (pbc.gov.cn / chinamoney.com.cn) or use the CBU cross rate.',
  );
  String get ratesUpdated => _t('Обновлено', 'Updated');
  String get ratesOnDate => _t('курс на', 'rate for');
  String get ratesNeverLoaded => _t(
    'Курсы ещё не загружались. Потяните вниз, чтобы обновить.',
    'Rates not loaded yet. Pull down to refresh.',
  );
  String get ratesOfflineCached => _t(
    'Нет связи с cbu.uz — показаны сохранённые курсы.',
    'No connection to cbu.uz — showing saved rates.',
  );
  String get ratesOfflineEmpty => _t(
    'Нет связи с cbu.uz. Проверьте интернет и обновите.',
    'No connection to cbu.uz. Check the internet and refresh.',
  );
  String allCurrencies(int n) =>
      _f('Все валюты ({0})', 'All currencies ({0})', [n]);
  String get notSet => _t('Не задан', 'Not set');
  String get tapToEnter => _t('Нажмите, чтобы ввести', 'Tap to enter');
  String get cbuCrossShort => _t('кросс по CBU', 'CBU cross');
  String get useCbuCross => _t('Кросс-курс CBU', 'CBU cross rate');
  String get enteredOn => _t('введён', 'entered');
  String get crossRate => _t('Кросс-курс USD / CNY', 'Cross rate USD / CNY');
  String get crossRateUsdCny =>
      _t('Кросс-курс: 1 USD = ? CNY', 'Cross rate: 1 USD = ? CNY');
  String get usedInCalculators =>
      _t('Используется в расчётах', 'Used in calculators');
  String get useOfficialRate => _t('Курс CBU/PBOC', 'CBU/PBOC rate');
  String get converter => _t('Конвертер валют', 'Currency converter');
  String get converterViaCbu => _t(
    'По официальным курсам CBU (через UZS)',
    'At official CBU rates (via UZS)',
  );
  String get ratesNeeded => _t(
    'Нужны курсы CBU — обновите список ниже',
    'CBU rates needed — refresh the list below',
  );

  // Tariffs
  String transportMode(TransportMode m) => switch (m) {
    TransportMode.sea => _t('Море', 'Sea'),
    TransportMode.rail => _t('Ж/д', 'Rail'),
    TransportMode.road => _t('Авто', 'Road'),
    TransportMode.air => _t('Авиа', 'Air'),
    TransportMode.multimodal => _t('Мультимодальная', 'Multimodal'),
  };
  String get newRoute => _t('Новое направление', 'New route');
  String get editRoute => _t('Направление', 'Route');
  String get noRoutes => _t('Направлений пока нет', 'No routes yet');
  String get routeFrom => _t('Откуда', 'From');
  String get routeTo => _t('Куда', 'To');
  String get cargoType => _t('Контейнер / груз', 'Container / cargo');
  String get priceFrom => _t('Цена от', 'Price from');
  String get priceTo => _t('Цена до', 'Price to');
  String get daysFrom => _t('Дней от', 'Days from');
  String get daysTo => _t('Дней до', 'Days to');
  String daysShort(String d) => _f('{0} дн.', '{0} days', [d]);
  String get routeNeedsPoints =>
      _t('Укажите, откуда и куда', 'Enter origin and destination');
  String get tariffsHint => _t(
    'Ставки вводите и обновляйте сами — они используются в калькуляторе цены («Из тарифов»).',
    'Enter and update the rates yourself — they are used in the price calculator ("From tariffs").',
  );
  String get fromTariffs => _t('Из тарифов', 'From tariffs');
  String get pickRoute => _t('Выберите направление', 'Choose a route');
  String get pickRouteHint => _t(
    'Подставится средняя цена за партию',
    'The average price per batch will be used',
  );

  // Chat & Observer
  String get chatTitle => _t('Чат контракта', 'Contract chat');
  String get chatNoDeals => _t(
    'Создайте сделку — у каждой будет свой чат',
    'Create a deal — each one has its own chat',
  );
  String get chatEmpty => _t('Сообщений пока нет', 'No messages yet');
  String get chatEmptyHint => _t(
    'Записывайте договорённости с покупателем, продавцом и агентом. Смена статуса сделки появится здесь автоматически.',
    'Log agreements with the buyer, seller and agent. Status changes appear here automatically.',
  );
  String get chatHint => _t('Написать сообщение…', 'Write a message…');
  String get chatDealCreated => _t('Сделка создана', 'Deal created');
  String chatStageChanged(String stage) =>
      _f('Статус: {0}', 'Status: {0}', [stage]);
  String chatAuthor(ChatAuthor a) => switch (a) {
    ChatAuthor.me => _t('Я', 'Me'),
    ChatAuthor.buyer => _t('Покупатель', 'Buyer'),
    ChatAuthor.seller => _t('Продавец', 'Seller'),
    ChatAuthor.agent => _t('Агент', 'Agent'),
    ChatAuthor.manager => _t('Менеджер', 'Manager'),
    ChatAuthor.system => _t('Система', 'System'),
  };
  String get observerMode =>
      _t('Режим наблюдателя (Observer)', 'Observer mode');
  String get observerToggle => _t('Только просмотр', 'View only');
  String get observerExplain => _t(
    'Удобно, чтобы показать сделки партнёру: всё видно, но ничего нельзя изменить или удалить. Для выхода нужен ваш пароль.',
    'Handy for showing deals to a partner: everything is visible but nothing can be changed or deleted. Your password is needed to exit.',
  );
  String get observerBanner =>
      _t('Режим Observer: только просмотр', 'Observer mode: view only');
  String get observerActiveInfo => _t(
    'Режим наблюдателя включён: сделки, расчёты и чат доступны только для просмотра.',
    'Observer mode is on: deals, calculations and chat are view-only.',
  );
  String get observerOffInfo => _t(
    'Переписка и статусы хранятся на этом телефоне. Отправить чат партнёру можно кнопкой «Поделиться».',
    'Messages and statuses are stored on this phone. Send a chat to a partner with the Share button.',
  );
  String get observerReadOnly => _t('Только просмотр', 'View only');
  String get observerNotSaved => _t(
    'Режим Observer: изменения не сохраняются',
    'Observer mode: changes are not saved',
  );
  String get observerExitTitle =>
      _t('Выйти из режима Observer', 'Exit Observer mode');

  // Appearance
  String get themeAmoled => _t('AMOLED', 'AMOLED');
  String get accentColor => _t('Акцентный цвет', 'Accent color');
  String accentName(AccentColor a) => switch (a) {
    AccentColor.teal => 'Teal',
    AccentColor.amber => 'Amber',
    AccentColor.blue => 'Blue',
    AccentColor.purple => 'Purple',
  };
  String get backgroundImage => _t('Фоновое изображение', 'Background image');
  String get chooseFromGallery =>
      _t('Выбрать из галереи', 'Choose from gallery');
  String get changeBackground => _t('Сменить фото', 'Change photo');
  String get removeBackground => _t('Убрать фон', 'Remove background');
  String get backgroundVisibility => _t('Видимость', 'Visibility');
  String get backgroundBlur => _t('Размытие', 'Blur');
  String get backgroundFailed =>
      _t('Не удалось загрузить фото', 'Could not load the photo');

  // ---------- v2.1: VAT bonus ----------
  String get vatBonusTitle =>
      _t('Возврат НДС и НДС-бонус', 'VAT refund & VAT bonus');
  String get vatRefundCalc => _t('Считать возврат НДС', 'Calculate VAT refund');
  String get vatRefundCalcHint => _t(
    'Возврат НДС в Китае считается от суммы закупа у завода (FOB)',
    'The China VAT refund is calculated on the factory purchase amount (FOB)',
  );
  String get vatRefundAmount => _t('Возврат НДС', 'VAT refund');
  String get myVatShare => _t('Моя доля возврата', 'My share of the refund');
  String get vatBonus => _t('НДС-бонус', 'VAT bonus');
  String get addVatBonusToProfit =>
      _t('Добавлять НДС-бонус в чистую прибыль', 'Add VAT bonus to net profit');
  String get vatBonusInProfitHint => _t(
    'Включено: бонус прибавляется к прибыли',
    'On: the bonus is added to profit',
  );
  String get vatBonusReferenceHint => _t(
    'Выключено: бонус показан справочно и в прибыль не входит',
    'Off: the bonus is shown for reference and not counted in profit',
  );
  String get vatBonusReferenceShort => _t(
    'НДС-бонус (справочно, не в прибыли)',
    'VAT bonus (reference, not in profit)',
  );
  String get vatSection => _t('НДС', 'VAT');

  // ---------- v2.1: profit formula ----------
  String get revenueFromBuyer => _t(
    'Выручка от покупателя (Контракт №1, без НДС)',
    'Revenue from buyer (Contract #1, excl. VAT)',
  );
  String get buyerVatExcluded =>
      _t('НДС покупателя (уходит в бюджет)', 'Buyer VAT (paid to the budget)');
  String get paymentToFactory => _t('Выплата заводу', 'Payment to factory');
  String get factoryVat => _t('НДС по закупке', 'Purchase VAT');
  String get agentFeeInternal =>
      _t('Агентские (скрыто от покупателя)', 'Agent fee (hidden from buyer)');
  String get profitBeforeBonus =>
      _t('Прибыль без НДС-бонуса', 'Profit before VAT bonus');
  String get factoryUnitPrice =>
      _t('Цена завода за единицу (FOB)', 'Factory unit price (FOB)');
  String get unitPriceCalculated =>
      _t('Цена за единицу (рассчитана)', 'Unit price (calculated)');

  // ---------- v2.1: price calculator ----------
  String perThousandLabel(String unit) => _f('За {0}', 'Per {0}', [unit]);
  String get fromBuyerPrice => _t('От цены покупателя', 'From buyer price');
  String get buyerPricePerUnit =>
      _t('Цена покупателю за единицу', 'Buyer price per unit');
  String get breakEvenPrice => _t('цена безубыточности', 'break-even price');

  // ---------- v2.1: deal kinds ----------
  String get kindBackToBack => _t('Back-to-Back', 'Back-to-Back');
  String get kindThreeParty => _t('Трёхсторонний', 'Three-party');
  String get singleContract => _t('Единый контракт', 'Single contract');
  String get singleContractHint => _t(
    'Покупатель ⇄ Завод ⇄ Ваша компания. Покупатель видит только цену контракта',
    'Buyer ⇄ Factory ⇄ Your company. The buyer sees only the contract price',
  );
  String get internalCalc => _t('Внутренний расчёт', 'Internal calculation');
  String get internalCalcHint => _t(
    'Сумма заводу, логистика, агентские и НДС — только для вас, в документ покупателя не попадают',
    'Factory amount, logistics, agent fee and VAT — for you only, never in the buyer document',
  );
  String get threePartiesShort =>
      _t('Покупатель ⇄ Завод ⇄ Плательщик', 'Buyer ⇄ Factory ⇄ Payer');
  String get internalOnlyShort => _t('только для вас', 'for you only');
  String get payerTrader => _t(
    'Плательщик / Трейдер (ваша компания)',
    'Payer / Trader (your company)',
  );
  String get payerShort => _t('Плательщик', 'Payer');
  String get companyStatus =>
      _t('Статус вашей компании', 'Your company status');
  String get companyStatusInfo =>
      _t('Подсказка по статусам', 'About the statuses');
  String roleTitle(CompanyRole r) => switch (r) {
    CompanyRole.buyerImporter => _t(
      'Buyer & Importer (Покупатель и импортёр)',
      'Buyer & Importer',
    ),
    CompanyRole.payer => _t(
      'Payer (Платёж через третье лицо)',
      'Payer (third-party payment)',
    ),
    CompanyRole.principalAgent => _t(
      'Principal / Commission Agent (Принципал / Комиссионер)',
      'Principal / Commission Agent',
    ),
  };
  String roleShortHint(CompanyRole r) => switch (r) {
    CompanyRole.buyerImporter => _t(
      'Трейдер выкупает товар на себя',
      'The trader buys the goods in its own name',
    ),
    CompanyRole.payer => _t(
      'Контракт завода с покупателем, оплату производит ваша компания',
      'Factory–buyer contract, your company makes the payment',
    ),
    CompanyRole.principalAgent => _t(
      'Работа по агентской схеме',
      'Working under an agency scheme',
    ),
  };
  String roleDetails(CompanyRole r) => switch (r) {
    CompanyRole.buyerImporter => _t(
      'Ваша компания покупает товар у завода на себя и продаёт покупателю. В контракте вы — покупатель у завода; право собственности переходит к вам.',
      'Your company buys the goods from the factory in its own name and sells them to the buyer. In the contract you are the factory’s buyer; title passes to you.',
    ),
    CompanyRole.payer => _t(
      'Контракт заключён между заводом и покупателем, а оплату заводу производит ваша компания. В разделе Payment Terms ваша компания указывается как «Payer». Покупатель платит вам цену контракта.',
      'The contract is between the factory and the buyer, and your company pays the factory. In Payment Terms your company is named as the "Payer". The buyer pays you the contract price.',
    ),
    CompanyRole.principalAgent => _t(
      'Ваша компания действует как комиссионер (агент) от имени или по поручению принципала и получает вознаграждение по агентскому договору.',
      'Your company acts as a commission agent on behalf of, or on the instructions of, the principal and earns a fee under the agency agreement.',
    ),
  };
  String get legalDisclaimer => _t(
    'Справочная информация, не юридическая консультация. Схему сделки и формулировки контракта согласуйте с юристом и таможенным брокером.',
    'Reference information, not legal advice. Agree the deal scheme and contract wording with a lawyer and a customs broker.',
  );

  // ---------- v2.1: pricing ----------
  String get contractPriceTitle =>
      _t('Цена контракта для покупателя', 'Contract price for the buyer');
  String get pricingManual => _t('Вручную', 'Manual');
  String get pricingMarginPercent => _t('Маржа %', 'Margin %');
  String get pricingMarginAmount => _t('Маржа суммой', 'Margin sum');
  String get marginPercentOfFactory =>
      _t('Ваша маржа, % от суммы завода', 'Your margin, % of factory amount');
  String get marginSumUsd => _t('Ваша маржа, сумма', 'Your margin, sum');
  String get paymentToFactoryTotal => _t(
    'Всего к выплате (завод, логистика, агент)',
    'Total to pay (factory, logistics, agent)',
  );
  String get paymentToFactoryHint => _t(
    'Из вкладки «Контракт №2 / Внутренний расчёт»',
    'From the "Contract #2 / Internal" tab',
  );
  String get contractPriceForBuyer => _t('Цена контракта', 'Contract price');
  String get marginHiddenHint => _t(
    'Покупатель видит только итоговую цену контракта. Маржа, сумма заводу и агентские в его документ не попадают.',
    'The buyer sees only the final contract price. Margin, factory amount and agent fee never appear in the buyer document.',
  );

  // ---------- v2.1: documents ----------
  String get docForBuyer => _t(
    'Документ для покупателя (только цена контракта)',
    'Buyer document (contract price only)',
  );
  String get docInternal => _t(
    'Внутренний отчёт (полный расчёт)',
    'Internal report (full calculation)',
  );
  String get contractSubject =>
      _t('Предмет контракта', 'Subject of the contract');
  String get totalWithVat => _t('Итого с НДС', 'Total incl. VAT');

  // ---------- v2.1: languages & splash ----------
  String get languageAuto => _t('Как в системе', 'System default');

  // ---------- v2.1: assistant ----------
  String get assistantTitle => _t('AI-ассистент', 'AI assistant');
  String get assistantOnline => _t('Онлайн', 'Online');
  String get assistantOffline => _t('Офлайн', 'Offline');
  String get assistantOnlineSoon => _t(
    'Онлайн-режим появится позже: для него нужен платный AI-сервис. Сейчас работает офлайн-ассистент — без интернета.',
    'Online mode will come later: it needs a paid AI service. The offline assistant works now — without the internet.',
  );
  String get assistantSubtitle => _t(
    'Офлайн · анализ ваших расчётов',
    'Offline · analysis of your calculations',
  );
  String get assistantHello => _t(
    'Здравствуйте! Я офлайн-ассистент NexusTrade. Анализирую ваши расчёты прямо на телефоне, без интернета: маржу, логистику, цену безубыточности, НДС-бонус и агентские. Выберите, что проверить.',
    'Hello! I am the NexusTrade offline assistant. I analyse your calculations right on the phone, without the internet: margin, logistics, break-even price, VAT bonus and agent fee. Choose what to check.',
  );
  String get askLastQuote =>
      _t('Последний расчёт цены', 'Latest price calculation');
  String get askPickQuote => _t('Выбрать расчёт…', 'Choose a calculation…');
  String get askPickDeal => _t('Выбрать сделку…', 'Choose a deal…');
  String get askMonth => _t('Итоги месяца', 'Month summary');
  String get askRates => _t('Курсы валют', 'Exchange rates');
  String get askHint => _t(
    'Спросите: цена, сделка, месяц, курс…',
    'Ask: price, deal, month, rate…',
  );
  String get assistantDontUnderstand => _t(
    'Я работаю офлайн и понимаю короткие запросы: «цена», «сделка», «месяц», «курс». Или выберите действие ниже.',
    'I work offline and understand short requests: "price", "deal", "month", "rate". Or choose an action below.',
  );
  String get assistantNoQuotes => _t(
    'Расчётов цены пока нет — создайте его во вкладке «Цена».',
    'No price calculations yet — create one in the Price tab.',
  );
  String get assistantNoDeals => _t('Сделок пока нет.', 'No deals yet.');
  String get assistantAsk => _t('Спросить ассистента', 'Ask the assistant');
  String aiQuoteHeadline(
    String name,
    String price,
    String profit,
    String margin,
  ) => _f(
    '«{0}»: цена покупателю {1}, итоговая прибыль {2}, маржа {3}.',
    '"{0}": buyer price {1}, total profit {2}, margin {3}.',
    [name, price, profit, margin],
  );
  String aiDealHeadline(String title, String profit, String margin) => _f(
    'Сделка {0}: чистая прибыль {1}, маржа {2}.',
    'Deal {0}: net profit {1}, margin {2}.',
    [title, profit, margin],
  );
  String aiLoss(String v) => _f(
    'Убыток {0}: цена ниже затрат. Пересмотрите цену или закупку.',
    'Loss of {0}: the price is below cost. Revise the price or the purchase.',
    [v],
  );
  String aiLowMargin(String m) => _f(
    'Маржа {0} — ниже рекомендуемых 5%. Риск: курс или фрахт съедят прибыль.',
    'Margin {0} is below the recommended 5%. Risk: FX or freight may eat the profit.',
    [m],
  );
  String aiHighMargin(String m) => _f(
    'Маржа {0} — высокая. Проверьте, что цена конкурентна для покупателя.',
    'Margin {0} is high. Check that the price is competitive for the buyer.',
    [m],
  );
  String aiGoodMargin(String m) =>
      _f('Маржа {0} — в норме.', 'Margin {0} is healthy.', [m]);
  String aiLogisticsShare(String share) => _f(
    'Логистика — {0} цены. Проверьте тариф или объём загрузки.',
    'Logistics is {0} of the price. Check the tariff or the load volume.',
    [share],
  );
  String aiAgentHigh(String p) => _f(
    'Агентские {0} — выше обычных 8–9%.',
    'Agent fee {0} is above the usual 8–9%.',
    [p],
  );
  String get aiAgentHidden => _t(
    'Агентские и маржа скрыты от покупателя ✓',
    'Agent fee and margin are hidden from the buyer ✓',
  );
  String aiBreakEven(String price) => _f(
    'Цена безубыточности: {0}. Ниже неё — убыток.',
    'Break-even price: {0}. Below it you lose money.',
    [price],
  );
  String aiPriceForMargin(String margin, String price) => _f(
    'Для маржи {0} нужна цена {1}.',
    'For a {0} margin the price should be {1}.',
    [margin, price],
  );
  String aiRoundPrice(String price, String gain) => _f(
    'Округлите цену до {0} — это +{1} прибыли.',
    'Round the price up to {0} — that is +{1} profit.',
    [price, gain],
  );
  String aiBonusOff(String bonus, String total) => _f(
    'НДС-бонус {0} не включён в прибыль. С ним прибыль была бы {1}.',
    'VAT bonus {0} is not counted in profit. With it profit would be {1}.',
    [bonus, total],
  );
  String aiBonusOn(String bonus) => _f(
    'НДС-бонус {0} включён в прибыль.',
    'VAT bonus {0} is included in profit.',
    [bonus],
  );
  String get aiRefundOff => _t(
    'Возврат НДС выключен. Если товар экспортный — проверьте ставку возврата в Китае.',
    'VAT refund is off. For export goods, check the China refund rate.',
  );
  String aiStale(int days) => _f(
    'Расчёт не обновлялся {0} дн. — проверьте цены, фрахт и курс.',
    'Not updated for {0} days — check prices, freight and FX.',
    [days],
  );
  String aiRatesStale(int days) => _f(
    'Курсы валют не обновлялись {0} дн. Откройте вкладку «Курсы».',
    'Exchange rates are {0} days old. Open the Rates tab.',
    [days],
  );
  String get aiRatesNever => _t(
    'Курсы CBU ещё не загружались — откройте вкладку «Курсы».',
    'CBU rates have not been loaded yet — open the Rates tab.',
  );
  String aiRatesFresh(String rate) => _f(
    'Курсы свежие. Кросс-курс: 1 USD = {0} CNY.',
    'Rates are fresh. Cross rate: 1 USD = {0} CNY.',
    [rate],
  );
  String aiFxDiff(String contract, String now) => _f(
    'Курс в контракте {0}, а сейчас {1}. Учтите курсовую разницу.',
    'The contract rate is {0}, now it is {1}. Mind the FX difference.',
    [contract, now],
  );
  String get aiBuyerHasInternal => _t(
    'В Контракте №1 есть логистика или агентские — покупатель может их увидеть. Перенесите их в Контракт №2.',
    'Contract #1 contains logistics or agent fee — the buyer may see them. Move them to Contract #2.',
  );
  String get aiMissingNumbers =>
      _t('Не заполнены номера контрактов.', 'Contract numbers are missing.');
  String get aiRefundPending => _t(
    'Сделка закрыта, а возврат НДС ещё не получен — напомните партнёру.',
    'The deal is closed but the VAT refund has not arrived — remind your partner.',
  );
  String get aiPayerTerms => _t(
    'Схема Payer: в Payment Terms укажите вашу компанию как «Payer».',
    'Payer scheme: name your company as the "Payer" in Payment Terms.',
  );
  String aiMonthSummary(int count, String profit, String margin) => _f(
    'В этом месяце {0} сделок, прибыль {1}, средняя маржа {2}.',
    'This month: {0} deals, profit {1}, average margin {2}.',
    [count, profit, margin],
  );
  String aiMonthLow(int n) => _f(
    'Сделок с маржой ниже 5%: {0}.',
    'Deals with margin below 5%: {0}.',
    [n],
  );
  String aiMonthPending(String v) =>
      _f('Ожидается НДС-бонус: {0}.', 'VAT bonus pending: {0}.', [v]);
  String aiMonthTrend(String delta) => _f(
    'По сравнению с прошлым месяцем: {0}.',
    'Compared with last month: {0}.',
    [delta],
  );
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => AppStrings.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

extension AppStringsX on BuildContext {
  AppStrings get s => AppStrings.of(this);
}
