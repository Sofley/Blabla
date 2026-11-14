(() => {
  'use strict';
  const $ = (s) => document.querySelector(s);
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const EVENTS = {
    tg_click: 'Нажали «Telegram»', phone_click: 'Нажали на телефон', email_click: 'Нажали на почту',
    product_open: 'Открыли карточку товара', request_add: 'Добавили в запрос', lead_submit: 'Отправили заявку',
    social_click: 'Перешли в соцсеть', samples_click: 'Интерес к боксу образцов',
  };
  const fmt = (n) => Number(n).toLocaleString('ru-RU');

  function bars(el, rows, opts = {}) {
    if (!rows.length) { el.innerHTML = '<p class="empty">Пока нет данных</p>'; return; }
    const max = Math.max(...rows.map((r) => r.v), 1);
    el.innerHTML = rows.map((r) => `
      <div class="bar">
        <span class="bar__label" title="${esc(r.label)}">${esc(r.label)}</span>
        <span class="bar__track"><span class="bar__fill" style="width:0" data-w="${(r.v / max * 100).toFixed(1)}%"></span></span>
        <span class="bar__n"><b>${fmt(r.v)}</b>${opts.second ? ' · ' + fmt(r.v2) : ''}</span>
      </div>`).join('');
    requestAnimationFrame(() => el.querySelectorAll('.bar__fill').forEach((b) => { b.style.width = b.dataset.w; }));
  }

  function chart(el, daily) {
    const W = 1000, H = 220, P = { l: 30, r: 10, t: 10, b: 24 };
    const max = Math.max(...daily.map((d) => d.sessions), 1);
    const step = (W - P.l - P.r) / daily.length;
    const bw = Math.max(Math.min(step * 0.62, 28), 2);
    const y = (v) => H - P.b - (v / max) * (H - P.t - P.b);
    const ticks = [0, Math.ceil(max / 2), max];
    let s = ticks.map((t) => `<line x1="${P.l}" x2="${W - P.r}" y1="${y(t)}" y2="${y(t)}" stroke="#ECE7DF"/><text x="${P.l - 6}" y="${y(t) + 3}" text-anchor="end">${t}</text>`).join('');
    const every = Math.ceil(daily.length / 10);
    daily.forEach((d, i) => {
      const x = P.l + i * step + (step - bw) / 2;
      const h = H - P.b - y(d.sessions);
      s += `<rect x="${x}" y="${y(d.sessions)}" width="${bw}" height="${Math.max(h, d.sessions ? 2 : 0)}" rx="3" fill="#22201E"><title>${d.day}: ${d.sessions} виз., ${d.leads} заяв.</title></rect>`;
      if (d.leads) s += `<circle cx="${x + bw / 2}" cy="${y(d.sessions) - 8}" r="${Math.min(3 + d.leads, 7)}" fill="#B8955F"><title>${d.leads} заяв.</title></circle>`;
      if (i % every === 0) s += `<text x="${x + bw / 2}" y="${H - 6}" text-anchor="middle">${d.day.slice(8)}.${d.day.slice(5, 7)}</text>`;
    });
    el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none" role="img" aria-label="Визиты по дням">${s}</svg>`;
  }

  async function load(days) {
    const r = await fetch('/admin/api/stats?days=' + days, { cache: 'no-store' });
    if (!r.ok) { $('#foot').textContent = 'Не удалось загрузить статистику'; return; }
    const d = await r.json();
    const t = d.totals;
    $('#kpis').innerHTML = [
      ['Визиты', t.sessions], ['Посетители', t.visitors], ['Просмотры', t.pageviews], ['Заявки', t.leads], ['Конверсия', t.conversion + '%'],
    ].map(([k, v]) => `<div class="kpi"><div class="kpi__v">${typeof v === 'number' ? fmt(v) : v}</div><div class="kpi__k">${k}</div></div>`).join('');
    chart($('#chart'), d.daily);
    bars($('#sources'), d.sources.map((s) => ({ label: s.label, v: s.sessions, v2: s.leads })), { second: true });
    bars($('#clicks'), d.clicks.map((c) => ({ label: EVENTS[c.name] || c.name, v: c.n })));
    bars($('#products'), d.products.map((c) => ({ label: c.name, v: c.n })));
    bars($('#devices'), d.devices.map((c) => ({ label: c.name, v: c.n })));
    bars($('#regions'), d.regions.map((c) => ({ label: c.name.replace(/_/g, ' '), v: c.n })));
    bars($('#campaigns'), d.campaigns.map((c) => ({ label: c.name, v: c.n })));
    bars($('#referrers'), d.referrers.map((c) => ({ label: c.name, v: c.n })));
    $('#leads').innerHTML = d.recentLeads.length
      ? '<thead><tr><th>№</th><th>Дата</th><th>Имя</th><th>Контакт</th><th>Ответ через</th><th>Позиции и комментарий</th><th>Источник</th></tr></thead><tbody>' +
        d.recentLeads.map((l) => `<tr>
          <td>${l.id}</td>
          <td>${new Date(l.t).toLocaleString('ru-RU', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })}</td>
          <td>${esc(l.name)}</td><td>${esc(l.contact)}</td><td>${esc(l.channel)}</td>
          <td class="pre">${esc([l.items, l.comment].filter(Boolean).join('\n\n'))}</td>
          <td><span class="tag">${esc(l.src)}</span>${l.delivered ? '' : ' <span class="tag tag--warn" title="Не доставлено в Telegram — проверьте настройки бота">не в TG</span>'}</td>
        </tr>`).join('') + '</tbody>'
      : '<tbody><tr><td class="empty">Заявок за период нет</td></tr></tbody>';
    $('#foot').textContent = 'Обновлено ' + new Date(d.generatedAt).toLocaleTimeString('ru-RU') + ' · обновляется каждую минуту';
  }

  let days = 30;
  $('#period').addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    document.querySelectorAll('#period button').forEach((x) => x.classList.toggle('is-active', x === b));
    days = +b.dataset.d; load(days);
  });
  load(days);
  setInterval(() => load(days), 60_000);
})();
