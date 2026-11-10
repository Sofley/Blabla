import 'package:flutter/widgets.dart';

import '../../data/models/account.dart';
import '../../data/models/contract_stage.dart';
import '../../data/models/trade_contract.dart';

/// Lightweight localization (Russian / English) without code generation.
class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('ru'), Locale('en')];

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      const AppStrings(Locale('en'));

  bool get _ru => locale.languageCode == 'ru';
  String _t(String ru, String en) => _ru ? ru : en;

  // App & navigation
  String get appTitle => 'B2B Ledger';
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
      _t('Укажите номер: $contract', 'Enter the number: $contract');

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
      _t('Курс: 1 USD = ? $code', 'Rate: 1 USD = ? $code');
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
    'Прибыль = Контракт №1 без НДС − Контракт №2 (товар, логистика, агентские, НДС) + возврат НДС посреднику. Все суммы пересчитаны в USD по курсам на даты заключения.',
    'Profit = Contract #1 excl. VAT − Contract #2 (goods, logistics, agency, VAT) + VAT refund to the intermediary. All amounts converted to USD at rates on signing dates.',
  );

  // Stages
  String get status => _t('Статус', 'Status');
  String get statusTracker => _t('Этапы выполнения', 'Execution stages');
  String stage(ContractStage s) => switch (s) {
    ContractStage.signed => _t('Контракт подписан', 'Contract signed'),
    ContractStage.prepayment => _t('Предоплата', 'Prepayment'),
    ContractStage.factoryPaymentCny => _t(
      'Оплата заводу в CNY',
      'Factory payment (CNY)',
    ),
    ContractStage.inTransit => _t('В пути', 'In transit'),
    ContractStage.closed => _t('Закрыт', 'Closed'),
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
    'Учет ВЭД-контрактов по схеме Back-to-Back. Все данные хранятся только на устройстве.',
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
      _t('Придумайте PIN из $n цифр', 'Create a $n-digit PIN');
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
      _t('С возвращением, $name', 'Welcome back, $name');
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
  String attemptsLeft(int n) => _t('осталось попыток: $n', '$n attempts left');
  String tooManyAttempts(int sec) => _t(
    'Слишком много попыток. Подождите $sec с',
    'Too many attempts. Wait $sec s',
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
      _t('Файл сохранён: $name', 'File saved: $name');
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
  String restoreText(int deals, int quotes) => _t(
    'В копии: сделок — $deals, расчётов — $quotes. Текущие данные будут заменены.',
    'Backup contains $deals deals and $quotes calculations. Current data will be replaced.',
  );
  String get restoreDone => _t('Данные восстановлены', 'Data restored');
  String get invalidBackup => _t(
    'Файл не является резервной копией B2B Ledger',
    'Not a B2B Ledger backup file',
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
