import { timingSafeEqual } from 'node:crypto';
import { redisCommand } from '../lib/redis.js';

const response = (body, status = 200) => Response.json(body, {
  status,
  headers: { 'Cache-Control': 'no-store' },
});
const validId = value => /^[1-9]\d{0,15}$/.test(value);
const name = value => typeof value === 'string' ? value.slice(0, 80) : '';
const amount = value => Number.isSafeInteger(value) && value >= 0 ? value : null;

const mask = value => { const chars = Array.from(name(value)); return chars.length > 4 ? chars.slice(0,2).join('') + '***' + chars.slice(-2).join('') : (chars[0] || '') + '***'; };
const publicPlayer = player => ({...player, username:mask(player.username), displayName:mask(player.username)});
const imageId = value => typeof value === 'string' && /^[1-9]\d{0,15}$/.test(value) ? value : null;
const playerPrefix = 'seashop-aa:player:';
const decode = value => typeof value === 'string' ? JSON.parse(value) : value;

function cleanRewards(value) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 50).flatMap(item => {
    const label = name(item?.name).trim();
    const count = amount(item?.amount);
    return label && count !== null ? [{ name: label, amount: count, imageId:imageId(item.imageId) }] : [];
  });
}

async function listPlayers() {
  const keys = new Set();
  let cursor = '0';
  do {
    const [next, found] = await redisCommand(['SCAN', cursor, 'MATCH', playerPrefix + '*', 'COUNT', 200]);
    cursor = String(next);
    for (const key of found) {
      if (validId(key.slice(playerPrefix.length))) keys.add(key);
    }
  } while (cursor !== '0');

  const players = [];
  const orderedKeys = [...keys];
  for (let i = 0; i < orderedKeys.length; i += 100) {
    const batch = await redisCommand(['MGET', ...orderedKeys.slice(i, i + 100)]);
    for (const entry of batch) {
      if (entry != null) players.push(decode(entry));
    }
  }
  return players.sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
}

export default {
  async fetch(request) {
    const { method } = request;
    if (method !== 'GET' && method !== 'POST') {
      return new Response(null, { status: 405, headers: { Allow: 'GET, POST' } });
    }
    const setting = method === 'GET' ? 'TRACKER_VIEW_KEY' : 'TRACKER_API_KEY';
    const secret = process.env[setting];
    if (!secret) return response({ error: 'Tracker configuration missing' }, 503);
    const expected = Buffer.from(secret);
    const supplied = Buffer.from(request.headers.get('x-api-key') ?? '');
    if (supplied.length !== expected.length || !timingSafeEqual(expected, supplied)) {
      return response({ error: 'Invalid key' }, 401);
    }
    const id = new URL(request.url).searchParams.get('id');
    try {
      if (method === 'GET' && id === null) return response({ players: (await listPlayers()).map(publicPlayer) });
      if (!validId(id ?? '')) return response({ error: 'Invalid User ID' }, 400);
      const key = playerPrefix + id;
      if (method === 'GET') {
        const stored = await redisCommand(['GET', key]);
        if (!stored) return response({ error: 'Player has not sent data' }, 404);
        return response({ player: publicPlayer(decode(stored)) });
      }
      const body = await request.text();
      if (body.length > 12_000) return response({ error: 'Payload too large' }, 413);
      let data;
      try { data = JSON.parse(body); } catch { return response({ error: 'Invalid JSON' }, 400); }
      if (!name(data?.username) || String(data.userId) !== id) {
        return response({ error: 'Invalid player' }, 400);
      }
      const player = {
        userId: id,
        username: name(data.username),
        displayName: name(data.displayName),
        gems: amount(data.gems),
        gold: amount(data.gold),
        wave: amount(data.wave),
        description: name(data.description),
        tracking: data.tracking !== false,
        round: data.round && typeof data.round === 'object' ? {
          stage: name(data.round.stage),
          gems: amount(data.round.gems),
          gold: amount(data.round.gold),
          items: cleanRewards(data.round.items),
        } : null,
        updatedAt: new Date().toISOString(),
      };
      await redisCommand(['SET', key, JSON.stringify(player), 'EX', 604800]);
      return response({ ok: true });
    } catch {
      return response({ error: 'Tracker storage unavailable' }, 503);
    }
  },
};
