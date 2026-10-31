// TV'deki uygulamada uzaktan JavaScript çalıştırır (geliştirme aracı).
// Önce: ares-inspect -d tv -a com.ps5altyazi.test  (hata ayıklayıcıyı açar)
// Kullanım: node araclar/tv-eval.mjs "ifade" [TV_IP]

const expr = process.argv[2];
const host = process.argv[3] || process.env.TV_IP || '192.168.1.153';
if (!expr) {
  console.error('Kullanım: node araclar/tv-eval.mjs "ifade" [TV_IP]');
  process.exit(1);
}

const targets = await (await fetch(`http://${host}:9998/json`)).json();
const page = targets.find((t) => t.type === 'page');
if (!page) {
  console.error('Uygulama sayfası bulunamadı. ares-inspect çalışıyor mu?');
  process.exit(1);
}

const ws = new WebSocket(page.webSocketDebuggerUrl);
let answered = false;
ws.onopen = () => {
  ws.send(JSON.stringify({
    id: 1,
    method: 'Runtime.evaluate',
    params: { expression: expr, returnByValue: true, awaitPromise: true },
  }));
};
ws.onmessage = (msg) => {
  const data = JSON.parse(msg.data);
  if (data.id !== 1) return;
  answered = true;
  const r = data.result || {};
  if (r.exceptionDetails) console.error('Hata:', JSON.stringify(r.exceptionDetails));
  else console.log(JSON.stringify(r.result && r.result.value, null, 2));
  ws.close();
};
ws.onerror = (e) => {
  // TV kapanışta bağlantıyı sert kestiği için yanıt sonrası hatalar yok sayılır.
  if (answered) return;
  console.error('Bağlantı hatası:', e.message || e);
  process.exit(1);
};
