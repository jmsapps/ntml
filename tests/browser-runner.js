// Shared real-browser transport for NTML's Playwright tier.
//
// Each example is loaded as the JS artifact produced by `nim js`; browser tests never
// import a second NTML copy. Listener instrumentation is installed before page scripts.

const fs = require('fs');
const http = require('http');
const path = require('path');
const playwright = require('playwright');

// Engine selection. chromium | firefox | webkit -- all three are verified green.
// Override with NTML_BROWSER.
//
// If a browser crashes or refuses to start, suspect the HOST ENVIRONMENT before the
// engine: a Homebrew-style DYLD_LIBRARY_PATH leaks the system's libraries into the
// browser process and breaks it in ways that look like engine or content bugs. See the
// env scrub in openBrowserTier.
const ENGINE = process.env.NTML_BROWSER || 'chromium';

function assert(condition, message) {
  if (!condition) throw new Error(message || 'assertion failed');
}

function createStaticServer(root) {
  const absoluteRoot = path.resolve(root);
  const server = http.createServer((request, response) => {
    const pathname = new URL(request.url, 'http://ntml.test').pathname;
    if (pathname === '/' || pathname === '/blank.html') {
      response.writeHead(200, { 'content-type': 'text/html' });
      response.end('<!doctype html><html><head></head><body></body></html>');
      return;
    }
    const file = path.resolve(absoluteRoot, '.' + pathname);
    if (!file.startsWith(absoluteRoot + path.sep)) {
      response.writeHead(403); response.end(); return;
    }
    fs.readFile(file, (error, data) => {
      if (error && !path.extname(file)) {
        response.writeHead(200, { 'content-type': 'text/html' });
        response.end('<!doctype html><html><head></head><body></body></html>');
        return;
      }
      if (error) { response.writeHead(404); response.end(); return; }
      response.writeHead(200, { 'content-type': file.endsWith('.js') ? 'text/javascript' : 'text/plain' });
      response.end(data);
    });
  });
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

const listenerInstrumentation = () => {
  const originalAdd = EventTarget.prototype.addEventListener;
  const originalRemove = EventTarget.prototype.removeEventListener;
  const entries = new WeakMap();
  let total = 0;

  function record(target, type, handler, delta) {
    let byType = entries.get(target);
    if (!byType) { byType = new Map(); entries.set(target, byType); }
    let handlers = byType.get(type);
    if (!handlers) { handlers = new Set(); byType.set(type, handlers); }
    if (delta > 0 && !handlers.has(handler)) { handlers.add(handler); total += 1; }
    if (delta < 0 && handlers.delete(handler)) total -= 1;
  }

  EventTarget.prototype.addEventListener = function(type, handler, options) {
    record(this, type, handler, 1);
    return originalAdd.call(this, type, handler, options);
  };
  EventTarget.prototype.removeEventListener = function(type, handler, options) {
    record(this, type, handler, -1);
    return originalRemove.call(this, type, handler, options);
  };
  window.__ntmlListenerCount = (target, type) => {
    const handlers = entries.get(target)?.get(type);
    return handlers ? handlers.size : 0;
  };
  window.__ntmlTotalListeners = () => total;
};

async function openBrowserTier(buildRoot) {
  const server = await createStaticServer(buildRoot);
  const address = server.address();
  const origin = `http://127.0.0.1:${address.port}`;
  const engine = playwright[ENGINE];
  if (!engine) {
    await new Promise(resolve => server.close(resolve));
    throw new Error(`unknown NTML_BROWSER=${ENGINE} (expected chromium, firefox or webkit)`);
  }

  // Strip DYLD_* from the browser's environment. A Homebrew-style
  // DYLD_LIBRARY_PATH=/opt/homebrew/lib makes Firefox load the system libnss3 instead of
  // its own bundled copy, and it dies with "Symbol not found: _PR_GMTParameters /
  // Couldn't load XPCOM" before Playwright can attach. Browsers ship their own libraries;
  // they never want the host's override.
  const browserEnv = { ...process.env };
  for (const key of Object.keys(browserEnv)) {
    if (key.startsWith('DYLD_')) delete browserEnv[key];
  }

  // --disable-gpu is a Chromium-only flag; passing it to other engines is rejected.
  const launchOptions = { headless: true, env: browserEnv };
  if (ENGINE === 'chromium') launchOptions.args = ['--disable-gpu'];

  let browser;
  try {
    browser = await engine.launch(launchOptions);
  } catch (error) {
    // Close the static server, or its open handle keeps Node alive and a fast, clear
    // launch failure turns into an indefinite hang.
    await new Promise(resolve => server.close(resolve));
    throw new Error(`failed to launch ${ENGINE}: ${String(error.message || error).split('\n')[0]}`);
  }
  const context = await browser.newContext();

  async function newPage() {
    const page = await context.newPage();
    await page.addInitScript(listenerInstrumentation);
    return page;
  }

  async function loadExample(name, route = '/') {
    // `route` is the URL the page sits at when the bundle executes, which is what the
    // routing examples read on init. Default '/' -- a non-root default would make
    // examples/router.nim render its 404 branch.
    const page = await newPage();
    await page.goto(`${origin}${route}`);
    await page.addScriptTag({ url: `${origin}/examples/${name}.js` });
    return page;
  }

  return {
    origin,
    engine: ENGINE,
    newPage,
    loadExample,
    assert,
    async close() { await context.close(); await browser.close(); await new Promise(resolve => server.close(resolve)); }
  };
}

module.exports = { assert, openBrowserTier };

if (require.main === module) {
  (async () => {
    const tier = await openBrowserTier(process.argv[2] || '/tmp/ntml-tests');
    try {
      const page = await tier.newPage();
      await page.goto(`${tier.origin}/blank.html`);
      assert(await page.evaluate(() => document.body != null), `${tier.engine} did not expose a document body`);
      // Render an emoji deliberately: a host-library leak into the browser shows up as a
      // crash while rasterising one (examples/links.nim contains an emoji), so the bridge
      // check must prove the engine survives content, not merely that it booted.
      await page.setContent('<!doctype html><html><body><span>\u{1F9ED}</span></body></html>');
      await page.waitForTimeout(250);
      assert(await page.evaluate(() => document.body.textContent.length) > 0, `${tier.engine} crashed rendering an emoji glyph`);
      await page.close();
      console.log(`Playwright ${tier.engine} bridge passed`);
    } finally {
      await tier.close();
    }
  })().catch(error => { console.error(error.stack || error); process.exitCode = 1; });
}
