// Yerel altyazı sunucusu: TV uygulamasına Server-Sent Events ile altyazı gönderir.
// Kullanım: node server.mjs [--port 8787] [--demo]
// Terminale yazılan her satır da altyazı olarak gönderilir.

import http from 'node:http';
import os from 'node:os';
import readline from 'node:readline';

const args = process.argv.slice(2);
const PORT = Number(valueOf('--port') ?? 8787);

const DEMO_LINES = [
  'Bu bir test altyazısıdır.',
  'Altyazı oyun görüntüsünün üstünde görünüyorsa katman çalışıyor.',
  'Kuzey kapısını tut, takviye geliyor!',
  'Bu kılıcı nereden buldun? Babamın kılıcına benziyor.',
  'Bir sonraki adım: ses tanıma ve çeviri.',
];

const clients = new Set();
let demoTimer = null;
let demoIndex = 0;

function valueOf(flag) {
  const i = args.indexOf(flag);
  return i >= 0 ? args[i + 1] : undefined;
}

function broadcast(event, data) {
  const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
  for (const res of clients) res.write(payload);
}

function say(text, duration, original) {
  text = String(text ?? '').trim();
  if (!text) return;
  broadcast('subtitle', { text, duration: Number(duration) || null, at: Date.now() });
  if (original) console.log(`  ${original}`);
  console.log(`→ [${clients.size} TV] ${text}`);
}

function setDemo(on) {
  clearInterval(demoTimer);
  demoTimer = null;
  if (!on) return;
  const next = () => say(DEMO_LINES[demoIndex++ % DEMO_LINES.length], 3500);
  next();
  demoTimer = setInterval(next, 4500);
}

function readJson(req) {
  return new Promise((resolve) => {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      try { resolve(JSON.parse(body || '{}')); } catch { resolve({}); }
    });
  });
}

function lanAddresses() {
  return Object.values(os.networkInterfaces())
    .flat()
    .filter((a) => a && a.family === 'IPv4' && !a.internal)
    .map((a) => a.address);
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x');
  // TV uygulaması file:// kökeninden bağlandığı için CORS açık.
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.end();

  if (url.pathname === '/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    });
    res.write('retry: 2000\n\n');
    clients.add(res);
    broadcast('status', { clients: clients.size });
    console.log(`+ TV bağlandı (${req.socket.remoteAddress}), toplam ${clients.size}`);
    req.on('close', () => {
      clients.delete(res);
      broadcast('status', { clients: clients.size });
      console.log(`- TV ayrıldı, toplam ${clients.size}`);
    });
    return;
  }

  if (url.pathname === '/say' && req.method === 'POST') {
    const { text, duration, original } = await readJson(req);
    say(text, duration, original);
    return json(res, { ok: true, clients: clients.size });
  }

  // Oyundaki altyazı ekrandan kalkınca okuyucu bunu çağırır.
  if (url.pathname === '/clear' && req.method === 'POST') {
    broadcast('clear', {});
    return json(res, { ok: true });
  }

  if (url.pathname === '/demo' && req.method === 'POST') {
    const { on } = await readJson(req);
    setDemo(Boolean(on));
    return json(res, { ok: true, demo: Boolean(demoTimer) });
  }

  if (url.pathname === '/state') {
    return json(res, { clients: clients.size, demo: Boolean(demoTimer) });
  }

  if (url.pathname === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    return res.end(CONTROL_PAGE);
  }

  res.writeHead(404);
  res.end('Bulunamadı');
});

function json(res, data) {
  res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(data));
}

// Bağlantıyı canlı tutmak için düzenli boş yorum satırı.
setInterval(() => { for (const res of clients) res.write(': ping\n\n'); }, 15000);

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Altyazı sunucusu çalışıyor (port ${PORT}).`);
  for (const ip of lanAddresses()) console.log(`  Kontrol sayfası: http://${ip}:${PORT}/`);
  console.log('Terminale bir satır yazıp Enter\'a basarsan TV\'ye altyazı olarak gider.');
  if (args.includes('--demo')) setDemo(true);
});

readline.createInterface({ input: process.stdin }).on('line', (line) => say(line));

const CONTROL_PAGE = `<!doctype html>
<html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Altyazı Kontrol</title>
<style>
  :root { color-scheme: light dark; --bg:#f6f6f4; --fg:#1b1b1b; --muted:#6b6b6b; --card:#fff; --line:#ddd; --accent:#1f6feb; }
  @media (prefers-color-scheme: dark) { :root { --bg:#141414; --fg:#eee; --muted:#9a9a9a; --card:#1e1e1e; --line:#333; --accent:#4c8dff; } }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--fg); font:16px/1.5 system-ui, sans-serif; }
  main { max-width:560px; margin:0 auto; padding:24px 16px; }
  h1 { font-size:20px; margin:0 0 4px; }
  p.muted { color:var(--muted); margin:0 0 20px; }
  .card { background:var(--card); border:1px solid var(--line); border-radius:12px; padding:16px; margin-bottom:16px; }
  textarea { width:100%; min-height:90px; font:inherit; padding:10px; border-radius:8px; border:1px solid var(--line); background:transparent; color:inherit; resize:vertical; }
  .row { display:flex; gap:8px; align-items:center; margin-top:10px; flex-wrap:wrap; }
  button { font:inherit; padding:8px 14px; border-radius:8px; border:1px solid var(--line); background:transparent; color:inherit; cursor:pointer; }
  button.primary { background:var(--accent); border-color:var(--accent); color:#fff; }
  label { color:var(--muted); font-size:14px; }
  input[type=number] { width:70px; font:inherit; padding:6px; border-radius:8px; border:1px solid var(--line); background:transparent; color:inherit; }
  #state { font-weight:600; }
</style></head>
<body><main>
  <h1>PS5 Altyazı — Kontrol</h1>
  <p class="muted">Bağlı TV: <span id="state">…</span></p>
  <div class="card">
    <textarea id="text" placeholder="TV'de görünecek altyazı (Ctrl/Cmd+Enter gönderir)"></textarea>
    <div class="row">
      <button class="primary" id="send">Gönder</button>
      <label>Süre (sn) <input type="number" id="dur" value="4" min="1" max="20"></label>
    </div>
  </div>
  <div class="card">
    <div class="row" style="margin:0">
      <button id="demo">Demo akışını başlat</button>
      <span class="muted" style="color:var(--muted)">Örnek cümleleri 4,5 sn arayla gönderir.</span>
    </div>
  </div>
</main>
<script>
  const $ = (id) => document.getElementById(id);
  let demo = false;
  async function post(path, body) {
    const r = await fetch(path, { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(body) });
    return r.json();
  }
  async function refresh() {
    const s = await (await fetch('/state')).json();
    $('state').textContent = s.clients;
    demo = s.demo;
    $('demo').textContent = demo ? 'Demo akışını durdur' : 'Demo akışını başlat';
  }
  $('send').onclick = async () => {
    await post('/say', { text: $('text').value, duration: Number($('dur').value) * 1000 });
    $('text').select();
  };
  $('text').addEventListener('keydown', (e) => { if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) $('send').click(); });
  $('demo').onclick = async () => { await post('/demo', { on: !demo }); refresh(); };
  refresh(); setInterval(refresh, 2000);
</script>
</body></html>`;
