// Offline stub for Google Analytics so the cloned site never reaches out to Google.
(function (global) {
  global.dataLayer = global.dataLayer || [];
  global.gtag = global.gtag || function () {
    global.dataLayer.push(arguments);
  };
})(typeof window !== 'undefined' ? window : self);
