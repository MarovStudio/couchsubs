// SPDX-License-Identifier: AGPL-3.0-only
// TV uygulamasının metinleri. Dil TV'nin diline göre seçilir; Türkçe değilse İngilizce.
(function () {
  'use strict';

  var TEXTS = {
    tr: {
      waiting: 'Bilgisayarınızda veya telefonunuzda CouchSubs uygulamasını açın.',
      waitingHint: 'Uygulama bu TV\'yi bulup altyazıları buraya gönderecek.',
      panelTitle: 'CouchSubs',
      hdmi: 'HDMI',
      server: 'Uygulama',
      connection: 'Bağlantı',
      loading: '(yükleniyor)',
      videoReady: '(görüntü geldi)',
      playing: '(oynatılıyor)',
      inputError: '(hata: giriş açılamadı)',
      sourceError: '(hata: kaynak desteklenmiyor)',
      auto: 'otomatik',
      consoleNotFound: 'konsol bulunamadı',
      noEventSource: 'Bu TV desteklenmiyor (EventSource yok)',
      connecting: 'bağlanıyor…',
      connected: 'bağlı',
      reconnecting: 'bağlantı yok, yeniden deneniyor…',
      none: '—',
      keys: '1–4: HDMI girişi · 0: konsolu otomatik bul · Kırmızı: test altyazısı · Yeşil: bu panel',
      localTest: 'Test: bu yazı oyunun üstünde görünüyor mu?'
    },
    en: {
      waiting: 'Open the CouchSubs app on your computer or phone.',
      waitingHint: 'The app will find this TV and send subtitles here.',
      panelTitle: 'CouchSubs',
      hdmi: 'HDMI',
      server: 'App',
      connection: 'Connection',
      loading: '(loading)',
      videoReady: '(picture received)',
      playing: '(playing)',
      inputError: '(error: input could not be opened)',
      sourceError: '(error: source not supported)',
      auto: 'automatic',
      consoleNotFound: 'console not found',
      noEventSource: 'This TV is not supported (no EventSource)',
      connecting: 'connecting…',
      connected: 'connected',
      reconnecting: 'disconnected, retrying…',
      none: '—',
      keys: '1–4: HDMI input · 0: find console automatically · Red: test subtitle · Green: this panel',
      localTest: 'Test: is this text shown on top of the game?'
    }
  };

  var lang = (navigator.language || 'en').toLowerCase().indexOf('tr') === 0 ? 'tr' : 'en';

  window.t = function (key) {
    return (TEXTS[lang] && TEXTS[lang][key]) || TEXTS.en[key] || key;
  };

  // data-i18n niteliği taşıyan öğelerin metnini doldurur.
  window.applyI18n = function () {
    var nodes = document.querySelectorAll('[data-i18n]');
    for (var i = 0; i < nodes.length; i++) {
      nodes[i].textContent = window.t(nodes[i].getAttribute('data-i18n'));
    }
  };
})();
