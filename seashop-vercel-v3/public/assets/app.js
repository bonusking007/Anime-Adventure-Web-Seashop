const byId = id => document.getElementById(id);
const format = new Intl.NumberFormat('th-TH');
const count = value => value == null ? '—' : format.format(value);
const displayName = player => player.displayName || player.username;
const active = player => Date.now() - Date.parse(player.updatedAt) < 60_000;
const onlineLabel = player => active(player) ? 'กำลังส่งข้อมูล' : 'ออฟไลน์';
const timestamp = value => new Date(value).toLocaleString('th-TH', {timeZone:'Asia/Bangkok'});
let players = [];
let viewKey = '';
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
    const names = [displayName(player), player.username, player.userId, ...(player.round?.items ?? []).map(item => item.name)];
    return (!onlineOnly || active(player)) && names.some(name => String(name).toLowerCase().includes(term));
  });
  byId('account-count').textContent = count(players.length);
  byId('online-count').textContent = count(players.filter(active).length);
  for (const field of ['gems', 'gold']) {
    const values = players.map(player => player[field]).filter(Number.isFinite);
    byId('total-' + field).textContent = count(values.length ? values.reduce((total,value) => total + value, 0) : null);
  }
  byId('visible-count').textContent = count(filtered.length);
  byId('recent').textContent = players.length ?
    displayName(players[0]) + ' · ' + timestamp(players[0].updatedAt) : 'ยังไม่มีข้อมูล';
  const focusedId = document.activeElement?.dataset?.userId;
  const cards = filtered.map(player => {
    const card = element('button', '', 'aa-account');
    card.type = 'button';
    card.dataset.userId = player.userId;
    card.append(
      element('span', Array.from(displayName(player))[0] || '?', 'aa-initial'),
      element('strong', displayName(player)),
      element('span', '@' + player.username + ' · ' + onlineLabel(player), 'mut'),
      element('span', 'เพชร ' + count(player.gems) + ' · เวฟ ' + count(player.wave), 'aa-stats'),
    );
    card.addEventListener('click', () => {
      openedId = player.userId;
      renderDetail();
      byId('name').focus();
    });
    return card;
  });
  byId('cards').replaceChildren(...cards);
  if (focusedId) cards.find(card => card.dataset.userId === focusedId)?.focus();
  byId('empty').hidden = filtered.length > 0;
  byId('empty').textContent = players.length ? 'ไม่พบบัญชีที่ตรงกับตัวกรอง' : 'ยังไม่มีบัญชีส่งข้อมูลจาก Tracker';
  renderDetail();
}

function renderDetail() {
  const player = players.find(entry => entry.userId === openedId);
  byId('overview').hidden = Boolean(player);
  byId('detail').hidden = !player;
  if (!player) return;
  byId('name').textContent = displayName(player);
  byId('bigav').textContent = Array.from(displayName(player))[0] || '?';
  byId('player-online').textContent = onlineLabel(player);
  byId('updated').textContent = '@' + player.username + ' · ' + timestamp(player.updatedAt);
  for (const field of ['gems', 'gold', 'wave']) byId(field).textContent = count(player[field]);
  const round = player.round;
  byId('stage').textContent = round?.stage || (round ? 'รอบล่าสุด' : 'ยังไม่มีผลจบรอบ');
  const rewards = [
    {name:'เพชร', amount:round?.gems},
    {name:'ทอง', amount:round?.gold},
    ...(round?.items ?? []),
  ].filter(item => item.amount != null);
  byId('rewards').replaceChildren(...rewards.map(reward => {
    const row = element('li', '');
    row.append(element('span', reward.name), element('b', '×' + count(reward.amount)));
    return row;
  }));
  byId('no-items').hidden = rewards.length > 0;
}

async function sync() {
  if (!viewKey || pending || byId('dashboard').hidden) return;
  const controller = new AbortController();
  pending = controller;
  try {
    const res = await fetch('/api/player', {
      headers:{'X-API-Key':viewKey}, cache:'no-store', signal:controller.signal,
    });
    if (pending !== controller) return;
    if (res.status === 401) {
      viewKey = '';
      byId('profile').hidden = false;
      byId('feed').hidden = true;
      byId('health').dataset.state = 'error';
      byId('health').textContent = 'รหัสไม่ถูกต้อง';
      byId('status').textContent = 'ตรวจสอบ TRACKER_VIEW_KEY แล้วลองใหม่';
      return;
    }
    if (!res.ok) throw new Error('API error');
    const data = await res.json();
    if (!Array.isArray(data.players)) throw new Error('Invalid response');
    if (pending !== controller) return;
    players = data.players;
    byId('profile').hidden = true;
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
byId('profile').addEventListener('submit', event => {
  event.preventDefault();
  pending?.abort();
  pending = undefined;
  viewKey = byId('key').value;
  byId('key').value = '';
  byId('status').textContent = 'กำลังโหลดรายชื่อบัญชี…';
  sync();
});
byId('nav-home').addEventListener('click', () => { location.hash = 'home'; });
for (const id of ['nav-dash', 'enter']) {
  byId(id).addEventListener('click', () => { location.hash = 'dashboard'; });
}
byId('back').addEventListener('click', () => {
  const previous = openedId;
  openedId = undefined;
  renderDetail();
  [...byId('cards').children].find(card => card.dataset.userId === previous)?.focus();
});
byId('search').addEventListener('input', render);
byId('online').addEventListener('change', render);
byId('refresh').addEventListener('click', sync);
byId('detail-refresh').addEventListener('click', sync);
window.addEventListener('hashchange', route);
setInterval(sync, 15_000);
route();
