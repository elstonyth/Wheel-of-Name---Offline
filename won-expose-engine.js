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

// FIX: Dynamically discover the versioned index asset instead of hardcoding
async function discoverAndPatchEngine() {
  // Try to find the index script from existing script tags
  const scripts = Array.from(document.querySelectorAll('script[src*="index-"]'));
  let indexPath = null;
  
  for (const script of scripts) {
    const src = script.getAttribute('src') || '';
    if (/\/assets\/index-[a-zA-Z0-9]+\.js/.test(src)) {
      indexPath = src;
      break;
    }
  }
  
  // Fallback: search for any versioned index in /assets/
  if (!indexPath) {
    // Try common patterns
    const patterns = [
      '/assets/index-v385.js',
      '/assets/index.js'
    ];
    for (const pattern of patterns) {
      try {
        const response = await fetch(pattern, { method: 'HEAD' });
        if (response.ok) {
          indexPath = pattern;
          break;
        }
      } catch (e) {
        // Continue to next pattern
      }
    }
  }
  
  if (!indexPath) {
    console.warn('[WON] Could not discover index asset path. Trying default...');
    indexPath = '/assets/index-v385.js';
  }
  
  try {
    const mod = await import(indexPath);
    
    // FIX: Search for WheelClass more robustly by checking exports
    let WheelClass = null;
    const exportKeys = Object.keys(mod || {});
    
    // First try known export name
    if (mod?.b6 && typeof mod.b6 === 'function') {
      WheelClass = mod.b6;
    } else {
      // Search for a class with wheel-like properties
      for (const key of exportKeys) {
        const candidate = mod[key];
        if (typeof candidate === 'function' && candidate.prototype) {
          const proto = candidate.prototype;
          // Look for wheel engine signatures: draw, tick, click methods
          if (typeof proto.draw === 'function' && 
              (typeof proto.tick === 'function' || typeof proto.click === 'function')) {
            WheelClass = candidate;
            console.log(`[WON] Found wheel engine class at export '${key}'`);
            break;
          }
        }
      }
    }
    
    if (!WheelClass) {
      console.warn('[WON] Wheel engine class could not be found in exports:', exportKeys.slice(0, 10));
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
  } catch (err) {
    console.warn('[WON] Failed to patch wheel engine.', err);
  }
}

discoverAndPatchEngine();
