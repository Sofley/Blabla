// Редактор каталога для сайта без сервера (GitHub Pages).
// Работает целиком в браузере: читает products.json, даёт править товары через форму
// и выдаёт готовый products.json — его вставляют в файл на GitHub.
(() => {
  'use strict';
  const $ = (s) => document.querySelector(s);
  const S = window.SITE || {};
  const GH = S.github || {};
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const TAG_NAMES = { bags: 'Сумки', clutches: 'Клатчи', belts: 'Ремни', small: 'Мелкая галантерея' };
  const FINISH_KEYS = ['champagne', 'nickel', 'silver', 'bronze'];
  const DRAFT = 'lh_catalog_draft';
  const form = $('#pform'), editor = $('#editor');
  let products = [], original = '[]', editingIndex = -1;
  const localPhotos = {}; // имя файла → { url для предпросмотра, file }

  // Ссылки на GitHub
  if (GH.repo && GH.branch) {
    const base = `https://github.com/${GH.repo}`;
    $('#ghEdit').href = `${base}/edit/${GH.branch}/${GH.folder}/products.json`;
    $('#ghUpload').href = `${base}/upload/${GH.branch}/${GH.folder}/images`;
  }

  const store = {
    get() { try { return JSON.parse(localStorage.getItem(DRAFT)); } catch { return null; } },
    set(v) { try { localStorage.setItem(DRAFT, JSON.stringify(v)); } catch { /* приватный режим */ } },
    clear() { try { localStorage.removeItem(DRAFT); } catch { /* */ } },
  };
  function setStatus(text, err) { const el = $('#status'); el.textContent = text; el.classList.toggle('is-err', !!err); }
  const output = () => JSON.stringify(products, null, 2) + '\n';
  function changed() { store.set(products); render(); setStatus(output() !== original ? 'Есть изменения — не забудьте сохранить на GitHub (шаг 3).' : ''); }

  function render() {
    $('#listTitle').textContent = products.length ? `Товары: ${products.length}` : 'Товары';
    $('#empty').hidden = products.length > 0;
    $('#list').innerHTML = products.map((p, i) => {
      const src = localPhotos[p.photo]?.url || p.photo;
      return `
      <div class="pitem${p.hidden ? ' is-hidden' : ''}">
        <div class="pitem__thumb">${p.photo ? `<img src="${esc(src)}" alt="" onerror="this.replaceWith(document.createTextNode('фото ещё не загружено'))">` : (p.draw ? 'иллюстр.' : 'нет фото')}</div>
        <div>
          <div class="pitem__title">${esc(p.id)} · ${esc(p.title)}</div>
          <div class="pitem__meta">${p.price == null ? 'цена по запросу' : Number(p.price).toLocaleString('ru-RU') + ' ' + (S.currency || 'сум') + ' / ' + esc(p.unit)} · ${(p.tags || []).map((t) => TAG_NAMES[t]).join(', ') || 'без категории'}${p.hidden ? ' · скрыт' : ''}</div>
        </div>
        <div class="pitem__actions">
          <button class="btn btn--sm" data-act="up" data-i="${i}" ${i === 0 ? 'disabled' : ''} aria-label="Выше">↑</button>
          <button class="btn btn--sm" data-act="down" data-i="${i}" ${i === products.length - 1 ? 'disabled' : ''} aria-label="Ниже">↓</button>
          <button class="btn btn--sm" data-act="edit" data-i="${i}">Изменить</button>
        </div>
      </div>`;
    }).join('');
  }

  const translit = (s) => {
    const m = { а: 'a', б: 'b', в: 'v', г: 'g', д: 'd', е: 'e', ё: 'e', ж: 'zh', з: 'z', и: 'i', й: 'y', к: 'k', л: 'l', м: 'm', н: 'n', о: 'o', п: 'p', р: 'r', с: 's', т: 't', у: 'u', ф: 'f', х: 'h', ц: 'c', ч: 'ch', ш: 'sh', щ: 'sch', ъ: '', ы: 'y', ь: '', э: 'e', ю: 'yu', я: 'ya', ў: 'o', қ: 'q', ғ: 'g', ҳ: 'h' };
    return s.toLowerCase().split('').map((c) => m[c] ?? c).join('').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 50) || 'foto';
  };

  function setPhoto(name) {
    form.elements.photo.value = name || '';
    const src = localPhotos[name]?.url || name;
    $('#photoPreview').hidden = !name; if (name) $('#photoPreview').src = src;
    $('#photoEmpty').hidden = !!name;
    $('#photoRemove').hidden = !name;
    $('#photoSmall').hidden = !localPhotos[name];
  }
  $('#photoPreview').addEventListener('error', () => { $('#photoPreview').hidden = true; $('#photoEmpty').hidden = false; $('#photoEmpty').textContent = 'Фото ещё не загружено на GitHub'; });

  function openEditor(i) {
    editingIndex = i;
    const p = i >= 0 ? products[i] : null;
    form.reset();
    $('#formTitle').textContent = p ? 'Изменить ' + p.id : 'Новый товар';
    $('#deleteBtn').hidden = !p;
    $('#formErrors').textContent = '';
    $('#photoEmpty').textContent = 'Нет фото — на сайте будет иллюстрация';
    if (p) {
      for (const k of ['id', 'title', 'use', 'desc', 'unit', 'moq', 'draw', 'finish']) form.elements[k].value = p[k] ?? '';
      form.elements.price.value = p.price ?? '';
      form.elements.specs.value = Object.entries(p.specs || {}).map(([k, v]) => `${k}: ${v}`).join('\n');
      form.querySelectorAll('[name=tags]').forEach((c) => { c.checked = (p.tags || []).includes(c.value); });
      form.querySelectorAll('[name=finishes]').forEach((c) => { c.checked = (p.finishes || FINISH_KEYS).includes(c.value); });
      form.elements.hidden.checked = !!p.hidden;
    }
    setPhoto(p?.photo || '');
    editor.showModal();
    form.elements[p ? 'title' : 'id'].focus();
  }

  // Фото: показываем сразу, имя файла подставляем латиницей, уменьшенную копию можно скачать для загрузки на GitHub
  function resize(file) {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => {
        const k = Math.min(1, 1400 / Math.max(img.width, img.height));
        const c = document.createElement('canvas'); c.width = Math.round(img.width * k); c.height = Math.round(img.height * k);
        const ctx = c.getContext('2d'); ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, c.width, c.height); ctx.drawImage(img, 0, 0, c.width, c.height);
        c.toBlob((b) => (b ? resolve(b) : reject(new Error('Не удалось обработать фото'))), 'image/jpeg', 0.86);
      };
      img.onerror = () => reject(new Error('Не удалось прочитать фото'));
      img.src = URL.createObjectURL(file);
    });
  }
  $('#photoInput').addEventListener('change', async (e) => {
    const file = e.target.files[0]; if (!file) return;
    try {
      const blob = await resize(file);
      const base = translit(form.elements.title.value || file.name.replace(/\.[^.]+$/, ''));
      const name = `images/${base}.jpg`;
      localPhotos[name] = { url: URL.createObjectURL(blob), blob };
      setPhoto(name);
      $('#photoHint').textContent = `Нажмите «Скачать уменьшенное» — получите файл ${base}.jpg. Именно его загрузите в папку фото на GitHub.`;
    } catch (err) { $('#formErrors').textContent = err.message; }
    e.target.value = '';
  });
  $('#photoSmall').addEventListener('click', () => {
    const name = form.elements.photo.value; const lp = localPhotos[name]; if (!lp) return;
    const a = document.createElement('a'); a.href = lp.url; a.download = name.split('/').pop(); document.body.appendChild(a); a.click(); a.remove();
  });
  $('#photoRemove').addEventListener('click', () => setPhoto(''));
  form.elements.photo.addEventListener('change', () => setPhoto(form.elements.photo.value.trim()));

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const f = form.elements;
    const errors = [];
    const id = f.id.value.trim().toUpperCase();
    if (!/^[A-Z0-9][A-Z0-9-]{1,23}$/.test(id)) errors.push('Артикул: латиница, цифры и дефис, 2–24 символа');
    if (products.some((p, i) => p.id === id && i !== editingIndex)) errors.push('Такой артикул уже есть');
    const title = f.title.value.trim();
    if (title.length < 2) errors.push('Укажите название');
    const photo = f.photo.value.trim();
    if (photo && !/^images\/[a-z0-9._-]+\.(jpg|jpeg|png|webp)$/i.test(photo)) errors.push('Фото: путь вида images/имя-латиницей.jpg');
    if (errors.length) { $('#formErrors').textContent = errors.join('\n'); return; }
    const specs = {};
    for (const line of f.specs.value.split('\n')) {
      const i = line.indexOf(':'); if (i < 1) continue;
      const k = line.slice(0, i).trim(), v = line.slice(i + 1).trim(); if (k && v) specs[k] = v;
    }
    const finishes = [...form.querySelectorAll('[name=finishes]:checked')].map((c) => c.value);
    const fin = finishes.length ? finishes : FINISH_KEYS;
    const product = {
      id, title, use: f.use.value.trim(), desc: f.desc.value.trim(),
      price: f.price.value === '' ? null : Math.max(0, Math.round(+f.price.value)),
      unit: f.unit.value.trim() || 'шт.', moq: Math.max(1, Math.round(+f.moq.value || 1)),
      tags: [...form.querySelectorAll('[name=tags]:checked')].map((c) => c.value),
      draw: f.draw.value, photo, specs, finishes: fin, finish: fin.includes(f.finish.value) ? f.finish.value : fin[0],
    };
    if (f.hidden.checked) product.hidden = true;
    if (editingIndex >= 0) products[editingIndex] = product; else products.push(product);
    editor.close(); changed();
  });

  $('#deleteBtn').addEventListener('click', () => {
    const btn = $('#deleteBtn');
    if (btn.dataset.confirm !== '1') { btn.dataset.confirm = '1'; btn.textContent = 'Точно удалить? Нажмите ещё раз'; return; }
    products.splice(editingIndex, 1); editor.close(); changed();
  });
  editor.addEventListener('close', () => { const b = $('#deleteBtn'); b.dataset.confirm = ''; b.textContent = 'Удалить товар'; });
  $('#cancelBtn').addEventListener('click', () => editor.close());
  $('#newBtn').addEventListener('click', () => openEditor(-1));
  $('#list').addEventListener('click', (e) => {
    const b = e.target.closest('[data-act]'); if (!b) return;
    const i = +b.dataset.i;
    if (b.dataset.act === 'edit') return openEditor(i);
    const j = b.dataset.act === 'up' ? i - 1 : i + 1;
    if (j < 0 || j >= products.length) return;
    [products[i], products[j]] = [products[j], products[i]]; changed();
  });

  $('#copyBtn').addEventListener('click', async () => {
    try { await navigator.clipboard.writeText(output()); setStatus('Каталог скопирован. Теперь откройте файл каталога на GitHub и вставьте.'); }
    catch { setStatus('Не получилось скопировать — нажмите «Скачать products.json» и загрузите файл на GitHub.', true); }
  });
  $('#downloadBtn').addEventListener('click', () => {
    const url = URL.createObjectURL(new Blob([output()], { type: 'application/json' }));
    const a = document.createElement('a'); a.href = url; a.download = 'products.json'; document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  });
  $('#resetBtn').addEventListener('click', () => { products = JSON.parse(original); store.clear(); render(); setStatus('Изменения отменены — показан каталог с сайта.'); });

  (async () => {
    try {
      const r = await fetch('products.json', { cache: 'no-cache' });
      const list = r.ok ? await r.json() : [];
      products = Array.isArray(list) ? list : [];
    } catch { products = []; }
    original = output();
    const draft = store.get();
    if (Array.isArray(draft) && JSON.stringify(draft, null, 2) + '\n' !== original) {
      products = draft; setStatus('Восстановлены ваши несохранённые изменения. Сохраните их на GitHub (шаг 3) или отмените.');
    }
    render();
  })();
})();
