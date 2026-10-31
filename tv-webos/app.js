// SPDX-License-Identifier: AGPL-3.0-only
// CouchSubs TV uygulaması (webOS).
// HDMI girişini tam ekran gösterir, üstüne CouchSubs uygulamasından gelen altyazıyı basar.
// Eski webOS tarayıcıları için ES5 ile yazıldı.
(function () {
  'use strict';

  var t = window.t;
  var config = window.COUCHSUBS_CONFIG || {};
  var KEY = { RED: 403, GREEN: 404 };

  var server = null;
  var eventSource = null;
  // Kumandayla seçilen port kayıtlıysa o kullanılır, yoksa PS5 otomatik aranır.
  var savedPort = Number(load('hdmi'));
  var hdmiPort = savedPort || 1;

  var hideTimer = null;
  var panelTimer = null;

  function $(id) { return document.getElementById(id); }

  function load(key) {
    try { return window.localStorage.getItem('couchsubs.' + key); } catch (e) { return null; }
  }

  function save(key, value) {
    try { window.localStorage.setItem('couchsubs.' + key, String(value)); } catch (e) {}
  }

  function setStatus(id, text, cls) {
    var el = $(id);
    el.textContent = text;
    el.className = cls || '';
  }

  // --- Başlatma parametreleri ---

  function parseParams(raw) {
    if (!raw) return {};
    if (typeof raw === 'object') return raw;
    try { return JSON.parse(raw) || {}; } catch (e) { return {}; }
  }

  function launchParams() {
    return parseParams(window.PalmSystem && window.PalmSystem.launchParams);
  }

  // Parametrelerdeki sunucu ve HDMI tercihini uygular; sunucu değiştiyse yeniden bağlanır.
  function applyParams(params) {
    if (params.hdmi >= 1 && params.hdmi <= 4) {
      hdmiPort = Number(params.hdmi);
      save('hdmi', hdmiPort);
      showHdmi(hdmiPort);
    }
    if (params.server && params.server !== server) {
      save('server', params.server);
      connect(params.server);
    }
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
    setStatus('st-video', t('loading'), 'muted');
    video.addEventListener('loadeddata', function () { setStatus('st-video', t('videoReady'), 'ok'); });
    video.addEventListener('playing', function () { setStatus('st-video', t('playing'), 'ok'); });
    video.addEventListener('error', function () { setStatus('st-video', t('inputError'), 'bad'); });
    source.addEventListener('error', function () { setStatus('st-video', t('sourceError'), 'bad'); });

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

  function autoSelectConsole(onNotFound) {
    findConsolePort(function (port, label) {
      if (!port) return onNotFound && onNotFound();
      if (port !== hdmiPort) {
        hdmiPort = port;
        showHdmi(port);
      }
      setStatus('st-hdmi', port + ' — ' + label + ' (' + t('auto') + ')');
    });
  }

  // --- Altyazı ---

  function showSubtitle(text, duration) {
    $('subtitle-text').textContent = text;
    $('subtitle').className = '';
    clearTimeout(hideTimer);
    var ms = duration || Math.min(8000, 2000 + text.length * 60);
    hideTimer = setTimeout(hideSubtitle, ms);
  }

  function hideSubtitle() {
    clearTimeout(hideTimer);
    $('subtitle').className = 'hidden';
  }

  function applyStyle(style) {
    if (style.fontSize) $('subtitle-text').style.fontSize = style.fontSize + 'px';
    if (style.bottomPercent >= 0) $('subtitle').style.bottom = style.bottomPercent + '%';
  }

  // --- Sunucu bağlantısı (Server-Sent Events) ---

  function onEvent(name, handler) {
    eventSource.addEventListener(name, function (e) {
      var data;
      try { data = JSON.parse(e.data); } catch (err) { return; }
      handler(data);
    });
  }

  function connect(address) {
    if (eventSource) eventSource.close();
    server = address;
    $('waiting').className = 'hidden';
    setStatus('st-server', address);
    if (!window.EventSource) {
      setStatus('st-conn', t('noEventSource'), 'bad');
      return;
    }
    setStatus('st-conn', t('connecting'), 'muted');
    eventSource = new EventSource(address + '/events');
    eventSource.onopen = function () { setStatus('st-conn', t('connected'), 'ok'); };
    eventSource.onerror = function () { setStatus('st-conn', t('reconnecting'), 'bad'); };
    onEvent('subtitle', function (data) { if (data.text) showSubtitle(data.text, data.duration); });
    onEvent('clear', hideSubtitle);
    onEvent('style', applyStyle);
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
      autoSelectConsole(function () {
        setStatus('st-hdmi', hdmiPort + ' (' + t('consoleNotFound') + ')', 'bad');
      });
      showPanel(true);
    } else if (code >= 49 && code <= 52) { // 1–4
      hdmiPort = code - 48;
      save('hdmi', hdmiPort);
      showHdmi(hdmiPort);
      showPanel(true);
    } else if (code === KEY.RED) {
      showSubtitle(t('localTest'), 4000);
    } else if (code === KEY.GREEN) {
      togglePanel();
    }
  });

  // Uygulama zaten açıkken yeniden başlatılırsa (ör. CouchSubs onu öne getirdiğinde) parametreler burada gelir.
  document.addEventListener('webOSRelaunch', function (e) {
    applyParams(parseParams(e.detail));
  });

  window.applyI18n();
  showHdmi(hdmiPort);
  if (!savedPort) autoSelectConsole();

  var initial = launchParams();
  var address = initial.server || load('server') || config.server;
  applyParams(initial);
  if (!server) {
    if (address) connect(address); else $('waiting').className = '';
  }
  showPanel(true);
})();
