// PS5 Altyazı test uygulaması (webOS).
// HDMI girişini tam ekran gösterir, üstüne yerel sunucudan gelen altyazıyı basar.
// Eski webOS tarayıcıları için ES5 ile yazıldı.
(function () {
  'use strict';

  var config = window.ALTYAZI_CONFIG || {};
  var SERVER = config.server || 'http://192.168.1.2:8787';
  var KEY = { RED: 403, GREEN: 404, YELLOW: 405 };
  var SIZES = ['size-s', '', 'size-l'];

  // Kumandayla seçilen port kayıtlıysa o kullanılır, yoksa PS5 otomatik aranır.
  var savedPort = Number(load('hdmi'));
  var hdmiPort = savedPort || config.hdmi || 1;
  var sizeIndex = Number(load('size'));
  if (isNaN(sizeIndex) || sizeIndex < 0 || sizeIndex > 2) sizeIndex = 1;

  var hideTimer = null;
  var panelTimer = null;

  function $(id) { return document.getElementById(id); }

  function load(key) {
    try { return window.localStorage.getItem('altyazi.' + key); } catch (e) { return null; }
  }

  function save(key, value) {
    try { window.localStorage.setItem('altyazi.' + key, String(value)); } catch (e) {}
  }

  function setStatus(id, text, cls) {
    var el = $(id);
    el.textContent = text;
    el.className = cls || '';
  }

  // --- HDMI görüntüsü ---

  function showHdmi(port) {
    var host = $('video-host');
    host.innerHTML = '';

    var video = document.createElement('video');
    video.autoplay = true;
    var source = document.createElement('source');
    source.setAttribute('type', 'service/webos-external');
    source.setAttribute('src', 'ext://hdmi:' + port);
    video.appendChild(source);

    setStatus('st-hdmi', String(port));
    setStatus('st-video', '(yükleniyor)', 'muted');
    video.addEventListener('loadeddata', function () { setStatus('st-video', '(görüntü geldi)', 'ok'); });
    video.addEventListener('playing', function () { setStatus('st-video', '(oynatılıyor)', 'ok'); });
    video.addEventListener('error', function () { setStatus('st-video', '(hata: giriş açılamadı)', 'bad'); });
    source.addEventListener('error', function () { setStatus('st-video', '(hata: kaynak desteklenmiyor)', 'bad'); });

    host.appendChild(video);
  }

  // TV'nin giriş listesinden oyun konsolunun bağlı olduğu HDMI portunu bulur.
  // Bulamazsa callback'i null ile çağırır.
  function findConsolePort(callback) {
    var done = false;
    function finish(port, label) {
      if (done) return;
      done = true;
      callback(port, label);
    }
    try {
      var bridge = new PalmServiceBridge();
      bridge.onservicecallback = function (msg) {
        var devices;
        try { devices = JSON.parse(msg).devices || []; } catch (e) { return finish(null); }
        var hdmi = devices.filter(function (d) { return /^HDMI_/.test(d.id); });
        var pick = hdmi.filter(function (d) {
          return d.activate && (d.spdSourceDeviceInfo === 'GAME' || /playstation|ps5/i.test((d.label || '') + ' ' + (d.spdProductDescription || '')));
        })[0] || hdmi.filter(function (d) { return d.activate; })[0];
        finish(pick ? pick.port : null, pick ? pick.label : null);
      };
      bridge.call('luna://com.webos.service.eim/getAllInputStatus', '{}');
      // Köprü nesnesi çöpe gitmesin diye geri çağrı gelene kadar tutulur.
      window.__eimBridge = bridge;
      setTimeout(function () { finish(null); }, 3000);
    } catch (e) {
      finish(null);
    }
  }

  // --- Altyazı ---

  function showSubtitle(text, duration) {
    $('subtitle-text').textContent = text;
    $('subtitle').className = '';
    clearTimeout(hideTimer);
    var ms = duration || Math.min(8000, 2000 + text.length * 60);
    hideTimer = setTimeout(function () { $('subtitle').className = 'hidden'; }, ms);
  }

  function applySize() {
    document.body.className = SIZES[sizeIndex];
  }

  // --- Sunucu bağlantısı (Server-Sent Events) ---

  function connect() {
    setStatus('st-server', SERVER);
    if (!window.EventSource) {
      setStatus('st-conn', 'Bu TV EventSource desteklemiyor', 'bad');
      return;
    }
    setStatus('st-conn', 'bağlanıyor…', 'muted');
    var es = new EventSource(SERVER + '/events');
    es.onopen = function () { setStatus('st-conn', 'bağlı', 'ok'); };
    es.onerror = function () { setStatus('st-conn', 'bağlantı yok, yeniden deneniyor…', 'bad'); };
    es.addEventListener('subtitle', function (e) {
      try {
        var data = JSON.parse(e.data);
        if (data.text) showSubtitle(data.text, data.duration);
      } catch (err) {}
    });
    es.addEventListener('clear', function () {
      clearTimeout(hideTimer);
      $('subtitle').className = 'hidden';
    });
  }

  // --- Panel ve kumanda ---

  function showPanel(autoHide) {
    $('panel').className = '';
    clearTimeout(panelTimer);
    if (autoHide) panelTimer = setTimeout(hidePanel, 8000);
  }

  function hidePanel() { $('panel').className = 'hidden'; }

  function togglePanel() {
    if ($('panel').className === 'hidden') showPanel(false); else hidePanel();
  }

  document.addEventListener('keydown', function (e) {
    var code = e.keyCode;
    if (code === 48) { // 0: elle seçimi unut, konsolu yeniden ara
      save('hdmi', '');
      findConsolePort(function (port, label) {
        if (!port) return setStatus('st-hdmi', hdmiPort + ' (konsol bulunamadı)', 'bad');
        hdmiPort = port;
        showHdmi(port);
        setStatus('st-hdmi', port + ' — ' + label + ' (otomatik)');
      });
      showPanel(true);
    } else if (code >= 49 && code <= 52) { // 1–4
      hdmiPort = code - 48;
      save('hdmi', hdmiPort);
      showHdmi(hdmiPort);
      showPanel(true);
    } else if (code === KEY.RED) {
      showSubtitle('Yerel test: bu yazı oyunun üstünde görünüyor mu?', 4000);
    } else if (code === KEY.GREEN) {
      togglePanel();
    } else if (code === KEY.YELLOW) {
      sizeIndex = (sizeIndex + 1) % SIZES.length;
      save('size', sizeIndex);
      applySize();
      showSubtitle('Yazı boyutu örneği', 2500);
    }
  });

  applySize();
  showHdmi(hdmiPort);
  if (!savedPort) {
    findConsolePort(function (port, label) {
      if (!port) return;
      if (port !== hdmiPort) {
        hdmiPort = port;
        showHdmi(port);
      }
      setStatus('st-hdmi', port + ' — ' + label + ' (otomatik)');
    });
  }
  connect();
  showPanel(true);
})();
