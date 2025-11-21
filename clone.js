#!/usr/bin/env node
const puppeteer = require('puppeteer');
const fs = require('fs-extra');
const path = require('path');
const http = require('http');
const https = require('https');
const net = require('net');
const { URL } = require('url');

const TARGET_URL = 'https://wheelofnames.com/';
const OUTPUT_DIR = 'cloned-site-offline';

// ────────────────────────────────
// Local Server for Preview
// ────────────────────────────────
async function startServer() {
  const preferred = process.env.PORT ? Number(process.env.PORT) : 8080;
  const currentPort = preferred;
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
    console.log(`\n🌐 Local server running → http://localhost:${boundPort}`);
  });
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
