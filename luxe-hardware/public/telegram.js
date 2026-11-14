// Marvan как Telegram Mini App: тот же сайт, открытый из бота внутри Telegram.
// На обычном сайте этот файл ничего не делает и ничего не загружает.
(() => {
  'use strict';
  // Telegram передаёт параметры запуска в адресе (#tgWebAppData=…). Запоминаем на всю сессию,
  // потому что при переходах по якорям (#catalog) адрес меняется.
  let inTelegram = /tgWebApp(Data|Version|Platform)=/.test(location.hash);
  try {
    if (inTelegram) sessionStorage.setItem('lh_tg', '1');
    else inTelegram = sessionStorage.getItem('lh_tg') === '1';
  } catch { /* приватный режим */ }
  if (!inTelegram) return;

  document.documentElement.classList.add('in-telegram');

  function start() {
    const tg = window.Telegram && window.Telegram.WebApp;
    if (!tg) return;
    tg.ready();
    tg.expand();
    const call = (name, ...args) => { try { if (typeof tg[name] === 'function') tg[name](...args); } catch { /* старая версия Telegram */ } };
    call('setHeaderColor', '#4A1220');         // шапка Telegram в цвет бургунди-шапки сайта
    call('setBackgroundColor', '#F6F4F0');
    call('setBottomBarColor', '#F6F4F0');
    call('disableVerticalSwipes');             // прокрутка страницы не сворачивает приложение

    // Ссылки: на Telegram — открываем чат внутри Telegram, на другие сайты — во встроенном браузере
    const isTg = (url) => /^https:\/\/(t\.me|telegram\.me)\//i.test(url);
    const openUrl = (url) => {
      if (isTg(url)) { call('openTelegramLink', url); return true; }
      if (/^https?:\/\//i.test(url) && new URL(url).origin !== location.origin) { call('openLink', url); return true; }
      return false;
    };
    document.addEventListener('click', (e) => {
      const a = e.target.closest('a[href]');
      if (a && openUrl(a.href)) e.preventDefault();
    }, true);
    // Форма заявки открывает Telegram через window.open — внутри Mini App используем API Telegram
    const nativeOpen = window.open.bind(window);
    window.open = (url, ...rest) => (url && openUrl(String(url)) ? null : nativeOpen(url, ...rest));

    // Кнопка «Назад» Telegram закрывает карточку товара
    const modal = document.getElementById('modal');
    const back = tg.BackButton;
    if (modal && back) {
      back.onClick(() => modal.close());
      new MutationObserver(() => (modal.open ? back.show() : back.hide())).observe(modal, { attributes: true, attributeFilter: ['open'] });
    }

    // Лёгкая вибрация при выборе товара и покрытия
    document.addEventListener('click', (e) => {
      if (e.target.closest('.card, .swatch, .chip, #mAdd')) { try { tg.HapticFeedback.impactOccurred('light'); } catch { /* */ } }
    });
  }

  if (window.Telegram && window.Telegram.WebApp) start();
  else {
    const s = document.createElement('script');
    s.src = 'https://telegram.org/js/telegram-web-app.js';
    s.onload = start;
    document.head.appendChild(s);
  }
})();
