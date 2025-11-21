(function () {
  const WON = window.WON = window.WON || {};
  const TWO_PI = Math.PI * 2;

  function normalizeAngle(value) {
    if (!Number.isFinite(value)) {
      return 0;
    }
    let angle = value % TWO_PI;
    if (angle < 0) {
      angle += TWO_PI;
    }
    return angle;
  }

  function cryptoRandomInt(min, max) {
    const range = max - min + 1;
    if (range <= 0) return min;
    if (window.crypto && window.crypto.getRandomValues) {
      const array = new Uint32Array(1);
      let usableMax = Math.floor(0xffffffff / range) * range;
      let value;
      do {
        window.crypto.getRandomValues(array);
        value = array[0];
      } while (value >= usableMax);
      return min + (value % range);
    }
    return min + Math.floor(Math.random() * range);
  }

  const Geometry = (function () {
    let engine = null;

    function attach(newEngine) {
      engine = newEngine;
    }

    function requireEngine() {
      if (!engine) {
        throw new Error('[WON] Wheel engine not ready');
      }
      return engine;
    }

    function getDisplayEntries() {
      const current = requireEngine();
      if (current && current.entryPicker && typeof current.entryPicker.getDisplayEntries === 'function') {
        const entries = current.entryPicker.getDisplayEntries();
        return Array.isArray(entries) ? entries.slice() : [];
      }
      return [];
    }

    function computeSlices() {
      const entries = getDisplayEntries();
      const sliceCount = entries.length;
      if (!sliceCount) {
        return [];
      }
      let hasExplicitWeights = false;
      const weights = entries.map((entry) => {
        const weight = entry && typeof entry.weight === 'number' && entry.weight > 0 ? entry.weight : 1;
        if (weight !== 1) hasExplicitWeights = true;
        return weight;
      });
      const totalWeight = hasExplicitWeights ? weights.reduce((sum, value) => sum + value, 0) : sliceCount;
      const slices = [];
      let cursor = 0;
      for (let i = 0; i < sliceCount; i += 1) {
        const weight = hasExplicitWeights ? weights[i] : 1;
        const arc = TWO_PI * (weight / totalWeight || 0);
        const start = cursor;
        const end = cursor + arc;
        const center = start + arc / 2;
        slices.push({ start, end, center });
        cursor = end;
      }
      // Numerical rounding may leave the final end slightly short; adjust the last slice
      if (slices.length) {
        slices[slices.length - 1].end = TWO_PI;
      }
      return slices;
    }

    function getSliceCount() {
      return getDisplayEntries().length;
    }

    function getSliceCenterAngle(index) {
      const entries = getDisplayEntries();
      const count = entries.length;
      if (!count) {
        return 0;
      }

      const normalizedIndex = ((index % count) + count) % count;

      // Match the engine's uniform-slice math (iC) by using
      // multiples of the base angle step as the "centers".
      if (!entries[0] || !entries[0].weight) {
        const step = TWO_PI / count;
        return normalizeAngle(normalizedIndex * step);
      }

      // Fallback for weighted slices: use our approximate centers.
      const slices = computeSlices();
      if (!slices.length) {
        return 0;
      }
      return normalizeAngle(slices[normalizedIndex].center);
    }

    function getSliceWidth(index) {
      const slices = computeSlices();
      if (!slices.length) {
        return TWO_PI;
      }
      const normalizedIndex = ((index % slices.length) + slices.length) % slices.length;
      const slice = slices[normalizedIndex];
      const span = (slice.end - slice.start) || 0;
      return Math.max(0, span);
    }

    function getDisplayIndexAtAngle(angle) {
      const slices = computeSlices();
      if (!slices.length) return -1;
      const normalized = normalizeAngle(angle);
      for (let i = 0; i < slices.length; i += 1) {
        const slice = slices[i];
        if (normalized >= slice.start && normalized < slice.end) {
          return i;
        }
      }
      return slices.length - 1;
    }

    function getCurrentAngle() {
      const current = requireEngine();
      return normalizeAngle(current.angle || 0);
    }

    return {
      attach,
      getDisplayEntries,
      getSliceCount,
      getSliceCenterAngle,
      getSliceWidth,
      getDisplayIndexAtAngle,
      getCurrentAngle,
    };
  }());

  const SpinEngine = (function () {
    function easeOutCubic(t) {
      const clamped = Math.max(0, Math.min(1, t));
      return 1 - Math.pow(1 - clamped, 3);
    }

    return {
      easeOutCubic,
    };
  }());

  function createCheatModule() {
    const TAP_COUNT = 5;
    const TAP_WINDOW_MS = 3000;
    const state = {
      forcedIndex: null,
      tapTimes: [],
      panel: null,
      selectEl: null,
    };

    function closePanel() {
      if (state.panel && state.panel.parentNode) {
        state.panel.parentNode.removeChild(state.panel);
      }
      state.panel = null;
      state.selectEl = null;
    }

    function buildOptionLabel(entry, index) {
      if (!entry) {
        return `Slice ${index + 1}`;
      }
      if (entry.text && typeof entry.text === 'string' && entry.text.trim()) {
        return entry.text.trim();
      }
      if (entry.image) {
        return `Image slice ${index + 1}`;
      }
      return `Slice ${index + 1}`;
    }

    function populateOptions(select, onReady) {
      const entries = Geometry.getDisplayEntries();
      select.innerHTML = '';

      if (!entries.length) {
        if (typeof onReady === 'function') {
          onReady();
        }
        return;
      }

      let index = 0;
      let fragment = document.createDocumentFragment();
      const BATCH_SIZE = 400;

      function flushFragment() {
        if (fragment.childNodes.length) {
          select.appendChild(fragment);
          fragment = document.createDocumentFragment();
        }
      }

      function appendBatch(deadline) {
        const start = performance.now();
        const hasTime = () => {
          if (deadline && typeof deadline.timeRemaining === 'function') {
            return deadline.timeRemaining() > 1;
          }
          return performance.now() - start < 12;
        };

        while (index < entries.length && hasTime()) {
          const entry = entries[index];
          const option = document.createElement('option');
          option.value = String(index);
          option.textContent = buildOptionLabel(entry, index);
          fragment.appendChild(option);
          index += 1;
          if (index % BATCH_SIZE === 0) {
            flushFragment();
          }
        }

        flushFragment();

        if (index < entries.length) {
          const schedule = window.requestIdleCallback || window.requestAnimationFrame;
          schedule(appendBatch);
        } else {
          select.selectedIndex = 0;
          select.disabled = false;
          if (typeof onReady === 'function') {
            onReady();
          }
        }
      }

      select.disabled = true;
      const schedule = window.requestIdleCallback || window.requestAnimationFrame;
      schedule(appendBatch);
    }

    function applySelection() {
      if (!state.selectEl) {
        closePanel();
        return;
      }
      const selected = Number.parseInt(state.selectEl.value, 10);
      if (Number.isInteger(selected)) {
        state.forcedIndex = selected;
      }
      closePanel();
    }

    function cancelSelection() {
      closePanel();
    }

    function openPanel() {
      closePanel();
      const panel = document.createElement('div');
      panel.style.position = 'fixed';
      panel.style.bottom = '16px';
      panel.style.right = '16px';
      panel.style.background = 'rgba(0,0,0,0.8)';
      panel.style.color = '#fff';
      panel.style.width = '240px';
      panel.style.borderRadius = '8px';
      panel.style.boxShadow = '0 4px 12px rgba(0,0,0,0.45)';
      panel.style.padding = '12px';
      panel.style.fontFamily = 'Roboto, -apple-system, BlinkMacSystemFont, sans-serif';
      panel.style.zIndex = '2147483647';

      const title = document.createElement('div');
      title.textContent = 'Cheat mode';
      title.style.marginBottom = '8px';
      title.style.fontSize = '0.95rem';
      title.style.fontWeight = '600';

      const select = document.createElement('select');
      select.style.width = '100%';
      select.style.margin = '8px 0 12px';
      select.style.padding = '6px';
      select.style.fontSize = '0.9rem';
      select.style.borderRadius = '4px';
      select.setAttribute('aria-label', 'Choose winner');

      const buttonRow = document.createElement('div');
      buttonRow.style.display = 'flex';
      buttonRow.style.gap = '8px';
      buttonRow.style.marginTop = '8px';

      const applyBtn = document.createElement('button');
      applyBtn.textContent = 'Set for next spin';
      applyBtn.style.flex = '1';
      applyBtn.style.padding = '8px';
      applyBtn.style.fontSize = '0.9rem';
      applyBtn.style.background = '#3369e8';
      applyBtn.style.color = '#fff';
      applyBtn.style.border = 'none';
      applyBtn.style.borderRadius = '4px';
      applyBtn.style.cursor = 'pointer';
      applyBtn.disabled = true;
      populateOptions(select, () => {
        applyBtn.disabled = false;
      });

      const cancelBtn = document.createElement('button');
      cancelBtn.textContent = 'Cancel';
      cancelBtn.style.flex = '1';
      cancelBtn.style.padding = '8px';
      cancelBtn.style.fontSize = '0.9rem';
      cancelBtn.style.background = '#444';
      cancelBtn.style.color = '#fff';
      cancelBtn.style.border = 'none';
      cancelBtn.style.borderRadius = '4px';
      cancelBtn.style.cursor = 'pointer';

      applyBtn.addEventListener('click', applySelection);
      cancelBtn.addEventListener('click', cancelSelection);
      const closeBtn = document.createElement('button');
      closeBtn.textContent = '×';
      closeBtn.style.position = 'absolute';
      closeBtn.style.top = '4px';
      closeBtn.style.right = '8px';
      closeBtn.style.border = 'none';
      closeBtn.style.background = 'transparent';
      closeBtn.style.color = '#aaa';
      closeBtn.style.fontSize = '1.1rem';
      closeBtn.style.cursor = 'pointer';
      closeBtn.addEventListener('click', cancelSelection);

      document.addEventListener('keydown', function onKey(event) {
        if (event.key === 'Escape') {
          document.removeEventListener('keydown', onKey);
          cancelSelection();
        }
      }, { once: true });

      buttonRow.appendChild(cancelBtn);
      buttonRow.appendChild(applyBtn);

      panel.appendChild(closeBtn);
      panel.appendChild(title);
      panel.appendChild(select);
      panel.appendChild(buttonRow);
      document.body.appendChild(panel);
      state.panel = panel;
      state.selectEl = select;
    }

    function handleHotspotTap(timestamp) {
      state.tapTimes = state.tapTimes.filter((time) => timestamp - time <= TAP_WINDOW_MS);
      state.tapTimes.push(timestamp);
      if (state.tapTimes.length >= TAP_COUNT) {
        state.tapTimes = [];
        openPanel();
      }
    }

    function consumeForcedWinner() {
      const sliceCount = Geometry.getSliceCount();
      if (!sliceCount) {
        state.forcedIndex = null;
        return null;
      }
      if (!Number.isInteger(state.forcedIndex)) {
        return null;
      }
      const clamped = Math.max(0, Math.min(sliceCount - 1, state.forcedIndex));
      state.forcedIndex = null;
      return clamped;
    }

    function createHotspot() {
      const hotspot = document.createElement('div');
      hotspot.style.position = 'fixed';
      hotspot.style.bottom = '0';
      hotspot.style.left = '0';
      hotspot.style.width = '64px';
      hotspot.style.height = '64px';
      hotspot.style.zIndex = '2147483647';
      hotspot.style.cursor = 'pointer';
      hotspot.style.background = 'transparent';
      hotspot.style.touchAction = 'manipulation';
      hotspot.style.userSelect = 'none';
      hotspot.addEventListener('click', () => handleHotspotTap(performance.now()));
      document.body.appendChild(hotspot);
    }

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', createHotspot);
    } else {
      createHotspot();
    }

    return {
      consumeForcedWinner,
      openPanel,
      closePanel,
      handleHotspotTap,
    };
  }

  const Cheat = createCheatModule();

  const SpinController = (function () {
    let activeSpin = null;

    const api = {
      attach(engine) {
        patchWheelPrototype(engine);
      },
      handleClick(engine) {
        if (!engine || activeSpin) {
          return !!activeSpin;
        }
        const sliceCount = Geometry.getSliceCount();
        if (!sliceCount) {
          return false;
        }
        // Step 1: choose the target slice (cheat wins once, otherwise random).
        const forcedIndex = Cheat.consumeForcedWinner();
        const targetIndex = Number.isInteger(forcedIndex)
          ? forcedIndex
          : cryptoRandomInt(0, sliceCount - 1);

        // Step 2: convert slice index to the engine-aligned center angle.
        const centerAngle = Geometry.getSliceCenterAngle(targetIndex);

        // Step 3: measure the slice width so we can jitter safely inside it.
        const sliceWidth = Geometry.getSliceWidth(targetIndex);

        // Step 4: apply the same jitter logic for cheat + normal spins.
        // Pick a random percent between 0% and 45% of the slice width so
        // the pointer always remains inside the intended slice.
        const jitterPercent = cryptoRandomInt(0, 45) / 100;
        const jitterLimit = sliceWidth * jitterPercent;
        const jitterUnit = cryptoRandomInt(-1000, 1000) / 1000; // [-1, 1]
        const jitter = jitterUnit * jitterLimit;
        const adjustedCenter = centerAngle + jitter;

        // Step 5: add multiple full rotations to keep the animation natural.
        const currentAngle = Geometry.getCurrentAngle();
        const extraRotations = 6 + cryptoRandomInt(0, 2);
        const targetAngle = adjustedCenter + extraRotations * TWO_PI;
        activeSpin = {
          engine,
          startAngle: currentAngle,
          targetAngle,
          durationMs: 6000,
          easing: SpinEngine.easeOutCubic,
          startedAt: null,
        };
        return true;
      },
      step(engine) {
        if (!activeSpin || activeSpin.engine !== engine) {
          return false;
        }
        if (!activeSpin.startedAt) {
          activeSpin.startedAt = performance.now();
        }
        const elapsed = performance.now() - activeSpin.startedAt;
        const progress = Math.min(1, elapsed / activeSpin.durationMs);
        const eased = activeSpin.easing ? activeSpin.easing(progress) : progress;
        const delta = activeSpin.targetAngle - activeSpin.startAngle;
        const rawAngle = activeSpin.startAngle + delta * eased;
        applyAngle(engine, rawAngle);
        if (progress >= 1) {
          finishSpin(engine);
        }
        return true;
      },
    };

    function patchWheelPrototype(engine) {
      if (!engine || !engine.constructor || !engine.constructor.prototype) {
        return;
      }
      const proto = engine.constructor.prototype;
      if (proto.__wonCustomSpinPatched) {
        return;
      }
      const originalClick = proto.click;
      const originalTick = proto.tick;

      proto.__wonOriginalClick = originalClick;
      proto.__wonOriginalTick = originalTick;

      proto.click = function patchedClick(...args) {
        if (api.handleClick(this)) {
          return;
        }
        return originalClick.apply(this, args);
      };

      proto.tick = function patchedTick(randomFn) {
        if (api.step(this)) {
          return { state: 'WonCustomSpin', angle: this.angle };
        }
        return originalTick.call(this, randomFn);
      };

      proto.__wonCustomSpinPatched = true;
    }

    function applyAngle(engine, rawAngle) {
      const normalized = normalizeAngle(rawAngle);
      engine.angle = normalized;
      const previousIndex = typeof engine.indexFromThisTick === 'number'
        ? engine.indexFromThisTick
        : engine.getIndexAtPointer();
      engine.indexFromLastTick = previousIndex;
      const nextIndex = engine.getIndexAtPointer();
      engine.indexFromThisTick = nextIndex;
      if (nextIndex !== engine.indexFromLastTick && typeof engine.nameChangedCallback === 'function') {
        try {
          engine.nameChangedCallback();
        } catch (err) {
          console.warn('[WON] nameChangedCallback failed', err);
        }
      }
      if (engine.entryPicker && typeof engine.entryPicker.tick === 'function') {
        const needsRefresh = engine.entryPicker.tick(nextIndex);
        if (needsRefresh && typeof engine.refresh === 'function') {
          engine.refresh();
        }
      }
    }

    function finishSpin(engine) {
      activeSpin = null;
      engine.speed = 0;
      try {
        if (typeof engine.doneSpinningCallback === 'function') {
          engine.doneSpinningCallback(engine.getEntryAtPointer());
        }
      } catch (err) {
        console.warn('[WON] doneSpinningCallback failed', err);
      }
    }

    return api;
  }());

  function patchHighSliceRenderer(engine) {
    if (!engine || !engine.constructor || !engine.constructor.prototype) {
      return;
    }

    const proto = engine.constructor.prototype;
    if (proto.__wonHighSlicePatched) {
      return;
    }

    const originalDrawBasicSlices = proto.drawBasicSlices;

    function pickColor(entry, wheelConfig, index) {
      if (entry && entry.color) {
        return entry.color;
      }

      const palette = wheelConfig && Array.isArray(wheelConfig.colors)
        ? wheelConfig.colors
        : null;
      if (palette && palette.length) {
        return palette[index % palette.length];
      }

      return '#ccc';
    }

    function buildCacheKey(renderState) {
      const { displayEntries, wheelConfig, wheelRadius } = renderState || {};
      const outline = wheelConfig && typeof wheelConfig.outlineWidth === 'number'
        ? wheelConfig.outlineWidth
        : 0;
      const outlineColor = wheelConfig && wheelConfig.outlineColor
        ? wheelConfig.outlineColor
        : 'transparent';
      const palette = wheelConfig && Array.isArray(wheelConfig.colors)
        ? wheelConfig.colors
        : [];
      const entrySwatch = (displayEntries || [])
        .slice(0, 48)
        .map((entry) => (entry && entry.color) || '')
        .join(',');

      return [
        displayEntries ? displayEntries.length : 0,
        wheelRadius || 0,
        outline,
        outlineColor,
        palette.join(','),
        entrySwatch,
      ].join('|');
    }

    function renderStableSlices(engine, renderState, cacheKey) {
      const { context, displayEntries, wheelConfig, wheelRadius } = renderState || {};
      if (!context || !displayEntries || !displayEntries.length || !wheelRadius) {
        return null;
      }

      const count = displayEntries.length;
      const radians = TWO_PI / count;
      const outline = wheelConfig && typeof wheelConfig.outlineWidth === 'number'
        ? wheelConfig.outlineWidth
        : 0;
      const outlineColor = wheelConfig && wheelConfig.outlineColor
        ? wheelConfig.outlineColor
        : 'transparent';

      const diameter = Math.max(2, Math.ceil(wheelRadius * 2 + outline * 2 + 4));
      const cacheCanvas = engine.__wonHighSliceCache && engine.__wonHighSliceCache.canvas
        ? engine.__wonHighSliceCache.canvas
        : document.createElement('canvas');
      cacheCanvas.width = diameter;
      cacheCanvas.height = diameter;
      const cacheCtx = cacheCanvas.getContext('2d');
      cacheCtx.save();
      cacheCtx.clearRect(0, 0, diameter, diameter);
      cacheCtx.translate(diameter / 2, diameter / 2);

      const baseColor = pickColor(displayEntries[0] || {}, wheelConfig, 0);
      cacheCtx.beginPath();
      cacheCtx.arc(0, 0, wheelRadius, 0, TWO_PI);
      cacheCtx.closePath();
      cacheCtx.fillStyle = baseColor;
      cacheCtx.fill();

      for (let index = 0; index < count; index += 1) {
        const slice = displayEntries[index] || {};
        const start = -index * radians;
        const end = start - radians;
        const fillColor = pickColor(slice, wheelConfig, index);

        cacheCtx.beginPath();
        cacheCtx.moveTo(0, 0);
        cacheCtx.arc(0, 0, wheelRadius, start, end, true);
        cacheCtx.closePath();
        cacheCtx.fillStyle = fillColor;
        cacheCtx.fill();
      }

      if (outline > 0) {
        cacheCtx.beginPath();
        cacheCtx.arc(0, 0, Math.max(0, wheelRadius - outline / 2), 0, TWO_PI);
        cacheCtx.closePath();
        cacheCtx.lineWidth = Math.max(0.5, outline);
        cacheCtx.strokeStyle = outlineColor;
        cacheCtx.stroke();
      }

      cacheCtx.restore();
      engine.__wonHighSliceCache = { key: cacheKey, canvas: cacheCanvas };
      return cacheCanvas;
    }

    proto.drawBasicSlices = function patchedDrawBasicSlices(renderState) {
      try {
        if (renderState && renderState.displayEntries && renderState.displayEntries.length >= 2000) {
          const key = buildCacheKey(renderState);
          const cached = this.__wonHighSliceCache && this.__wonHighSliceCache.canvas;
          const isStale = !this.__wonHighSliceCache || this.__wonHighSliceCache.key !== key;
          const canvas = isStale ? renderStableSlices(this, renderState, key) : cached;
          if (canvas) {
            const ctx = renderState.context;
            ctx.save();
            ctx.drawImage(canvas, -canvas.width / 2, -canvas.height / 2);
            ctx.restore();
            return true;
          }
        }
      } catch (err) {
        console.warn('[WON] Stable slice renderer failed; falling back', err);
      }

      return originalDrawBasicSlices.call(this, renderState);
    };

    proto.__wonHighSlicePatched = true;
  }

  function setupWithEngine(engine) {
    try {
      Geometry.attach(engine);
      SpinController.attach(engine);
      patchHighSliceRenderer(engine);
    } catch (err) {
      console.warn('[WON] Failed to attach spin controller', err);
    }
  }

  WON.Geometry = Geometry;
  WON.SpinEngine = SpinEngine;
  WON.Cheat = Cheat;
  WON.SpinController = SpinController;

  if (typeof WON.onWheelEngineReady === 'function') {
    WON.onWheelEngineReady(setupWithEngine);
  }
}());
