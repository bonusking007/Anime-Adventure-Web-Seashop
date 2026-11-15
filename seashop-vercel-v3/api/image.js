export default {
 async fetch(request) {
  const q = new URL(request.url).searchParams;
  const id = q.get('id'), kind = q.get('kind');
  if (!/^[1-9]\d{0,15}$/.test(id || '') || !['avatar','asset'].includes(kind)) return new Response(null,{status:400});
  const path = kind === 'avatar' ? 'users/avatar-headshot?userIds=' : 'assets?assetIds=';
  try {
   const r = await fetch('https://thumbnails.roblox.com/v1/' + path + id + '&size=150x150&format=Png&isCircular=false',{signal:AbortSignal.timeout(6000)});
   if (!r.ok) throw Error();
   const data = await r.json();
   const entry = data.data?.find(x=>String(x.targetId)===id && x.state==='Completed');
   const url = new URL(entry?.imageUrl);
   if (url.protocol !== 'https:' || !url.hostname.endsWith('.rbxcdn.com')) throw Error();
   return new Response(null,{status:302,headers:{Location:url.href,'Cache-Control':'public, max-age=3600'}});
  } catch { return new Response(null,{status:404,headers:{'Cache-Control':'no-store'}}); }
 }
};
