const WON = window.WON = window.WON || {};
const ENGINE_READY_EVENT = 'won:wheel-engine-ready';
const callbacks = [];
let currentEngine = null;

function notify(engine) {
  if (!engine || currentEngine === engine) {
    return engine;
  }
  currentEngine = engine;
  WON.wheelEngine = engine;
  while (callbacks.length) {
    const cb = callbacks.shift();
    try {
      cb(engine);
    } catch (err) {
      setTimeout(() => { throw err; }, 0);
    }
  }
  try {
    window.dispatchEvent(new CustomEvent(ENGINE_READY_EVENT, { detail: { engine } }));
  } catch (err) {
    console.warn('[WON] Dispatching wheel engine ready event failed.', err);
  }
  return engine;
}

WON.onWheelEngineReady = function onWheelEngineReady(handler) {
  if (typeof handler !== 'function') {
    return () => {};
  }
  if (currentEngine) {
    handler(currentEngine);
    return () => {};
  }
  callbacks.push(handler);
  return () => {
    const idx = callbacks.indexOf(handler);
    if (idx >= 0) {
      callbacks.splice(idx, 1);
    }
  };
};

import('/assets/index-v385.js')
  .then((mod) => {
    const WheelClass = mod?.b6;
    if (!WheelClass) {
      console.warn('[WON] Wheel engine class could not be found.');
      return;
    }
    if (WheelClass.prototype.__wonExposePatched) {
      return;
    }
    const originalDraw = WheelClass.prototype.draw;
    WheelClass.prototype.draw = function patchedDraw(...args) {
      notify(this);
      return originalDraw.apply(this, args);
    };
    WheelClass.prototype.__wonExposePatched = true;
    if (currentEngine instanceof WheelClass) {
      notify(currentEngine);
    }
  })
  .catch((err) => {
    console.warn('[WON] Failed to patch wheel engine.', err);
  });
