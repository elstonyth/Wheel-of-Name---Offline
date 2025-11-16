// Ensures the offline clone never attempts to fetch remote fonts, analytics or settings.
(function () {
  const LOCAL_FONTS = '/assets/fonts/googlefonts.css';
  const LOCAL_GTAG = '/offline/gtag-stub.js';
  const CLIENT_SETTINGS_PATH = '/api/v2/client-settings';
  const CLIENT_SETTINGS_BODY = JSON.stringify({ ads: { enabled: false }, features: {}, version: 1 });

  const originalSetAttribute = Element.prototype.setAttribute;
  Element.prototype.setAttribute = function (name, value) {
    if (name === 'href' && typeof value === 'string' && value.includes('fonts.googleapis.com')) {
      value = LOCAL_FONTS;
    } else if (name === 'src' && typeof value === 'string' && value.includes('www.googletagmanager.com/gtag/js')) {
      value = LOCAL_GTAG;
    }
    return originalSetAttribute.call(this, name, value);
  };

  const originalAppendChild = Element.prototype.appendChild;
  Element.prototype.appendChild = function (node) {
    try {
      if (node && node.tagName === 'LINK') {
        const href = node.getAttribute('href') || '';
        if (href.includes('fonts.googleapis.com')) {
          node.setAttribute('href', LOCAL_FONTS);
        }
      } else if (node && node.tagName === 'SCRIPT') {
        const src = node.getAttribute('src') || '';
        if (src.includes('www.googletagmanager.com/gtag/js')) {
          node.setAttribute('src', LOCAL_GTAG);
        }
      }
    } catch (err) {
      // Ignore and continue with the append.
    }
    return originalAppendChild.call(this, node);
  };

  if (typeof window.fetch === 'function') {
    const originalFetch = window.fetch;
    window.fetch = function (resource, init) {
      const url = typeof resource === 'string' ? resource : resource && resource.url;
      if (url && url.indexOf(CLIENT_SETTINGS_PATH) !== -1) {
        return Promise.resolve(
          new Response(CLIENT_SETTINGS_BODY, {
            status: 200,
            headers: { 'Content-Type': 'application/json' }
          })
        );
      }
      return originalFetch.apply(this, arguments);
    };
  }
  try {
    var style = document.createElement('style');
    style.textContent = 'svg[data-v-05dd3f0e]{font-family:"Quicksand","Roboto",-apple-system,BlinkMacSystemFont,"Helvetica Neue",Arial,sans-serif;font-weight:700;}';
    if (document && document.head) {
      document.head.appendChild(style);
    } else {
      document.addEventListener('DOMContentLoaded', function () {
        document.head && document.head.appendChild(style);
      }, { once: true });
    }
  } catch (err) {
    // ignore
  }
})();
