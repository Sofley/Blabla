part of 'app_strings.dart';

/// Strings added in NexusTrade 3.0. Uzbek, Serbian and Chinese live in
/// tr_v3.dart, keyed by the English text.
extension AppStringsV3 on AppStrings {
  // ---------- Empty / confirmed zero ----------
  String get notSetValue => _t('Не задано', 'Not set');
  String get confirmZero => _t('Подтвердить 0', 'Confirm 0');
  String get confirmedZero => _t('Подтверждённый ноль', 'Confirmed zero');
  String get clearValue => _t('Очистить', 'Clear');
  String calculatedWithout(String list) =>
      _f('Рассчитано без: {0}', 'Calculated without: {0}', [list]);

  // ---------- Finance ----------
  String get agentVat => _t('НДС агента', 'Agent VAT');
  String get agentVatHint => _t(
    'Входит в цену клиента и не является вашим НДС. Пусто — «Не задано», ставка не подставляется.',
    'Included in the client price; not your VAT. Empty = not set, no rate is assumed.',
  );
  String get agencyBaseTitle => _t('База агентских', 'Agent fee base');
  String get agencyBaseV => _t('V = FOB + логистика', 'V = FOB + logistics');
  String get agencyBaseGoods =>
      _t('Себестоимость товара (EXW / FOB)', 'Goods cost (EXW / FOB)');
  String get agencyOnGoodsHint => _t(
    'Считается от себестоимости товара, независимо от EXW или FOB.',
    'Calculated on the goods cost, whether EXW or FOB.',
  );
  String get agencyPercentMode => _t('Процент', 'Percent');
  String get agencyFixedMode => _t('Фиксированная сумма', 'Fixed amount');
  String get agencyPercentOfGoods =>
      _t('Агентские, % от себестоимости', 'Agent fee, % of goods cost');
  String get agencyFixedAmount => _t('Агентские, сумма', 'Agent fee, amount');
  String get agentVatSwitch =>
      _t('НДС на услуги агента', 'VAT on agent services');
  String get logisticsManual => _t('Суммы', 'Amounts');
  String get logisticsPerTonne => _t('За тонну', 'Per tonne');
  String get logisticsPerTransport =>
      _t('За фуру / контейнер', 'Per truck / container');
  String get transportType =>
      _t('Тип транспорта и загрузки', 'Transport and loading type');
  String get transportTypes => _t('Типы транспорта', 'Transport types');
  String get newTransportType =>
      _t('Новый тип транспорта', 'New transport type');
  String get ratePerTonne => _t('Ставка за тонну', 'Rate per tonne');
  String get ratePerTransportUnit =>
      _t('Ставка за фуру / контейнер', 'Rate per truck / container');
  String get cargoWeightTonnes => _t('Вес партии, т', 'Batch weight, t');
  String get transportUnitsCount =>
      _t('Количество фур / контейнеров', 'Number of trucks / containers');
  String get capacityTonnes =>
      _t('Вместимость, т (пусто — не задана)', 'Capacity, t (empty = not set)');
  String get recalculate => _t('Пересчитать', 'Recalculate');
  String get capacityNotSetHint => _t(
    'Вместимость не задана — укажите количество вручную или задайте вместимость в Настройках.',
    'Capacity is not set — enter the number by hand or set the capacity in Settings.',
  );
  String unitsAutoHint(int n, double cap) => _f(
    'По весу: {0} шт. по {1} т. Можно изменить вручную.',
    'By weight: {0} × {1} t. Can be changed by hand.',
    [n, Fmt.editable(cap)],
  );
  String get vBase => _t('V (FOB + логистика)', 'V (FOB + logistics)');
  String get closingRate => _t('Курс на дату закрытия', 'Rate on closing date');
  String get closingRateHint => _t(
    'Нужен только для курсовой разницы. Прибыль не меняет.',
    'Only for the exchange difference. Does not change the profit.',
  );
  String get fxDifference =>
      _t('Курсовая разница (информация)', 'Exchange difference (info)');
  String get fxDifferenceHint => _t(
    'Показывается отдельно и не входит в прибыль.',
    'Shown separately; not part of the profit.',
  );
  String get pricingProfitPerUnit => _t('Прибыль/ед.', 'Profit/unit');
  String get profitPerUnitMode => _t('Прибыль за единицу', 'Profit per unit');
  String get profitPerUnitHint => _t(
    'USD за единицу Контракта №1 (например, 0,33 за кг). Цена считается от полной себестоимости.',
    'USD per unit of Contract #1 (e.g. 0.33 per kg). The price is calculated from the full cost.',
  );
  String get defaultProfitPerUnit =>
      _t('Прибыль по умолчанию, USD за ед.', 'Default profit, USD per unit');
  String get defaultAgentVat =>
      _t('НДС агента по умолчанию', 'Default agent VAT');
  String get defaultVatShare =>
      _t('Моя доля возврата НДС по умолчанию', 'My default VAT refund share');
  String get vatShareHint => _t(
    'Возврат НДС (9 % от FOB) получает китайская компания-посредник. Ваша доля по умолчанию — 0 %.',
    'The VAT refund (9% of FOB) is received by the Chinese intermediary company. Your default share is 0%.',
  );
  String get profitIncomplete => _t(
    'Не все поля заполнены — проверьте расчёт',
    'Some fields are not filled in — check the calculation',
  );

  // ---------- Stages ----------
  String get stageHistory => _t('История этапов', 'Stage history');
  String get oldStageName => _t('название до версии 3.0', 'name before v3.0');
  String changedBy(String name) =>
      _f('изменил(а): {0}', 'changed by: {0}', [name]);
  String get paymentStageHint =>
      _t('Оплата — 100 % от покупателя', 'Payment — 100% from the buyer');

  // ---------- Trash ----------
  String get trash => _t('Корзина', 'Trash');
  String get moveToTrash => _t('В корзину', 'Move to trash');
  String get moveToTrashQuestion =>
      _t('Переместить сделку в корзину?', 'Move the deal to the trash?');
  String get moveToTrashHint => _t(
    'Сделка хранится в корзине 15 дней, её можно восстановить. Затем она удаляется окончательно вместе с документами.',
    'The deal is kept in the trash for 15 days and can be restored. After that it is deleted for good together with its documents.',
  );
  String get movedToTrash =>
      _t('Сделка перемещена в корзину', 'Deal moved to the trash');
  String get undo => _t('Отменить', 'Undo');
  String get restoreDeal => _t('Восстановить', 'Restore');
  String get deleteForever => _t('Удалить навсегда', 'Delete for good');
  String get deleteForeverQuestion =>
      _t('Удалить сделку навсегда?', 'Delete the deal for good?');
  String get deleteForeverHint => _t(
    'Сделка, её документы и чат будут удалены без возможности восстановления. В ранее созданных резервных копиях она останется.',
    'The deal, its documents and chat will be deleted with no way back. It remains in backups made earlier.',
  );
  String daysLeft(int n) =>
      _f('Удаление через {0} дн.', 'Deleted in {0} d', [n]);
  String get trashEmpty => _t('Корзина пуста', 'The trash is empty');
  String get trashHint => _t(
    'Удалённые сделки хранятся 15 дней.',
    'Deleted deals are kept for 15 days.',
  );
  String get dealInTrash => _t('Сделка в корзине', 'The deal is in the trash');

  // ---------- Documents ----------
  String get documents => _t('Документы', 'Documents');
  String get addDocument => _t('Добавить документ', 'Add document');
  String get noDocuments => _t('Документов нет', 'No documents');
  String get documentsEncryptedHint => _t(
    'Файлы хранятся на телефоне в зашифрованном виде.',
    'Files are stored on the phone encrypted.',
  );
  String get deleteDocumentQuestion =>
      _t('Удалить документ?', 'Delete the document?');
  String get fileTooLarge =>
      _t('Файл больше 20 МБ', 'The file is larger than 20 MB');

  // ---------- Delivery ----------
  String get deliveryInfo =>
      _t('Условия и сроки поставки', 'Delivery terms and dates');
  String get deliveryInfoHint => _t(
    'Маршрут, базис, ожидаемые даты. Это видит клиент.',
    'Route, terms, expected dates. The client sees this.',
  );

  // ---------- Clients ----------
  String get clients => _t('Клиенты', 'Clients');
  String get client => _t('Клиент', 'Client');
  String get newClient => _t('Новый клиент', 'New client');
  String get editClient => _t('Клиент', 'Client');
  String get companyNameField => _t('Название компании', 'Company name');
  String get contactPerson => _t('Контактное лицо', 'Contact person');
  String get phoneField => _t('Телефон', 'Phone');
  String get emailField => _t('Эл. почта', 'Email');
  String get address => _t('Адрес', 'Address');
  String get noClients => _t('Клиентов пока нет', 'No clients yet');
  String get clientDeals => _t('Сделки клиента', 'Client deals');
  String get dealsCount => _t('Сделок', 'Deals');
  String get dealsSum => _t('Сумма сделок', 'Deals total');
  String get noClient => _t('Без клиента', 'No client');
  String get selectClient => _t('Выбрать клиента', 'Select client');
  String get deleteClientQuestion =>
      _t('Удалить клиента?', 'Delete the client?');
  String get deleteClientHint => _t(
    'Сделки останутся, связь с клиентом будет снята.',
    'Deals stay; they will no longer be linked to the client.',
  );
  String get nameRequired => _t('Укажите название', 'Enter a name');

  // ---------- Monthly report ----------
  String get monthlyReport => _t('Отчёт за месяц', 'Monthly report');
  String get profitByClient => _t('Прибыль по клиентам', 'Profit by client');
  String get byMonthOfSigning => _t(
    'Сделка относится к месяцу подписания Контракта №1.',
    'A deal belongs to the month Contract #1 was signed.',
  );
  String get monthProfitTotal => _t('Общая прибыль', 'Total profit');

  // ---------- Users & roles ----------
  String get workSection => _t('Работа', 'Work');
  String get users => _t('Пользователи', 'Users');
  String roleName(UserRole r) => switch (r) {
    UserRole.owner => _t('Владелец', 'Owner'),
    UserRole.admin => _t('Администратор', 'Administrator'),
    UserRole.manager => _t('Менеджер', 'Manager'),
    UserRole.partner => _t('Партнёр', 'Partner'),
    UserRole.client => _t('Клиент', 'Client'),
  };
  String roleHint(UserRole r) => switch (r) {
    UserRole.owner => _t(
      'Полный доступ, включая внутренние финансы.',
      'Full access, including internal finance.',
    ),
    UserRole.admin => _t(
      'Пользователи, сделки, документы, этапы. Без внутренних финансов.',
      'Users, deals, documents, stages. No internal finance.',
    ),
    UserRole.manager => _t(
      'Назначенные сделки, документы, этапы. Без внутренних финансов.',
      'Assigned deals, documents, stages. No internal finance.',
    ),
    UserRole.partner => _t(
      'Основная информация и этапы назначенных сделок.',
      'Basic info and stages of assigned deals.',
    ),
    UserRole.client => _t(
      'Только свои сделки: стороны, товар, сумма, сроки, поставка.',
      'Own deals only: parties, goods, amount, dates, delivery.',
    ),
  };
  String get addUser => _t('Добавить пользователя', 'Add user');
  String get userName => _t('Имя', 'Name');
  String get roleField => _t('Роль', 'Role');
  String get profilePin =>
      _t('PIN-код профиля (4–6 цифр)', 'Profile PIN (4–6 digits)');
  String get newPinOptional =>
      _t('Новый PIN (пусто — без изменений)', 'New PIN (empty = unchanged)');
  String get pinInvalid => _t('PIN — от 4 до 6 цифр', 'PIN must be 4–6 digits');
  String get usersHint => _t(
    'Профили для работы на этом телефоне. Внутренние финансы видит только владелец.',
    'Profiles for working on this phone. Only the owner sees internal finance.',
  );
  String get noUsers => _t('Других пользователей нет', 'No other users');
  String get deleteUserQuestion =>
      _t('Удалить пользователя?', 'Delete the user?');
  String get switchUser => _t('Сменить пользователя', 'Switch user');
  String get signInAs => _t('Войти как', 'Sign in as');
  String get ownerAccount => _t('Владелец', 'Owner');
  String signedInAs(String name, String role) =>
      _f('{0} · {1}', '{0} · {1}', [name, role]);
  String get assignedTo => _t('Доступ к сделке', 'Deal access');
  String get assignHint => _t(
    'Менеджеры и партнёры видят только назначенные им сделки.',
    'Managers and partners see only the deals assigned to them.',
  );
  String get noDealsForRole => _t('Нет доступных сделок', 'No deals available');
  String get clientLink =>
      _t('Клиент (чьи сделки видны)', 'Client (whose deals are visible)');
  String get financeOwnerOnly => _t(
    'Финансовые показатели доступны только владельцу.',
    'Financial figures are available to the owner only.',
  );
  String get enterProfilePin => _t('Введите PIN', 'Enter PIN');

  // ---------- Backups ----------
  String get backups => _t('Резервные копии', 'Backups');
  String get backupNow => _t('Создать копию сейчас', 'Back up now');
  String get restoreFromFile =>
      _t('Восстановить из файла', 'Restore from file');
  String lastBackup(String when) =>
      _f('Последняя копия: {0}', 'Last backup: {0}', [when]);
  String lastSavedOutside(String when) => _f(
    'Последнее сохранение вне телефона: {0}',
    'Last saved outside the phone: {0}',
    [when],
  );
  String get never => _t('ещё не было', 'never');
  String get backupEncryptedHint => _t(
    'Копия зашифрована (AES-256) ключом из вашего пароля. Без пароля её открыть нельзя.',
    'The backup is encrypted (AES-256) with a key from your password. It cannot be opened without the password.',
  );
  String get weeklyBackupReady =>
      _t('Еженедельная резервная копия готова', 'Weekly backup is ready');
  String get weeklyBackupText => _t(
    'Сохраните её в Google Drive: в открывшемся окне выберите «Google Диск».',
    'Save it to Google Drive: choose "Drive" in the window that opens.',
  );
  String get saveToDrive =>
      _t('Сохранить в Google Drive', 'Save to Google Drive');
  String get saveAsFile => _t('Сохранить файлом', 'Save as file');
  String get later => _t('Позже', 'Later');
  String get wrongPassword => _t('Неверный пароль', 'Wrong password');
  String get backupPasswordNeeded => _t(
    'Введите пароль аккаунта, чтобы включить шифрование резервных копий',
    'Enter the account password to enable encrypted backups',
  );
  String get backupFilePassword => _t(
    'Пароль, с которым создана копия',
    'Password the backup was made with',
  );
  String get wrongBackupPassword => _t(
    'Неверный пароль или файл повреждён',
    'Wrong password or damaged file',
  );
  String get restoreReplaceQuestion => _t(
    'Заменить данные на телефоне данными из копии?',
    'Replace the data on this phone with the backup?',
  );
  String get restoreSafetyHint => _t(
    'Перед восстановлением текущие данные будут сохранены в отдельную резервную копию.',
    'Before restoring, the current data is saved to a separate backup.',
  );
  String get registrationBackupWarning => _t(
    'Пароль защищает вход и резервные копии. Если вы его забудете, данные из копии восстановить будет невозможно. Запишите пароль и храните его в надёжном месте.',
    'The password protects sign-in and backups. If you forget it, data in a backup cannot be recovered. Write the password down and keep it somewhere safe.',
  );
  String get oldBackupPasswordNote => _t(
    'После смены пароля старые копии открываются старым паролем.',
    'After a password change, older backups open with the old password.',
  );
  String get driveNote => _t(
    'Google Drive — удобное хранилище, но не решение по юридическим требованиям к хранению персональных данных.',
    'Google Drive is convenient storage, not a solution for legal requirements on personal data storage.',
  );
  String get backupsOnPhone => _t('Копии на телефоне', 'Backups on the phone');
  String get shareAction => _t('Поделиться', 'Share');
  String get oldFormatBackup => _t(
    'Копия старой версии (без шифрования) — восстановлена.',
    'Backup of an older version (not encrypted) — restored.',
  );

  // ---------- Reminders ----------
  String get reminders => _t('Напоминания', 'Reminders');
  String reminderFrequency(int days) => switch (days) {
    1 => _t('Ежедневно', 'Daily'),
    3 => _t('Каждые 3 дня', 'Every 3 days'),
    7 => _t('Еженедельно', 'Weekly'),
    _ => _t('Выключены', 'Off'),
  };
  String get reminderTime => _t('Время', 'Time');
  String get reminderBody => _t(
    'Проверьте статусы сделок, оплаты и сроки.',
    'Check deal stages, payments and dates.',
  );
  String get notificationsDenied => _t(
    'Разрешите уведомления для NexusTrade в настройках телефона.',
    'Allow notifications for NexusTrade in the phone settings.',
  );

  // ---------- Online tariffs ----------
  String get onlineTariffs => _t('Онлайн-тарифы', 'Online tariffs');
  String get onlineTariffsHint => _t(
    'Появятся после подключения платных сервисов логистики (этап 3). Сейчас используются только ваши тарифы.',
    'Will appear once paid logistics services are connected (stage 3). For now only your own tariffs are used.',
  );
  String get noTariffs => _t(
    'Тарифов нет. Добавьте свои маршруты и ставки.',
    'No tariffs. Add your own routes and rates.',
  );

  // ---------- Home-screen widget ----------
  String get widgetSection =>
      _t('Виджет на рабочем столе', 'Home screen widget');
  String get widgetActiveContracts =>
      _t('Активные контракты', 'Active contracts');
  String get widgetNoDeals => _t('Нет сделок', 'No deals');
  String get widgetContractSum => _t('Сумма контракта', 'Contract amount');
  String get widgetHideAmounts =>
      _t('Скрыть суммы в виджете', 'Hide amounts in the widget');
  String get widgetHideHint => _t(
    'Виджет виден без разблокировки телефона. Включите, чтобы вместо суммы и прибыли показывались точки.',
    'The widget is visible without unlocking the phone. Turn on to show dots instead of the amount and profit.',
  );
  String get widgetHowToAdd => _t(
    'Добавить: долгое нажатие на рабочем столе → Виджеты → NexusTrade.',
    'To add: long-press the home screen → Widgets → NexusTrade.',
  );
  String get showInWidget => _t('Показывать в виджете', 'Show in the widget');
  String get shownInWidget =>
      _t('Эта сделка показана в виджете', 'This deal is shown in the widget');
  String get widgetDealAuto => _t(
    'Последняя активная сделка (автоматически)',
    'Latest active deal (automatic)',
  );

  // ---------- Two-party contract ----------
  String get kindTwoParty => _t('Двусторонний', 'Two-party');
  String get twoPartyContract =>
      _t('Двусторонний контракт', 'Two-party contract');
  String get twoPartyContractHint => _t(
    'Один контракт: Покупатель ↔ Продавец. Ваш расчёт — во вкладке «Внутренний расчёт».',
    'One contract: Buyer ↔ Seller. Your calculation is on the internal tab.',
  );
  String get twoPartiesShort => _t('Покупатель ↔ Продавец', 'Buyer ↔ Seller');

  // ---------- Deal number & snapshots ----------
  String get dealNumberTitle => _t('Номер сделки', 'Deal number');
  String get dealNumberAuto =>
      _t('Присвоится автоматически (NT-…)', 'Assigned automatically (NT-…)');
  String get dealNumberHint => _t(
    'Формат NT-ГГГГ-NNNN. Можно изменить вручную, номер должен быть уникальным.',
    'Format NT-YYYY-NNNN. Can be changed by hand; it must be unique.',
  );
  String get dealNumberTaken =>
      _t('Такой номер сделки уже есть', 'This deal number is already used');
  String get calcSnapshots => _t('Снимки расчёта', 'Calculation snapshots');
  String snapshotEvent(String e) => switch (e) {
    'closed' => _t('При закрытии', 'At closing'),
    _ => _t('При подписании', 'At signing'),
  };
  String get snapshotsHint => _t(
    'Расчёт фиксируется при подписании и при закрытии сделки и потом не меняется.',
    'The calculation is frozen at signing and at closing and never changes afterwards.',
  );
  String get currentCalc => _t('Сейчас', 'Now');

  // ---------- Dossier ----------
  String get officialContract =>
      _t('Официальный контракт', 'Official contract');
  String get contractAttached => _t('Контракт прикреплён', 'Contract attached');
  String get contractNotAttached =>
      _t('Контракт не прикреплён', 'Contract not attached');
  String get officialContractNumber => _t('Номер договора', 'Contract number');
  String get officialContractDate =>
      _t('Дата заключения', 'Date of conclusion');
  String get addAction => _t('Добавить', 'Add');
  String get replaceAction => _t('Заменить', 'Replace');
  String get viewAction => _t('Просмотр', 'View');
  String get downloadAction => _t('Скачать', 'Download');
  String docCategory(DocCategory c) => switch (c) {
    DocCategory.mainContract => _t(
      'Основной официальный договор',
      'Main official contract',
    ),
    DocCategory.invoice => _t('Invoice / Инвойсы', 'Invoices'),
    DocCategory.appendix => _t('Приложения к договору', 'Contract annexes'),
    DocCategory.supplement => _t(
      'Дополнительные соглашения',
      'Supplementary agreements',
    ),
    DocCategory.correction => _t(
      'Корректировки и исправленные документы',
      'Corrections and corrected documents',
    ),
    DocCategory.other => _t('Прочие документы', 'Other documents'),
  };
  String docStatus(DocStatus st) => switch (st) {
    DocStatus.active => _t('Действующий', 'Active'),
    DocStatus.replaced => _t('Заменённый', 'Replaced'),
    DocStatus.cancelled => _t('Аннулированный', 'Cancelled'),
  };
  String get docCategoryTitle => _t('Категория', 'Category');
  String get docTitle => _t('Название документа', 'Document name');
  String get docNumber => _t('Номер документа', 'Document number');
  String get docDate => _t('Дата документа', 'Document date');
  String get docStatusTitle => _t('Статус', 'Status');
  String get fileName => _t('Файл', 'File');
  String get uploaded => _t('загружен', 'uploaded');
  String versionsCount(int n) => _f('версий: {0}', 'versions: {0}', [n]);
  String get versionHistory => _t('История версий', 'Version history');
  String get currentVersion => _t('текущая', 'current');
  String get originalVersion => _t('первоначальная', 'original');
  String get previousVersion => _t('предыдущая', 'previous');
  String get relatedContract =>
      _t('К основному договору', 'Belongs to the main contract');
  String get correctsDocument =>
      _t('Исправляет документ', 'Corrects the document');
  String get visibleToClient =>
      _t('Показывать клиенту и партнёру', 'Show to the client and partner');
  String get visibleToClientHint => _t(
    'По умолчанию выключено: внутренние документы не показываются.',
    'Off by default: internal documents are not shown.',
  );
  String deleteDocumentHint(int n) => _f(
    'Будут удалены все версии файла ({0}). Действие нельзя отменить; в ранее созданных резервных копиях документ останется.',
    'All file versions ({0}) will be deleted. This cannot be undone; the document stays in backups made earlier.',
    [n],
  );
  String get noViewerApp => _t(
    'На телефоне нет приложения для этого формата. Используйте «Скачать».',
    'No app on the phone opens this format. Use "Download".',
  );
}
