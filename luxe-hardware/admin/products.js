(() => {
  'use strict';
  const $ = (s) => document.querySelector(s);
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const TAG_NAMES = { bags: 'Сумки', clutches: 'Клатчи', belts: 'Ремни', small: 'Мелкая галантерея' };
  const form = $('#pform'), editor = $('#editor');
  let products = [], editingId = null;

  async function api(url, opts = {}) {
    const r = await fetch(url, { headers: { 'Content-Type': 'application/json' }, cache: 'no-store', ...opts });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) throw Object.assign(new Error(j.error || (j.errors || []).join('\n') || 'Ошибка ' + r.status), { data: j });
    return j;
  }

  async function load() {
    products = await api('/admin/api/products');
    const visible = products.filter((p) => !p.hidden).length;
    $('#listTitle').textContent = products.length
      ? `Каталог: ${products.length} шт.${visible !== products.length ? ` (на сайте ${visible})` : ''}` : 'Каталог';
    $('#empty').hidden = products.length > 0;
    $('#list').innerHTML = products.map((p) => `
      <div class="pitem${p.hidden ? ' is-hidden' : ''}">
        <div class="pitem__thumb">${p.photo ? `<img src="${esc(p.photo)}" alt="">` : (p.draw ? 'иллюстр.' : 'нет фото')}</div>
        <div>
          <div class="pitem__title">${esc(p.id)} · ${esc(p.title)}</div>
          <div class="pitem__meta">${p.price == null ? 'цена по запросу' : p.price.toLocaleString('ru-RU') + ' ₽ / ' + esc(p.unit)} · ${p.tags.map((t) => TAG_NAMES[t]).join(', ') || 'без категории'}${p.hidden ? ' · скрыт' : ''}</div>
        </div>
        <div class="pitem__actions"><button class="btn" data-edit="${esc(p.id)}">Изменить</button></div>
      </div>`).join('');
  }

  function setPhoto(url) {
    form.elements.photo.value = url || '';
    $('#photoPreview').hidden = !url; if (url) $('#photoPreview').src = url;
    $('#photoEmpty').hidden = !!url; $('#photoRemove').hidden = !url;
  }

  function openEditor(p) {
    editingId = p ? p.id : null;
    form.reset();
    $('#formTitle').textContent = p ? 'Изменить ' + p.id : 'Новый товар';
    $('#deleteBtn').hidden = !p;
    $('#formErrors').textContent = '';
    if (p) {
      for (const k of ['id', 'title', 'use', 'desc', 'unit', 'moq', 'draw', 'finish']) form.elements[k].value = p[k] ?? '';
      form.elements.price.value = p.price ?? '';
      form.elements.specs.value = Object.entries(p.specs || {}).map(([k, v]) => `${k}: ${v}`).join('\n');
      form.querySelectorAll('[name=tags]').forEach((c) => { c.checked = p.tags.includes(c.value); });
      form.querySelectorAll('[name=finishes]').forEach((c) => { c.checked = p.finishes.includes(c.value); });
      form.elements.hidden.checked = !!p.hidden;
    }
    setPhoto(p?.photo);
    editor.showModal();
    form.elements[p ? 'title' : 'id'].focus();
  }

  // Фото уменьшаем в браузере до 1600 px — сайт грузится быстрее, сервер не забивается
  function resizeImage(file) {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => {
        const max = 1600, k = Math.min(1, max / Math.max(img.width, img.height));
        const c = document.createElement('canvas'); c.width = Math.round(img.width * k); c.height = Math.round(img.height * k);
        const ctx = c.getContext('2d'); ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, c.width, c.height);
        ctx.drawImage(img, 0, 0, c.width, c.height);
        URL.revokeObjectURL(img.src);
        resolve(c.toDataURL('image/jpeg', 0.86));
      };
      img.onerror = () => reject(new Error('Не удалось прочитать изображение'));
      img.src = URL.createObjectURL(file);
    });
  }
  $('#photoInput').addEventListener('change', async (e) => {
    const file = e.target.files[0]; if (!file) return;
    $('#photoEmpty').textContent = 'Загружаем…';
    try {
      const data = await resizeImage(file);
      const j = await api('/admin/api/upload', { method: 'POST', body: JSON.stringify({ data }) });
      setPhoto(j.url);
    } catch (err) { $('#formErrors').textContent = err.message; setPhoto(form.elements.photo.value); }
    $('#photoEmpty').textContent = 'Фото не выбрано — будет показана иллюстрация';
    e.target.value = '';
  });
  $('#photoRemove').addEventListener('click', () => setPhoto(''));

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const f = form.elements;
    const body = {
      prevId: editingId, id: f.id.value.trim(), title: f.title.value.trim(), use: f.use.value.trim(), desc: f.desc.value.trim(),
      price: f.price.value, unit: f.unit.value.trim(), moq: f.moq.value, specs: f.specs.value, draw: f.draw.value, photo: f.photo.value,
      tags: [...form.querySelectorAll('[name=tags]:checked')].map((c) => c.value),
      finishes: [...form.querySelectorAll('[name=finishes]:checked')].map((c) => c.value),
      finish: f.finish.value, hidden: f.hidden.checked,
    };
    $('#saveBtn').disabled = true;
    try { await api('/admin/api/products', { method: 'POST', body: JSON.stringify(body) }); editor.close(); await load(); }
    catch (err) { $('#formErrors').textContent = err.message; }
    finally { $('#saveBtn').disabled = false; }
  });

  $('#deleteBtn').addEventListener('click', async () => {
    if (!editingId || !confirm(`Удалить ${editingId} с сайта? Это нельзя отменить.`)) return;
    try { await api('/admin/api/products/' + encodeURIComponent(editingId), { method: 'DELETE' }); editor.close(); await load(); }
    catch (err) { $('#formErrors').textContent = err.message; }
  });
  $('#demoBtn').addEventListener('click', async () => { await api('/admin/api/products/import-demo', { method: 'POST', body: '{}' }); await load(); });
  $('#cancelBtn').addEventListener('click', () => editor.close());
  $('#newBtn').addEventListener('click', () => openEditor(null));
  $('#newBtn2').addEventListener('click', () => openEditor(null));
  $('#list').addEventListener('click', (e) => {
    const b = e.target.closest('[data-edit]'); if (b) openEditor(products.find((p) => p.id === b.dataset.edit));
  });
  load().catch((err) => { $('#listTitle').textContent = err.message; });
})();
