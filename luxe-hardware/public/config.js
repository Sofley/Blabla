// ============================================================
//  НАСТРОЙКИ САЙТА — всё, что владелец меняет, находится здесь.
//  Ниже стоят примерные данные: замените их на свои перед запуском.
// ============================================================
window.SITE = {
  brand: 'Luxe Hardware',

  phone: '+7 (495) 123-45-67',        // как показывать
  phoneHref: '+74951234567',          // для ссылки tel:
  email: 'order@luxehardware.ru',
  telegram: 'luxehardware_manager',   // ник менеджера без @ — кнопка «Написать в Telegram»
  address: 'Москва, ул. Электрозаводская, 21, стр. 4, офис 308',
  hours: 'Пн–Пт, 10:00–19:00',

  // Соцсети. Пустая строка — иконка не показывается.
  // Ссылки на сайт В ЭТИХ соцсетях ставьте с UTM-метками, например:
  //   https://ваш-сайт.ru/?utm_source=instagram&utm_medium=bio
  //   https://ваш-сайт.ru/?utm_source=youtube&utm_medium=video&utm_campaign=obzor_karabinov
  // Тогда в статистике точно будет видно, откуда пришёл человек.
  socials: {
    telegram: 'https://t.me/luxehardware',
    instagram: 'https://instagram.com/luxehardware',
    youtube: 'https://youtube.com/@luxehardware',
    google: 'https://maps.google.com/?q=Luxe+Hardware+Москва', // карточка компании в Google Картах
  },

  // Внешняя аналитика (необязательно). Пусто — счётчик не загружается.
  analytics: {
    yandexMetrikaId: '',      // например '98765432' — рекомендуется для РФ (Вебвизор, география)
    googleAnalyticsId: '',    // например 'G-XXXXXXXXXX'
  },

  // Адрес сервера заявок. Пусто — тот же домен, что и сайт.
  apiBase: '',
};
