import 'package:flutter/widgets.dart';

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
  String get goodsSection =>
      _t('Стоимость закупа товара', 'Goods purchase cost');
  String get goodsCost => _t('Стоимость товара', 'Goods cost');
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
    'Прибыль = Контракт №1 без НДС − Контракт №2 (товар, логистика, агентские, НДС). Все суммы пересчитаны в USD по курсам на даты заключения.',
    'Profit = Contract #1 excl. VAT − Contract #2 (goods, logistics, agency, VAT). All amounts converted to USD at rates on signing dates.',
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
  String get themeSystem => _t('Системная', 'System');
  String get themeLight => _t('Светлая', 'Light');
  String get themeDark => _t('Темная', 'Dark');
  String get language => _t('Язык', 'Language');
  String get languageSystem => _t('Как в системе', 'System default');
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
