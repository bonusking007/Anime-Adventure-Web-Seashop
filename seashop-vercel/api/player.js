import { timingSafeEqual } from 'node:crypto';
import { redisCommand } from '../lib/redis.js';

const response = (body, status = 200) => Response.json(body, {
  status,
  headers: { 'Cache-Control': 'no-store' },
});
const validId = value => /^[1-9]\d{0,15}$/.test(value);
const name = value => typeof value === 'string' ? value.slice(0, 80) : '';
const amount = value => Number.isSafeInteger(value) && value >= 0 ? value : null;

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
    const id = new URL(request.url).searchParams.get('id') ?? '';
    if (!validId(id)) return response({ error: 'Invalid User ID' }, 400);
    const key = 'seashop-aa:player:' + id;
    try {
      if (method === 'GET') {
        const stored = await redisCommand(['GET', key]);
        if (!stored) return response({ error: 'Player has not sent data' }, 404);
        return response({ player: typeof stored === 'string' ? JSON.parse(stored) : stored });
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
        round: data.round && typeof data.round === 'object' ? {
          stage: name(data.round.stage),
          gems: amount(data.round.gems),
          gold: amount(data.round.gold),
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
