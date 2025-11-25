#!/usr/bin/env node
const puppeteer = require('puppeteer');
const fs = require('fs-extra');
const path = require('path');
const http = require('http');
const https = require('https');
const net = require('net');
const os = require('os');
const { URL } = require('url');
const WebSocket = require('ws');
let qrcode;
try {
  qrcode = require('qrcode-terminal');
} catch (e) {
  qrcode = null; // Optional dependency
}

// DNS server for custom hostname resolution
let DNS2;
try {
  DNS2 = require('dns2');
} catch (e) {
  DNS2 = null;
}

let dnsServer = null;
let customHostname = null;

// Start DNS server for custom hostname
function startDnsServer(hostname, localIP) {
  if (!DNS2) {
    console.log('⚠️  DNS server not available (dns2 not installed)');
    return false;
  }
  
  customHostname = hostname.toLowerCase();
  const { Packet } = DNS2;
  
  const server = DNS2.createServer({
    udp: true,
    handle: async (request, send, rinfo) => {
      const response = Packet.createResponseFromRequest(request);
      const [question] = request.questions;
      const name = question.name.toLowerCase();
      
      // Resolve custom hostname to local IP
      if (name === customHostname || name === customHostname + '.') {
        response.answers.push({
          name: question.name,
          type: Packet.TYPE.A,
          class: Packet.CLASS.IN,
          ttl: 300,
          address: localIP
        });
        send(response);
        return;
      }
      
      // Forward other queries to upstream DNS (Google)
      try {
        const resolver = new DNS2({ dns: '8.8.8.8' });
        const result = await resolver.resolveA(name);
        result.answers.forEach(answer => {
          response.answers.push(answer);
        });
      } catch (e) {
        // No answer found
      }
      send(response);
    }
  });
  
  server.on('error', (err) => {
    if (err.code === 'EACCES' || err.code === 'EADDRINUSE') {
      console.log('⚠️  DNS server needs admin rights or port 53 is in use');
      return;
    }
    console.error('DNS error:', err.message);
  });
  
  try {
    server.listen({ udp: 53 });
    dnsServer = server;
    console.log(`🌐 DNS server running → ${customHostname} resolves to ${localIP}`);
    console.log(`\n📋 TO USE ON OTHER DEVICES:`);
    console.log(`   1. Go to WiFi settings on your phone/device`);
    console.log(`   2. Change DNS to: ${localIP}`);
    console.log(`   3. Open: http://${customHostname}/remote\n`);
    return true;
  } catch (e) {
    console.log('⚠️  Could not start DNS server:', e.message);
    return false;
  }
}

const TARGET_URL = 'https://wheelofnames.com/';
const OUTPUT_DIR = 'cloned-site-offline';

// ────────────────────────────────
// Local Server for Preview
// ────────────────────────────────
let serverInstance = null;
let wss = null;
const wsClients = { displays: new Set(), remotes: new Set() };
let cachedEntries = [];

// Get local network IP
function getLocalIP() {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        return iface.address;
      }
    }
  }
  return '127.0.0.1';
}

// Broadcast to all display clients
function broadcastToDisplays(message) {
  const data = JSON.stringify(message);
  wsClients.displays.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(data);
    }
  });
}

// Broadcast to all remote clients
function broadcastToRemotes(message) {
  const data = JSON.stringify(message);
  wsClients.remotes.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(data);
    }
  });
}

// Remote control HTML page
function getRemoteControlHTML(port) {
  const localIP = getLocalIP();
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="theme-color" content="#0f0f1a">
  <title>🎯 Remote</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
    html, body { height: 100%; overflow: hidden; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #0f0f1a 0%, #1a1a2e 50%, #16213e 100%);
      color: #fff;
      display: flex;
      flex-direction: column;
    }
    
    /* Header */
    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 16px;
      background: rgba(0,0,0,0.3);
      border-bottom: 1px solid rgba(255,255,255,0.1);
    }
    .header h1 {
      font-size: 1.1rem;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .status-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background: #ef4444;
      box-shadow: 0 0 8px #ef4444;
      transition: all 0.3s;
    }
    .status-dot.connected {
      background: #22c55e;
      box-shadow: 0 0 8px #22c55e;
    }
    .refresh-btn {
      background: rgba(255,255,255,0.1);
      border: none;
      color: #fff;
      width: 36px;
      height: 36px;
      border-radius: 50%;
      font-size: 1.2rem;
      cursor: pointer;
      transition: all 0.2s;
    }
    .refresh-btn:active { transform: scale(0.9); background: rgba(255,255,255,0.2); }
    
    /* Main content */
    .main {
      flex: 1;
      display: flex;
      flex-direction: column;
      padding: 12px;
      overflow: hidden;
      gap: 10px;
    }
    
    /* Selected display card */
    .selected-card {
      background: linear-gradient(135deg, #1e3a5f 0%, #0f3460 100%);
      border-radius: 12px;
      padding: 16px;
      text-align: center;
      border: 1px solid rgba(96, 165, 250, 0.3);
      box-shadow: 0 4px 20px rgba(0,0,0,0.3);
      position: relative;
    }
    .selected-label { font-size: 0.75rem; color: #94a3b8; text-transform: uppercase; letter-spacing: 1px; }
    .selected-name {
      font-size: 1.4rem;
      font-weight: 700;
      color: #60a5fa;
      margin-top: 4px;
      word-break: break-word;
    }
    .selected-name.none { color: #64748b; font-style: italic; font-weight: 400; }
    .cancel-btn {
      position: absolute;
      top: 8px;
      right: 8px;
      background: rgba(239, 68, 68, 0.2);
      border: 1px solid rgba(239, 68, 68, 0.3);
      color: #f87171;
      width: 28px;
      height: 28px;
      border-radius: 50%;
      font-size: 1rem;
      cursor: pointer;
      display: none;
      align-items: center;
      justify-content: center;
      transition: all 0.2s;
    }
    .cancel-btn.visible { display: flex; }
    .cancel-btn:active { background: rgba(239, 68, 68, 0.4); transform: scale(0.9); }
    
    /* Search container */
    .search-container {
      position: relative;
    }
    .search-box {
      width: 100%;
      padding: 14px 44px 14px 16px;
      font-size: 1rem;
      border: 2px solid rgba(255,255,255,0.1);
      border-radius: 12px;
      background: rgba(255,255,255,0.05);
      color: #fff;
      transition: all 0.2s;
    }
    .search-box::placeholder { color: #64748b; }
    .search-box:focus { outline: none; border-color: #3b82f6; background: rgba(59, 130, 246, 0.1); }
    .clear-btn {
      position: absolute;
      right: 8px;
      top: 50%;
      transform: translateY(-50%);
      background: rgba(255,255,255,0.1);
      border: none;
      color: #94a3b8;
      width: 28px;
      height: 28px;
      border-radius: 50%;
      font-size: 1rem;
      cursor: pointer;
      display: none;
    }
    .clear-btn.visible { display: block; }
    
    /* Entries list */
    .list-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 0 4px;
    }
    .count { font-size: 0.8rem; color: #64748b; }
    .entries-list {
      flex: 1;
      background: rgba(0,0,0,0.2);
      border-radius: 12px;
      overflow-y: auto;
      border: 1px solid rgba(255,255,255,0.05);
      -webkit-overflow-scrolling: touch;
    }
    .entry {
      padding: 16px;
      border-bottom: 1px solid rgba(255,255,255,0.05);
      cursor: pointer;
      transition: all 0.15s;
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .entry:last-child { border-bottom: none; }
    .entry:active { background: rgba(59, 130, 246, 0.2); }
    .entry.selected { 
      background: linear-gradient(90deg, rgba(59, 130, 246, 0.3) 0%, rgba(59, 130, 246, 0.1) 100%);
      border-left: 3px solid #3b82f6;
    }
    .entry-index {
      width: 32px;
      height: 32px;
      background: rgba(255,255,255,0.1);
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 0.75rem;
      color: #94a3b8;
      flex-shrink: 0;
    }
    .entry.selected .entry-index { background: #3b82f6; color: #fff; }
    .entry-text {
      flex: 1;
      font-size: 1rem;
      word-break: break-word;
    }
    .entry-check {
      width: 24px;
      height: 24px;
      border-radius: 50%;
      border: 2px solid rgba(255,255,255,0.2);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 0.8rem;
      flex-shrink: 0;
      opacity: 0;
      transition: all 0.2s;
    }
    .entry.selected .entry-check { opacity: 1; background: #3b82f6; border-color: #3b82f6; }
    
    /* Empty state */
    .empty-state {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 40px 20px;
      color: #64748b;
      text-align: center;
    }
    .empty-icon { font-size: 3rem; margin-bottom: 12px; opacity: 0.5; }
    
    /* Bottom action */
    .bottom-action {
      padding: 12px;
      padding-bottom: max(12px, env(safe-area-inset-bottom));
      background: rgba(0,0,0,0.4);
      border-top: 1px solid rgba(255,255,255,0.1);
    }
    .btn-set {
      width: 100%;
      padding: 18px;
      font-size: 1.1rem;
      font-weight: 600;
      background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
      color: #fff;
      border: none;
      border-radius: 12px;
      cursor: pointer;
      transition: all 0.2s;
      box-shadow: 0 4px 15px rgba(59, 130, 246, 0.4);
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
    }
    .btn-set:disabled { 
      background: #1e293b; 
      color: #475569; 
      cursor: not-allowed; 
      box-shadow: none;
    }
    .btn-set:not(:disabled):active { 
      transform: scale(0.98); 
      box-shadow: 0 2px 10px rgba(59, 130, 246, 0.3);
    }
    .btn-set.success {
      background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
      box-shadow: 0 4px 15px rgba(34, 197, 94, 0.4);
    }
    
    /* Toast notification */
    .toast {
      position: fixed;
      top: 20px;
      left: 50%;
      transform: translateX(-50%) translateY(-100px);
      background: #22c55e;
      color: #fff;
      padding: 12px 24px;
      border-radius: 30px;
      font-weight: 600;
      box-shadow: 0 4px 20px rgba(0,0,0,0.3);
      transition: transform 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
      z-index: 1000;
    }
    .toast.show { transform: translateX(-50%) translateY(0); }
  </style>
</head>
<body>
  <div class="header">
    <h1><span class="status-dot" id="statusDot"></span> Wheel Remote</h1>
    <button class="refresh-btn" onclick="location.reload()" title="Refresh">↻</button>
  </div>
  
  <div class="main">
    <div class="selected-card">
      <button class="cancel-btn" id="cancelSelectBtn" onclick="cancelSelection()">✕</button>
      <div class="selected-label">Next Winner</div>
      <div id="selectedName" class="selected-name none">Tap a name below</div>
    </div>
    
    <div class="search-container">
      <input type="text" id="search" class="search-box" placeholder="🔍  Search names...">
      <button class="clear-btn" id="clearBtn" onclick="clearSearch()">✕</button>
    </div>
    
    <div class="list-header">
      <span id="count" class="count">Loading...</span>
    </div>
    
    <div id="entriesList" class="entries-list"></div>
  </div>
  
  <div class="bottom-action">
    <button id="setBtn" class="btn-set" disabled>
      <span id="btnIcon">🎯</span>
      <span id="btnText">Select a name first</span>
    </button>
  </div>
  
  <div class="toast" id="toast">✓ Winner Set!</div>
  
  <script>
    const getWsUrl = () => {
      const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      let host = window.location.host;
      if (!host) {
        const hostname = window.location.hostname || '${localIP}';
        const fallbackPort = window.location.port || ${port};
        host = hostname + ':' + fallbackPort;
      }
      return protocol + '//' + host;
    };
    const ws = new WebSocket(getWsUrl());
    let entries = [];
    let selectedIndex = null;
    
    const statusDot = document.getElementById('statusDot');
    const searchEl = document.getElementById('search');
    const clearBtn = document.getElementById('clearBtn');
    const listEl = document.getElementById('entriesList');
    const countEl = document.getElementById('count');
    const selectedNameEl = document.getElementById('selectedName');
    const cancelSelectBtn = document.getElementById('cancelSelectBtn');
    const setBtnEl = document.getElementById('setBtn');
    const btnIcon = document.getElementById('btnIcon');
    const btnText = document.getElementById('btnText');
    const toast = document.getElementById('toast');
    
    ws.onopen = () => {
      statusDot.classList.add('connected');
      ws.send(JSON.stringify({ type: 'register', role: 'remote' }));
    };
    
    ws.onclose = () => {
      statusDot.classList.remove('connected');
      countEl.textContent = 'Disconnected - tap ↻ to reconnect';
    };
    
    ws.onmessage = (event) => {
      const msg = JSON.parse(event.data);
      if (msg.type === 'entries') {
        entries = msg.data || [];
        renderList();
      }
      if (msg.type === 'winner_set') {
        showSuccess();
      }
      if (msg.type === 'winner_confirmed') {
        showWinnerConfirmed(msg.name || 'Winner');
      }
    };
    
    function showSuccess() {
      setBtnEl.classList.add('success');
      btnIcon.textContent = '✓';
      btnText.textContent = 'Queued!';
      toast.textContent = '✓ Winner Queued - Spin the wheel!';
      toast.style.background = '#3b82f6';
      toast.classList.add('show');
      
      setTimeout(() => {
        toast.classList.remove('show');
      }, 2000);
      
      setTimeout(() => {
        setBtnEl.classList.remove('success');
        btnIcon.textContent = '🎯';
        btnText.textContent = 'Set Winner';
        // Keep selection visible until spin confirms
      }, 1500);
    }
    
    function showWinnerConfirmed(winnerName) {
      // Clear selection after winner is confirmed
      selectedIndex = null;
      selectedNameEl.textContent = 'Tap a name below';
      selectedNameEl.classList.add('none');
      cancelSelectBtn.classList.remove('visible');
      setBtnEl.disabled = true;
      btnText.textContent = 'Select a name first';
      renderList();
      
      // Show confirmation toast
      toast.textContent = '🎉 ' + winnerName + ' WON!';
      toast.style.background = '#22c55e';
      toast.classList.add('show');
      
      // Haptic celebration
      if (navigator.vibrate) navigator.vibrate([50, 50, 50, 50, 100]);
      
      setTimeout(() => {
        toast.classList.remove('show');
      }, 3000);
    }
    
    function renderList() {
      const query = searchEl.value.toLowerCase().trim();
      clearBtn.classList.toggle('visible', query.length > 0);
      
      const filtered = entries.map((e, i) => ({ ...e, originalIndex: i }))
        .filter(e => !query || (e.text || '').toLowerCase().includes(query));
      
      if (entries.length === 0) {
        countEl.textContent = 'Waiting for wheel data...';
      } else if (query) {
        countEl.textContent = filtered.length + ' of ' + entries.length + ' names';
      } else {
        countEl.textContent = entries.length + ' names';
      }
      
      listEl.innerHTML = '';
      
      if (filtered.length === 0 && entries.length > 0) {
        listEl.innerHTML = '<div class="empty-state"><div class="empty-icon">🔍</div><div>No matches found</div></div>';
        return;
      }
      
      if (entries.length === 0) {
        listEl.innerHTML = '<div class="empty-state"><div class="empty-icon">⏳</div><div>Open the wheel on the display PC<br>to load names here</div></div>';
        return;
      }
      
      filtered.forEach(entry => {
        const div = document.createElement('div');
        div.className = 'entry' + (entry.originalIndex === selectedIndex ? ' selected' : '');
        
        const indexSpan = document.createElement('span');
        indexSpan.className = 'entry-index';
        indexSpan.textContent = entry.originalIndex + 1;
        
        const textSpan = document.createElement('span');
        textSpan.className = 'entry-text';
        textSpan.textContent = entry.text || 'Entry ' + (entry.originalIndex + 1);
        
        const checkSpan = document.createElement('span');
        checkSpan.className = 'entry-check';
        checkSpan.textContent = '✓';
        
        div.appendChild(indexSpan);
        div.appendChild(textSpan);
        div.appendChild(checkSpan);
        
        div.onclick = () => selectEntry(entry);
        listEl.appendChild(div);
      });
    }
    
    function selectEntry(entry) {
      selectedIndex = entry.originalIndex;
      const name = entry.text || 'Entry ' + (entry.originalIndex + 1);
      selectedNameEl.textContent = name;
      selectedNameEl.classList.remove('none');
      cancelSelectBtn.classList.add('visible');
      setBtnEl.disabled = false;
      btnText.textContent = 'Set Winner';
      renderList();
      
      // Haptic feedback if available
      if (navigator.vibrate) navigator.vibrate(10);
    }
    
    function cancelSelection() {
      selectedIndex = null;
      selectedNameEl.textContent = 'Tap a name below';
      selectedNameEl.classList.add('none');
      cancelSelectBtn.classList.remove('visible');
      setBtnEl.disabled = true;
      btnText.textContent = 'Select a name first';
      renderList();
      
      // Haptic feedback
      if (navigator.vibrate) navigator.vibrate(10);
    }
    
    function clearSearch() {
      searchEl.value = '';
      searchEl.focus();
      renderList();
    }
    
    searchEl.addEventListener('input', renderList);
    
    setBtnEl.onclick = () => {
      if (selectedIndex !== null && !setBtnEl.disabled) {
        ws.send(JSON.stringify({ type: 'set_winner', index: selectedIndex }));
        setBtnEl.disabled = true;
        btnText.textContent = 'Sending...';
        if (navigator.vibrate) navigator.vibrate([10, 50, 10]);
      }
    };
  </script>
</body>
</html>`;
}

async function startServer() {
  const preferred = process.env.PORT ? Number(process.env.PORT) : 8080;
  // FIX: Use findOpenPort for automatic port fallback
  const currentPort = await findOpenPort(preferred, 20);
  if (currentPort === 0) {
    console.error(`❌ Could not find an available port starting from ${preferred}`);
    process.exit(1);
  }
  if (currentPort !== preferred) {
    console.log(`⚠️ Port ${preferred} was in use. Using port ${currentPort} instead.`);
  }
  
  const server = http.createServer((req, res) => {
    const safePath = decodeURIComponent(req.url.split('?')[0]);
    
    // Offline stubs and API
    if (safePath.startsWith('/api/v2/client-settings')) {
      const clientSettings = {
        version: 1,
        spinsPerSecond: 1,
        ads: { enabled: false },
        features: {}
      };
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(clientSettings));
      return;
    }

    if (safePath === '/offline/gtag-stub.js') {
      res.writeHead(200, { 'Content-Type': 'application/javascript' });
      res.end('window.dataLayer=window.dataLayer||[];window.gtag=window.gtag||function(){/* offline */};');
      return;
    }
    if (safePath === '/won-expose-engine.js') {
      try {
        const exposePath = path.join(__dirname, 'won-expose-engine.js');
        const script = fs.readFileSync(exposePath, 'utf8');
        res.writeHead(200, { 'Content-Type': 'application/javascript' });
        res.end(script);
      } catch (err) {
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('/* failed to load won-expose-engine */');
      }
      return;
    }
    if (safePath === '/won-spin.js') {
      try {
        const spinPath = path.join(__dirname, 'won-spin.js');
        const script = fs.readFileSync(spinPath, 'utf8');
        res.writeHead(200, { 'Content-Type': 'application/javascript' });
        res.end(script);
      } catch (err) {
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('/* failed to load won-spin */');
      }
      return;
    }
    if (safePath.startsWith('/assets/DesktopAd')) {
      const isCss = safePath.endsWith('.css');
      res.writeHead(200, { 'Content-Type': isCss ? 'text/css' : 'application/javascript' });
      res.end('');
      return;
    }

    // Handle hashed preload scripts served at the site root
    if (/^\/[A-Za-z0-9_.=-]{12,}$/.test(safePath)) {
      res.writeHead(200, { 'Content-Type': 'application/javascript' });
      res.end('');
      return;
    }

    // Remote control page
    if (safePath === '/remote' || safePath === '/remote/') {
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(getRemoteControlHTML(currentPort));
      return;
    }

    // API endpoint to receive entries from display
    if (safePath === '/api/entries' && req.method === 'POST') {
      let body = '';
      req.on('data', chunk => { body += chunk; });
      req.on('end', () => {
        try {
          const data = JSON.parse(body);
          cachedEntries = data.entries || [];
          broadcastToRemotes({ type: 'entries', data: cachedEntries });
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: true }));
        } catch (e) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Invalid JSON' }));
        }
      });
      return;
    }

    // ✅ 4. Confirm working folder and file mapping
    let filePath = path.join(OUTPUT_DIR, safePath);
    if (safePath === '/' || safePath === '') {
      filePath = path.join(OUTPUT_DIR, 'index.html');
    } else if (!path.extname(filePath)) {
      filePath = path.join(OUTPUT_DIR, safePath, 'index.html');
    }

    fs.readFile(filePath)
      .then((data) => {
        const ext = path.extname(filePath).toLowerCase();
        // ✅ 3. Ensure MIME types include JSON and ICO
        const types = {
          '.html': 'text/html',
          '.css': 'text/css',
          '.js': 'text/javascript',
          '.png': 'image/png',
          '.jpg': 'image/jpeg',
          '.jpeg': 'image/jpeg',
          '.svg': 'image/svg+xml',
          '.gif': 'image/gif',
          '.webp': 'image/webp',
          '.mp3': 'audio/mpeg',
          '.mp4': 'video/mp4',
          '.ico': 'image/x-icon',
          '.json': 'application/json',
          '.woff2': 'font/woff2',
          '.woff': 'font/woff',
          '.ttf': 'font/ttf',
          '.eot': 'application/vnd.ms-fontobject',
          '.otf': 'font/otf'
        };
        let body = data;
        if (ext === '.html' || ext === '.js' || ext === '.css') {
          let text = data.toString('utf8');
          // Localize Google Fonts to a bundled CSS
          text = text.replace(/https?:\/\/fonts\.googleapis\.com[^"'>)\s]*/g, '/assets/fonts/googlefonts.css');
          // Replace Google Tag Manager script with local stub
          text = text.replace(/https?:\/\/www\.googletagmanager\.com\/gtag\/js[^"'>)\s]*/g, '/offline/gtag-stub.js');
          if (ext === '.html') {
            // FIX: Remove Content-Security-Policy meta tags that may block injected scripts
            text = text.replace(/<meta[^>]*http-equiv\s*=\s*["']?Content-Security-Policy["']?[^>]*>/gi, '<!-- CSP removed for offline mode -->');
            
            const inject = "<script>!function(){try{const o=Element.prototype.setAttribute;Element.prototype.setAttribute=function(n,v){try{if(n==='href'&&typeof v==='string'&&v.includes('fonts.googleapis.com')){v='/assets/fonts/googlefonts.css'}if(n==='src'&&typeof v==='string'&&v.includes('www.googletagmanager.com/gtag/js')){v='/offline/gtag-stub.js'}}catch(e){}return o.call(this,n,v)};const a=Element.prototype.appendChild;Element.prototype.appendChild=function(node){try{if(node&&node.tagName==='LINK'){const h=node.getAttribute('href')||'';if(h.includes('fonts.googleapis.com')){node.setAttribute('href','/assets/fonts/googlefonts.css')}}if(node&&node.tagName==='SCRIPT'){const s=node.getAttribute('src')||'';if(s&&s.includes('www.googletagmanager.com/gtag/js')){node.setAttribute('src','/offline/gtag-stub.js')}}}catch(e){}return a.call(this,node)};var of=window.fetch;window.fetch=function(r,opts){try{var u=typeof r==='string'?r:r&&r.url;if(u&&u.indexOf('/api/v2/client-settings')!==-1){return Promise.resolve(new Response(JSON.stringify({ads:{enabled:false},features:{},version:1}),{status:200,headers:{'Content-Type':'application/json'}}))}}catch(e){}return of.apply(this,arguments)};window.gtag=window.gtag||function(){}}catch(e){}}();</script>";
            const inject2 = "<script>(function(){const BRAND='wheelofnames.com';let buildLabel='f93a / f93a';let observer=null;function updateBuildLabel(){try{const node=document.querySelector('.build');if(node&&node.textContent&&node.textContent.trim()){buildLabel=node.textContent.trim();}}catch(e){}}function fix(){try{updateBuildLabel();document.querySelectorAll('.q-toolbar__title h1, .q-toolbar__title').forEach(function(node){if(node.textContent!==BRAND){node.textContent=BRAND;}});document.querySelectorAll('.build').forEach(function(node){if(node.textContent!==buildLabel){node.textContent=buildLabel;}});}catch(e){}}function ensureObserver(){try{const target=document.querySelector('header')||document.body;if(!target)return;if(observer&&observer.__wonTarget===target)return;if(observer){observer.disconnect();}observer=new MutationObserver(function(){schedule();});observer.__wonTarget=target;observer.observe(target,{childList:true,subtree:true});}catch(e){}}function schedule(){fix();ensureObserver();setTimeout(function(){fix();ensureObserver();},150);setTimeout(function(){fix();ensureObserver();},500);setTimeout(function(){fix();ensureObserver();},1200);}function hookHistory(){['pushState','replaceState'].forEach(function(method){try{const original=history[method];if(!original)return;history[method]=function(){const result=original.apply(this,arguments);schedule();return result;};}catch(e){}});window.addEventListener('popstate',schedule);window.addEventListener('hashchange',schedule);}function init(){schedule();hookHistory();}if(document.readyState==='loading'){document.addEventListener('DOMContentLoaded',init);}else{init();}})();</script>";
            const inject3 = "<script type=\"module\" src=\"/won-expose-engine.js\"></script><script type=\"module\" src=\"/won-spin.js\"></script>";
            if (text.indexOf('</head>') !== -1) {
              text = text.replace('</head>', inject + inject2 + inject3 + '</head>');
            } else {
              text = inject + inject2 + inject3 + text;
            }
          }
          body = Buffer.from(text, 'utf8');
        }
        res.writeHead(200, { 'Content-Type': types[ext] || 'application/octet-stream' });
        res.end(body);
      })
      .catch(() => {
        res.writeHead(404);
        res.end('404 Not Found');
      });
  });
  server.on('error', (err) => {
    if (err && err.code === 'EADDRINUSE') {
      console.error(`Port ${currentPort} is already in use. Please stop the other process or change the PORT environment variable.`);
      process.exit(1);
      return;
    }
    console.error('Server error:', err);
    process.exit(1);
  });

  server.listen(currentPort, () => {
    const addr = server.address();
    const boundPort = addr && typeof addr === 'object' ? addr.port : currentPort;
    const localIP = getLocalIP();
    const remoteUrl = `http://${localIP}:${boundPort}/remote`;
    
    console.log(`\n🌐 Local server running → http://localhost:${boundPort}`);
    console.log(`📱 Remote control → ${remoteUrl}`);
    
    // Start DNS server if custom hostname is set
    const hostname = process.env.HOSTNAME || process.env.CUSTOM_HOST;
    if (hostname && hostname !== 'localhost') {
      startDnsServer(hostname, localIP);
    }
    
    // Display QR code for remote control
    if (qrcode) {
      console.log(`\n📱 Scan this QR code with your phone:\n`);
      qrcode.generate(remoteUrl, { small: true });
      console.log(`\n   (Or type the URL manually on your phone)`);
    } else {
      console.log(`   (Open this URL on your phone to control the wheel)`);
    }
  });
  
  serverInstance = server;
  
  // Setup WebSocket server for remote control
  wss = new WebSocket.Server({ server });
  
  wss.on('connection', (ws) => {
    console.log('[WS] New client connected');
    
    ws.on('message', (message) => {
      try {
        const msg = JSON.parse(message.toString());
        
        // Client registering as display or remote
        if (msg.type === 'register') {
          if (msg.role === 'display') {
            wsClients.displays.add(ws);
            console.log('[WS] Display client registered');
          } else if (msg.role === 'remote') {
            wsClients.remotes.add(ws);
            console.log('[WS] Remote client registered');
            // Send current entries to new remote
            if (cachedEntries.length > 0) {
              ws.send(JSON.stringify({ type: 'entries', data: cachedEntries }));
            }
          }
        }
        
        // Display sending entries update
        if (msg.type === 'entries_update') {
          cachedEntries = msg.data || [];
          broadcastToRemotes({ type: 'entries', data: cachedEntries });
        }
        
        // Remote setting winner
        if (msg.type === 'set_winner' && typeof msg.index === 'number') {
          console.log(`[WS] Remote set winner: index ${msg.index}`);
          broadcastToDisplays({ type: 'set_winner', index: msg.index });
          // Confirm to remote
          ws.send(JSON.stringify({ type: 'winner_set', index: msg.index }));
        }
        
        // Display confirming winner after spin
        if (msg.type === 'winner_confirmed' && msg.name) {
          console.log(`[WS] Winner confirmed: ${msg.name}`);
          broadcastToRemotes({ type: 'winner_confirmed', name: msg.name });
        }
      } catch (e) {
        console.error('[WS] Message parse error:', e.message);
      }
    });
    
    ws.on('close', () => {
      wsClients.displays.delete(ws);
      wsClients.remotes.delete(ws);
      console.log('[WS] Client disconnected');
    });
  });
  
  // FIX: Add graceful shutdown handler
  function gracefulShutdown(signal) {
    console.log(`\n🛑 Received ${signal}. Shutting down gracefully...`);
    if (serverInstance) {
      serverInstance.close(() => {
        console.log('✅ Server closed.');
        process.exit(0);
      });
      // Force exit after 5 seconds if server doesn't close
      setTimeout(() => {
        console.log('⚠️ Forcing exit after timeout.');
        process.exit(1);
      }, 5000);
    } else {
      process.exit(0);
    }
  }
  
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));
  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
}

// ────────────────────────────────
// Helpers
// ────────────────────────────────

async function findOpenPort(start, maxSteps = 10) {
  async function isPortFree(port) {
    return new Promise((resolve) => {
      const tester = net
        .createServer()
        .once('error', () => resolve(false))
        .once('listening', () => tester.close(() => resolve(true)))
        .listen(port, '0.0.0.0');
    });
  }
  for (let i = 0; i <= maxSteps; i++) {
    const p = start + i;
    // eslint-disable-next-line no-await-in-loop
    if (await isPortFree(p)) return p;
  }
  // Fallback to ephemeral port
  return 0;
}

// =======================================================================
// ▼▼▼ NEW: Hyperlink Discovery Function ▼▼▼
// =======================================================================
async function getInternalLinks(page, baseUrl) {
  const base = new URL(baseUrl);
  const links = await page.$$eval('a[href]', as =>
    as.map(a => a.getAttribute('href')).filter(Boolean)
  );
  const clean = links
    .map(href => {
      try {
        const u = new URL(href, base);
        u.hash = '';
        return u.href;
      } catch {
        return null;
      }
    })
    .filter(Boolean)
    // Exclude mailto, tel, etc. and links to other domains
    .filter(url => new URL(url).protocol.startsWith('http') && new URL(url).hostname === base.hostname);
  return [...new Set(clean)];
}

function urlToFilePath(url, outputDir) {
  const parsedUrl = new URL(url);
  let urlPath = parsedUrl.pathname;

  if (urlPath.endsWith('/')) {
    urlPath += 'index.html';
  } else if (!path.extname(urlPath)) {
    urlPath += '/index.html';
  }
  
  if (urlPath.startsWith('/')) {
    urlPath = urlPath.slice(1);
  }

  return path.join(outputDir, urlPath);
}

async function downloadBuffer(url, maxRedirects = 5) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const lib = u.protocol === 'https:' ? https : http;
    const req = lib.request({
      hostname: u.hostname,
      path: u.pathname + (u.search || ''),
      method: 'GET',
      port: u.port || (u.protocol === 'https:' ? 443 : 80),
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'Accept': '*/*',
        'Referer': TARGET_URL
      }
    }, (res) => {
      if ([301,302,303,307,308].includes(res.statusCode) && res.headers.location) {
        if (maxRedirects <= 0) return reject(new Error('Too many redirects'));
        const next = new URL(res.headers.location, u).href;
        res.resume();
        downloadBuffer(next, maxRedirects - 1).then(resolve).catch(reject);
        return;
      }
      if (res.statusCode !== 200) {
        res.resume();
        return reject(new Error(`HTTP ${res.statusCode}`));
      }
      const chunks = [];
      res.on('data', (d) => chunks.push(d));
      res.on('end', () => resolve(Buffer.concat(chunks)));
    });
    req.on('error', reject);
    req.end();
  });
}

// Mirror Google Fonts locally by reading the Google Fonts CSS reference from index.html,
// downloading that CSS and all referenced font files, and writing them under assets/fonts.
async function mirrorGoogleFontsFromHtml() {
  try {
    const htmlPath = path.join(OUTPUT_DIR, 'index.html');
    if (!await fs.pathExists(htmlPath)) return;
    const html = await fs.readFile(htmlPath, 'utf8');
    const m = html.match(/https?:\/\/fonts\.googleapis\.com[^"'>)\s]*/i);
    if (!m) return;
    const cssUrl = m[0];

    const cssBuf = await downloadBuffer(cssUrl);
    let cssText = cssBuf.toString('utf8');
    const outDir = path.join(OUTPUT_DIR, 'assets', 'fonts');
    await fs.ensureDir(outDir);

    const seen = new Set();
    const urlRe = /url\(["']?(.*?\.(?:woff2|woff|ttf|otf|eot))["']?\)/ig;
    let match;
    while ((match = urlRe.exec(cssText)) !== null) {
      try {
        const abs = new URL(match[1], cssUrl).href;
        if (seen.has(abs)) continue;
        seen.add(abs);
        const fontBuf = await downloadBuffer(abs);
        const base = path.basename(new URL(abs).pathname);
        await fs.writeFile(path.join(outDir, base), fontBuf);
        const localRef = `/assets/fonts/${base}`;
        const escaped = match[1].replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        cssText = cssText.replace(new RegExp(escaped, 'g'), localRef);
      } catch {}
    }

    await fs.writeFile(path.join(outDir, 'googlefonts.css'), cssText, 'utf8');
  } catch {}
}
// ... other helpers remain the same ...
function categorizeAsset(urlPath) {
  const ext = path.extname(urlPath).toLowerCase();
  if (ext.endsWith('.css')) return 'assets/css';
  if (ext.endsWith('.js')) return 'assets/js';
  if ([
    '.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico', '.webp'
  ].includes(ext))
    return 'assets/img';
  if ([
    '.mp3', '.wav', '.ogg', '.m4a', '.aac'
  ].includes(ext))
    return 'assets/audio';
  if ([
    '.mp4', '.webm', '.mov', '.avi', '.mkv'
  ].includes(ext))
    return 'assets/video';
  if ([
    '.woff2', '.woff', '.ttf', '.eot', '.otf'
  ].includes(ext))
    return 'assets/fonts';
  return 'assets/misc';
}

function extractCssUrls(cssText) {
  const regex = /url\(["']?(.*?)["']?\)/g;
  const urls = [];
  let match;
  while ((match = regex.exec(cssText)) !== null) {
    const u = match[1];
    if (u && !u.startsWith('data:') && !u.startsWith('blob:')) urls.push(u);
  }
  return urls;
}

function rewriteCssUrls(cssText, baseUrl) {
  const regex = /url\(["']?(.*?)["']?\)/g;
  return cssText.replace(regex, (match, rawUrl) => {
    try {
      if (rawUrl.startsWith('data:') || rawUrl.startsWith('blob:')) return match;
      const abs = new URL(rawUrl, baseUrl).href;
      const fileName = path.basename(new URL(abs).pathname);
      const categoryDir = categorizeAsset(fileName);
      const relPath = path
        .relative('assets/css', `${categoryDir}/${fileName}`)
        .replace(/\\/g, '/');
      return `url("${relPath}")`;
    } catch {
      return match;
    }
  });
}

function addToManifest(manifest, categoryDir, filePath, sizeKB) {
  const type = path.basename(categoryDir);
  if (!manifest.assets[type]) manifest.assets[type] = [];
  manifest.assets[type].push({
    path: `${categoryDir}/${path.basename(filePath)}`,
    size_kb: sizeKB,
    category: type,
  });
}

// ────────────────────────────────
// Clone Function
// ────────────────────────────────
async function cloneSite() {
  console.log('🚀 Launching Puppeteer...');
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] });
  const page = await browser.newPage();
  await fs.ensureDir(OUTPUT_DIR);

  const baseHost = new URL(TARGET_URL).hostname;
  const assetUrls = new Set();
  const urlsToVisit = [TARGET_URL];
  const visitedUrls = new Set();

  const manifest = { site: TARGET_URL, generated_at: new Date().toISOString(), assets: {}, summary: {} };

  await page.setRequestInterception(true);
  page.on('request', (req) => {
    const url = new URL(req.url());
    if (url.hostname !== baseHost || ['xhr', 'fetch'].includes(req.resourceType())) {
      req.abort();
    } else {
      if (['stylesheet', 'image', 'script', 'media', 'font'].includes(req.resourceType())) {
        assetUrls.add(req.url());
      }
      req.continue();
    }
  });

  page.on('response', async (res) => {
    try {
      const url = res.url();
      if (new URL(url).hostname !== baseHost) return;
      const ct = res.headers()['content-type'] || '';
      if (/(javascript|css|image|audio|video|font|woff|ttf|eot|otf)/i.test(ct)) {
        assetUrls.add(url);
      }
    } catch {}
  });

  // =======================================================================
  // ▼▼▼ REFACTORED: Main Crawling Loop ▼▼▼
  // =======================================================================
  while (urlsToVisit.length > 0) {
    const currentUrl = urlsToVisit.shift();
    if (visitedUrls.has(currentUrl)) {
      continue;
    }
    visitedUrls.add(currentUrl);

    console.log(`\n🔎 Processing page: ${currentUrl}`);
    try {
      // 🔧 2. Add the safe-URL guard before each page.goto()
      if (!currentUrl || !/^https?:\/\//i.test(currentUrl)) {
        console.warn(`⚠️ Skipping invalid page URL: ${currentUrl}`);
        continue;
      }
      await page.goto(currentUrl, { waitUntil: 'networkidle0', timeout: 90000 });
      // 🔧 1. Replace every page.waitForTimeout(...)
      await new Promise(resolve => setTimeout(resolve, 5000));

      console.log('📜 Scrolling to trigger lazy-loaded assets...');
      await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
      // 🔧 1. Replace every page.waitForTimeout(...)
      await new Promise(resolve => setTimeout(resolve, 5000));

      console.log('🔁 Forcing scripts to preload resources...');
      await page.evaluate(async () => {
        for (const s of Array.from(document.scripts)) {
          if (s.src) try { await fetch(s.src); } catch {}
        }
      });
      // 🔧 1. Replace every page.waitForTimeout(...)
      await new Promise(resolve => setTimeout(resolve, 5000));

      // Try to trigger a wheel spin to capture audio assets
      console.log('🔊 Triggering spin to capture audio assets...');
      try {
        await page.keyboard.down('Control');
        await page.keyboard.press('Enter');
        await page.keyboard.up('Control');
        await new Promise(resolve => setTimeout(resolve, 3000));
      } catch {}

      // Rewrite links to be root-relative
      await page.evaluate(() => {
        document.querySelectorAll('[src], [href]').forEach((el) => {
          const attr = el.hasAttribute('src') ? 'src' : 'href';
          const val = el.getAttribute(attr);
          if (val && !val.startsWith('data:') && !val.startsWith('blob:')) {
            try {
              const absUrl = new URL(val, document.baseURI);
              if (absUrl.hostname === new URL(document.baseURI).hostname) {
                el.setAttribute(attr, absUrl.pathname + absUrl.search + absUrl.hash);
              }
            } catch {}
          }
        });
      });

      // Save HTML for the current page
      let html = await page.content();
      const htmlPath = urlToFilePath(currentUrl, OUTPUT_DIR);
      await fs.ensureDir(path.dirname(htmlPath));
      await fs.writeFile(htmlPath, html);
      console.log(`💾 Saved HTML: ${path.relative(OUTPUT_DIR, htmlPath)}`);

      // Discover new internal links and add them to the queue
      const internalLinks = await getInternalLinks(page, TARGET_URL);
      for (const link of internalLinks) {
        if (!visitedUrls.has(link)) {
          urlsToVisit.push(link);
        }
      }
    } catch (e) {
      console.warn(`⚠️ Failed to process ${currentUrl}: ${e.message}`);
    }
  }

  // Mirror Google Fonts locally (CSS + font files)
  await mirrorGoogleFontsFromHtml();

  // Expand asset list by parsing CSS and JS for referenced resources (fonts, audio, images)
  try {
    console.log('\n🔎 Expanding asset list from CSS/JS references...');
    const initialAssets = Array.from(assetUrls);
    for (const asset of initialAssets) {
      try {
        const u = new URL(asset);
        if (u.hostname !== baseHost) continue;
        if (/\.css($|\?)/i.test(u.pathname)) {
          const cssBuf = await downloadBuffer(asset);
          const cssText = cssBuf.toString('utf8');
          // capture url(...) entries
          const urls = extractCssUrls(cssText);
          for (const rel of urls) {
            try {
              const abs = new URL(rel, asset).href;
              if (new URL(abs).hostname === baseHost) assetUrls.add(abs);
            } catch {}
          }
        } else if (/\.js($|\?)/i.test(u.pathname)) {
          const jsBuf = await downloadBuffer(asset);
          const js = jsBuf.toString('utf8');
          const re = /['"]([^'"\)]+\.(?:mp3|ogg|wav|woff2?|ttf|otf|eot|png|jpg|jpeg|gif|svg|webp))['"]/ig;
          let m;
          while ((m = re.exec(js)) !== null) {
            try {
              const abs = new URL(m[1], asset).href;
              if (new URL(abs).hostname === baseHost) assetUrls.add(abs);
            } catch {}
          }
        }
      } catch {}
    }
  } catch {}

  console.log(`\nDownloading ${assetUrls.size} unique assets...`);
  let successCount = 0, failCount = 0;
  // ... Asset downloading logic remains largely the same but outside the loop ...
  for (const url of assetUrls) {
     try {
      if (!url.startsWith('http')) continue;
      
      // 🔧 2. Add the safe-URL guard before each page.goto()
      if (!url || !/^https?:\/\//i.test(url)) {
        console.warn(`⚠️ Skipping invalid asset URL: ${url}`);
        continue;
      }
      const buffer = await downloadBuffer(url);
      
      let urlPath = new URL(url).pathname;
      if (urlPath.startsWith('/')) urlPath = urlPath.slice(1);
      
      const filePath = path.join(OUTPUT_DIR, urlPath);
      await fs.ensureDir(path.dirname(filePath));
      const categoryDir = path.dirname(urlPath);
      
      await fs.writeFile(filePath, buffer);
      
      const sizeKB = buffer.length / 1024;
      addToManifest(manifest, categoryDir, filePath, sizeKB);
      successCount++;
      console.log(`✔ Saved: ${urlPath}`);
    } catch (e) {
      console.warn(`⚠️ Skipped asset: ${url} (${e.message})`);
      failCount++;
    }
  }

  manifest.summary = { total_downloaded: successCount, total_skipped: failCount, total_size_kb: Object.values(manifest.assets).flat().reduce((sum, f) => sum + (f.size_kb || 0), 0).toFixed(2) };
  await fs.writeJSON(path.join(OUTPUT_DIR, 'manifest.json'), manifest, { spaces: 2 });
  await browser.close();

  console.log(`\n✅ Clone complete!`);
  console.log(`💾 ${visitedUrls.size} pages and ${successCount} assets saved, ${failCount} assets skipped.`);
  console.log(`📁 Offline copy: ${OUTPUT_DIR}`);
  console.log(`🌍 Run "node clone.js serve" to preview locally.`);
}

// ────────────────────────────────
// CLI Entrypoint
// ────────────────────────────────
const arg = process.argv[2];
if (arg === 'serve') {
  startServer();
} else {
  cloneSite().catch((err) => console.error('❌ Error:', err));
}
