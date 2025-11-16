// Offline stub to satisfy gtag() calls when analytics is disabled.
(function (global) {
  global.dataLayer = global.dataLayer || [];
  global.gtag = global.gtag || function () {
    global.dataLayer.push(arguments);
  };
})(typeof window !== 'undefined' ? window : self);
