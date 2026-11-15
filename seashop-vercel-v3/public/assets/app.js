const byId = id => document.getElementById(id);
const format = new Intl.NumberFormat('th-TH');
const count = value => value == null ? '—' : format.format(value);
const displayName = player => {
 const value = player.username || player.displayName || '';
 if (value.includes('***')) return value;
 const chars = Array.from(value);
 return chars.length > 4 ? chars.slice(0,2).join('') + '***' + chars.slice(-2).join('') : (chars[0] || '') + '***';
};
function picture(id, kind, className) {
 const img = document.createElement('img');
 img.className = className;
 img.alt = kind === 'avatar' ? 'รูปโปรไฟล์ผู้เล่น' : 'รูปไอเทม';
 img.loading = 'lazy';
 img.src = '/api/image?kind=' + kind + '&id=' + encodeURIComponent(id);
 img.addEventListener('error', () => { img.src = '/assets/sea-shop-logo.png'; }, {once:true});
 return img;
}
const active = player => player.tracking !== false && Date.now() - Date.parse(player.updatedAt) < 60_000;
const onlineLabel = player => active(player) ? 'กำลังส่งข้อมูล' : 'ออฟไลน์';
const timestamp = value => new Date(value).toLocaleString('th-TH', {timeZone:'Asia/Bangkok'});
let players = [];
let openedId;
let pending;

function element(tag, value, className) {
  const node = document.createElement(tag);
  node.textContent = value;
  if (className) node.className = className;
  return node;
}

function render() {
  const term = byId('search').value.trim().toLowerCase();
  const onlineOnly = byId('online').checked;
  const filtered = players.filter(player => {
    const names = [displayName(player), player.username, player.userId, ...(player.round?.items ?? []).map(item => item.name), ...(player.inventory ?? []).map(item => item.name)];
    return (!onlineOnly || active(player)) && names.some(name => String(name).toLowerCase().includes(term));
  });
  byId('account-count').textContent = count(players.length);
  const focusedId = document.activeElement?.dataset?.userId;
  const cards = filtered.map(player => {
    const card = element('article', '', 'aa-account');
    card.dataset.userId = player.userId;
    card.append(
      picture(player.userId, 'avatar', 'aa-initial'),
      element('strong', displayName(player)),
      element('span', '@' + displayName(player), 'mut'),
      element('span', onlineLabel(player), 'card-badge'),
      element('span', player.description || 'ยังไม่ได้ตั้งสถานะ', 'custom-description'),
      element('span', 'เพชร ' + count(player.gems) + ' · เวฟ ' + count(player.wave), 'aa-stats'),
    );
    const button = element('button', 'ดูไอเทม  ↗', 'card-action');
    button.type = 'button';
    button.dataset.userId = player.userId;
    button.setAttribute('aria-label', 'ดูไอเทมของ ' + displayName(player));
    card.append(button);
    button.addEventListener('click', () => {
      openedId = player.userId;
      selectItemTab(true);
      renderDetail();
      byId('name').focus();
    });
    return card;
  });
  byId('cards').replaceChildren(...cards);
  if (focusedId) cards.find(card => card.dataset.userId === focusedId)?.querySelector('button')?.focus();
  byId('empty').hidden = filtered.length > 0;
  byId('empty').textContent = players.length ? 'ไม่พบบัญชีที่ตรงกับตัวกรอง' : 'ยังไม่มีบัญชีส่งข้อมูลจาก Tracker';
  renderDetail();
}

const imageKey = value => String(value ?? '').toLowerCase().replace(/[^\p{L}\p{N}]/gu, '');
function gameImage(group, value) {
  const path = globalThis.seashopGameImages?.[group]?.[imageKey(value)];
  return typeof path === 'string' ? '/assets/' + path : null;
}

function localPicture(path, className, alt = '') {
  const image = document.createElement('img');
  image.src = path;
  image.className = className;
  image.alt = alt;
  image.loading = 'lazy';
  image.addEventListener('error', () => { image.hidden = true; }, {once:true});
  return image;
}

function renderTeam(team) {
  const units = Array.isArray(team) ? team : [];
  byId('team-units').replaceChildren(...units.map(unit => {
    const card = element('li', '', 'team-unit');
    const portrait = element('div', '', 'team-portrait');
    const path = gameImage('units', unit.name);
    if (path) portrait.append(localPicture(path, 'team-portrait-image'));
    else portrait.append(element('span', unit.name.slice(0, 1), 'team-placeholder'));
    if (unit.level != null) portrait.append(element('span', 'Lv.' + count(unit.level), 'team-level'));
    const traitBadge = element('span', '', 'team-trait-badge');
    for (const trait of unit.traits ?? []) {
      const traitPath = gameImage('traits', trait);
      if (traitPath) {
        traitBadge.append(localPicture(traitPath, 'team-trait', trait));
        portrait.append(traitBadge);
        break;
      }
    }
    card.append(portrait, element('span', unit.name, 'team-name'));
    return card;
  }));
  const empty = byId('team-empty');
  empty.hidden = units.length > 0;
  empty.textContent = Array.isArray(team) ? 'ยังไม่มี Unit ในทีม' : 'รอ Tracker ส่งข้อมูลทีม';
}

function selectItemTab(bag) {
  byId('bag-panel').hidden = !bag;
  byId('rewards-panel').hidden = bag;
  for (const [id, active] of [['tab-bag', bag], ['tab-rewards', !bag]]) {
    byId(id).classList.toggle('on', active);
    byId(id).setAttribute('aria-pressed', String(active));
  }
}

function renderBag(player) {
  const items = Array.isArray(player.inventory) ? player.inventory : null;
  byId('bag-note').textContent = items
    ? (items.length + ' รายการ' + (player.inventoryUpdatedAt ? ' · ' + timestamp(player.inventoryUpdatedAt) : ''))
    : 'รอ Tracker รับข้อมูลกระเป๋าจากเกม';
  byId('bag-items').replaceChildren(...(items ?? []).map(item => {
    const card = element('li', '', 'bag-item');
    const path = gameImage('items', item.imageId) || gameImage('items', item.id) || gameImage('items', item.name);
    if (path) card.append(localPicture(path, 'bag-icon'));
    else if (item.imageId) card.append(picture(item.imageId, 'asset', 'bag-icon'));
    else card.append(element('span', '◇', 'bag-placeholder'));
    card.append(element('span', item.name, 'bag-name'), element('strong', '×' + count(item.amount), 'bag-count'));
    return card;
  }));
}

function renderDetail() {
  const player = players.find(entry => entry.userId === openedId);
  byId('overview').hidden = Boolean(player);
  byId('detail').hidden = !player;
  if (!player) return;
  byId('name').textContent = displayName(player);
  byId('bigav').replaceChildren(picture(player.userId, 'avatar', 'avatar-image'));
  byId('description').textContent = player.description || 'ยังไม่ได้ตั้งสถานะ';
  byId('player-online').textContent = onlineLabel(player);
  byId('updated').textContent = '@' + displayName(player) + ' · ' + timestamp(player.updatedAt);
  for (const field of ['gems', 'gold', 'wave']) byId(field).textContent = count(player[field]);
  renderTeam(player.team);
  renderBag(player);
  const round = player.round;
  byId('stage').textContent = round?.stage || (round ? 'รอบล่าสุด' : 'ยังไม่มีผลจบรอบ');
  const rewards = [
    {name:'เพชร', amount:round?.gems},
    {name:'ทอง', amount:round?.gold},
    ...(round?.items ?? []),
  ].filter(item => item.amount != null);
  byId('rewards').replaceChildren(...rewards.map(reward => {
    const row = element('tr', '');
    const label = element('td', '');
    const wrap = element('span', '', 'item-label');
    const localPath = gameImage('items', reward.imageId) || gameImage('items', reward.name);
    if (localPath) wrap.append(localPicture(localPath, 'item-icon'));
    else if (reward.imageId) wrap.append(picture(reward.imageId, 'asset', 'item-icon'));
    wrap.append(element('span', reward.name));
    label.append(wrap);
    row.append(label, element('td', '×' + count(reward.amount)));
    return row;
  }));
  byId('no-items').hidden = rewards.length > 0;
}

async function sync() {
  if (pending || byId('dashboard').hidden) return;
  const controller = new AbortController();
  pending = controller;
  try {
    const res = await fetch('/api/player', {
      cache:'no-store', signal:controller.signal,
    });
    if (pending !== controller) return;
    if (!res.ok) throw new Error('API error');
    const data = await res.json();
    if (!Array.isArray(data.players)) throw new Error('Invalid response');
    if (pending !== controller) return;
    players = data.players;
    byId('feed').hidden = false;
    byId('health').dataset.state = 'ready';
    byId('health').textContent = 'เชื่อมต่อแล้ว';
    byId('status').textContent = '';
    render();
  } catch {
    if (pending !== controller) return;
    byId('health').dataset.state = 'error';
    byId('health').textContent = 'API ERROR';
    byId('status').textContent = 'เชื่อมต่อ Tracker ไม่ได้ ระบบจะลองใหม่อัตโนมัติ';
  } finally {
    if (pending === controller) pending = undefined;
  }
}

function route() {
  const dashboard = location.hash === '#dashboard';
  byId('home').hidden = dashboard;
  byId('dashboard').hidden = !dashboard;
  byId('nav-home').classList.toggle('on', !dashboard);
  byId('nav-dash').classList.toggle('on', dashboard);
  if (dashboard) sync();
  else {
    pending?.abort();
    pending = undefined;
  }
}
byId('tab-bag').addEventListener('click', () => selectItemTab(true));
byId('tab-rewards').addEventListener('click', () => selectItemTab(false));
byId('nav-home').addEventListener('click', () => { location.hash = 'home'; });
for (const id of ['nav-dash', 'enter']) {
  byId(id).addEventListener('click', () => { location.hash = 'dashboard'; });
}
byId('back').addEventListener('click', () => {
  const previous = openedId;
  openedId = undefined;
  renderDetail();
  [...byId('cards').children].find(card => card.dataset.userId === previous)?.querySelector('button')?.focus();
});
byId('search').addEventListener('input', render);
byId('online').addEventListener('change', render);
byId('refresh').addEventListener('click', sync);
byId('detail-refresh').addEventListener('click', sync);
window.addEventListener('hashchange', route);
setInterval(sync, 15_000);
route();
