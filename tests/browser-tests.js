// Playwright behavioural suite. Every browser case loads the Nim-generated example
// artifact, then interacts only through its rendered page.

const fs = require('fs');
const path = require('path');
const { assert, openBrowserTier } = require('./browser-runner');

const buildRoot = process.env.NTML_TEST_OUT || '/tmp/ntml-tests';
const sourceExamples = process.env.NTML_EXAMPLE_SRC || path.join(__dirname, '..', 'examples');
const cases = [];
const test = (name, fn) => cases.push({ name, fn });
const text = page => page.locator('body').innerText();
const button = (page, name) => page.getByRole('button', { name, exact: true });

async function example(tier, name, fn, route = '/') {
  const page = await tier.loadExample(name, route);
  try { await fn(page); } finally { await page.close(); }
}

test('smoke discovers and loads every compiled example artifact', async tier => {
  const names = fs.readdirSync(sourceExamples).filter(file => file.endsWith('.nim')).map(file => path.basename(file, '.nim')).sort();
  assert(names.length > 0, 'no examples discovered from examples/*.nim');
  for (const name of names) {
    console.log(`  smoke loading: ${name}`);
    await example(tier, name, async page => {
      assert(await page.locator('body *').count() > 0, `${name} rendered no elements`);
    });
  }
  console.log(`  discovered/exercised examples: ${names.length} (${names.join(', ')})`);
});

test('signals, conditionals, and for updates react to genuine clicks/checks', async tier => {
  await example(tier, 'signals', async page => {
    assert((await text(page)).includes('Count: 0'));
    await button(page, 'Increment').click();
    assert((await text(page)).includes('Count: 1') && (await text(page)).includes('Doubled: 2'));
    const box = page.locator('input[type=checkbox]');
    const before = await box.isChecked(); await box.setChecked(!before); assert(await box.isChecked() === !before);
  });
  await example(tier, 'ifStatements', async page => {
    await button(page, 'Increment count').click(); assert((await text(page)).includes('Count: 1'));
    await button(page, 'Turn light off').click(); assert((await text(page)).includes('Light is off'));
  });
  await example(tier, 'forStatements', async page => {
    const before = await page.locator('#symbols').innerText(); await button(page, 'Cycle list order').click();
    assert(await page.locator('#symbols').innerText() !== before, 'for loop did not update');
  });
});

test('keyed reconciliation preserves identity and a reused node listener', async tier => {
  await example(tier, 'keyedDiffs', async page => {
    const rows = page.locator('#keyed-diffs li'); const before = await rows.count();
    await button(page, 'Add').click(); assert(await rows.count() === before + 1);
    await button(page, 'Remove First').click(); assert(await rows.count() === before);
    const first = await rows.nth(0).elementHandle();
    await button(page, 'Swap First Two').click();
    assert(await page.evaluate(node => document.querySelectorAll('#keyed-diffs li')[1] === node, first), 'keyed node was remounted');
    await rows.nth(1).getByRole('button', { name: 'To Front', exact: true }).click();
    assert(await page.evaluate(node => document.querySelectorAll('#keyed-diffs li')[0] === node, first), 'reused keyed node lost its click listener');
  });
});

test('todo and form bindings use browser input and submit flows', async tier => {
  await example(tier, 'todos', async page => {
    const items = page.locator('#todo-list li'); const before = await items.count();
    await page.locator('.todo-input').fill('write tests'); await button(page, 'Add').click();
    assert(await items.count() === before + 1 && (await text(page)).includes('write tests'));
    assert(await page.locator('.todo-input').inputValue() === '', 'signal-to-input reset did not round-trip');
    await button(page, 'Completed').click(); assert(await items.count() <= before + 1);
  });
  await example(tier, 'forms', async page => {
    await page.locator('#username').fill('nope'); await page.locator('#password').fill('wrong'); await button(page, 'Submit').click();
    assert((await text(page)).includes('Incorrect login information'));
    await button(page, 'Clear form').click();
    assert(await page.locator('#username').inputValue() === '' && await page.locator('#password').inputValue() === '', 'form signal-to-input clear did not round-trip');
  });
  await example(tier, 'forms', async page => {
    await page.locator('#username').fill('user123'); await page.locator('#password').fill('pass123'); await button(page, 'Submit').click();
    assert((await text(page)).includes('Logged in!') && !(await text(page)).includes('Incorrect login information'));
  });
});

test('effect, scoped CSS, and overload showcase retain their behavior', async tier => {
  await example(tier, 'effect', async page => { await button(page, 'Increment').click(); assert((await text(page)).includes('Counter value: 1')); });
  await example(tier, 'styled', async page => {
    const heading = page.locator('h1'); const cls = await heading.getAttribute('class'); assert(cls && cls.startsWith('s-'));
    assert(await page.evaluate(className => [...document.styleSheets].some(sheet => [...sheet.cssRules].some(rule => rule.cssText.includes(className))), cls), 'scoped CSS was not injected');
    const hero = button(page, 'Cycle Accent Color'); const before = await hero.getAttribute('style'); await hero.click(); assert(await hero.getAttribute('style') !== before);
  });
  await example(tier, 'overloads', async page => { const before = await text(page); await button(page, 'Cycle values').click(); assert(await text(page) !== before); });
});

test('routing, wildcard routes, and Link navigation update rendered content and URL without reload', async tier => {
  await example(tier, 'router', async page => {
    assert(await page.locator('.page-title').innerText() === 'Home'); await button(page, 'Login').click();
    assert(await page.locator('.page-title').innerText() === 'Login' && new URL(page.url()).pathname === '/login');
  });
  const missing = await tier.newPage();
  try { await missing.goto(`${tier.origin}/missing`); await missing.addScriptTag({ url: `${tier.origin}/examples/router.js` }); assert(await missing.locator('.page-title').innerText() === '404'); }
  finally { await missing.close(); }
  await example(tier, 'routerWildcards', async page => {
    await page.getByRole('link', { name: /User 42/ }).click(); assert((await text(page)).includes('id = 42'));
  });
  await example(tier, 'routerWildcards', async page => { await page.getByRole('link', { name: /Files wildcard/ }).click(); assert((await text(page)).includes('(no params)')); });
  await example(tier, 'links', async page => {
    const a = page.getByRole('link', { name: 'Overview' }); assert(await a.getAttribute('href') === '/links');
    const navigations = await page.evaluate(() => performance.getEntriesByType('navigation').length);
    await page.getByRole('link', { name: 'Router' }).click();
    assert(new URL(page.url()).pathname === '/links/router' && await page.evaluate(() => performance.getEntriesByType('navigation').length) === navigations, 'Link reloaded the document');
  });
});

test('relative navigate() resolves against the path only, never the query string', async tier => {
  const at = route => example(tier, 'relativeNav', async page => {
    const url = () => new URL(page.url());
    await page.locator('#descend').click();
    assert(url().pathname === '/relativeNav/users/1/edit',
      `+/edit from ${route} should descend the path, got ${url().pathname + url().search}`);
    assert(url().search === '', `+/edit should drop the query, got ${url().search}`);
    assert((await page.locator('#path').innerText()) === '/relativeNav/users/1/edit',
      'router.path should track the navigation');
  }, route);
  await at('/relativeNav/users/1');            // no query -- must keep working
  await at('/relativeNav/users/1?tab=a');      // the reported failure
  await at('/relativeNav/users/1#frag');       // hash takes the same path through the fix

  await example(tier, 'relativeNav', async page => {
    await page.locator('#ascend').click();
    const url = new URL(page.url());
    assert(url.pathname === '/relativeNav/users/settings',
      `-/settings should replace the last segment, got ${url.pathname}`);
    assert(url.search === '', `-/settings should drop the query, got ${url.search}`);
  }, '/relativeNav/users/1?tab=a');

  await example(tier, 'relativeNav', async page => {
    await page.locator('#descend-q').click();
    const url = new URL(page.url());
    assert(url.pathname === '/relativeNav/users/1/edit' && url.search === '?mode=raw',
      `explicit query should survive, got ${url.pathname + url.search}`);
  }, '/relativeNav/users/1?tab=a');
});

test('falsey boolean attributes are removed, not written as the string "false"', async tier => {
  await example(tier, 'booleanAttrs', async page => {
    const attr = (sel, name) => page.locator(sel).getAttribute(name);
    for (const [sel, name] of [['#a', 'autofocus'], ['#demo', 'novalidate'],
                               ['#v', 'controls'], ['#v', 'muted']]) {
      assert(await attr(sel, name) === null,
        `${name} on ${sel} should be absent for a falsey value, got ${JSON.stringify(await attr(sel, name))}`);
    }
    for (const [sel, name] of [['#b', 'autofocus'], ['#v', 'loop']]) {
      assert(await attr(sel, name) !== null, `${name} on ${sel} should be present for a truthy value`);
    }
    assert(await page.locator('#a').evaluate(el => el.autofocus) === false, '#a.autofocus property should be false');
    assert(await page.locator('#b').evaluate(el => el.autofocus) === true, '#b.autofocus property should be true');
    assert(await attr('#c', 'required') === null, 'required should start absent');
    await page.locator('#toggle').click();
    assert(await attr('#c', 'required') !== null, 'required should appear when the signal flips true');
    await page.locator('#toggle').click();
    assert(await attr('#c', 'required') === null, 'required should be removed when the signal flips false');
  });
});

test('keyed patching keeps attributes current and rows reactive', async tier => {
  await example(tier, 'keyedAttrs', async page => {
    const attr = (sel, name) => page.locator(sel).getAttribute(name);
    assert(await attr('#row-1', 'data-n') === '0', 'precondition: rows start at 0');

    await page.locator('#bump').click();
    assert(await attr('#row-1', 'data-n') === '1',
      `static attribute should follow the patch, got ${await attr('#row-1', 'data-n')}`);
    assert(await attr('#row-1 span', 'data-inner') === '1',
      `nested attribute should follow the patch, got ${await attr('#row-1 span', 'data-inner')}`);
    assert(await attr('#row-2', 'data-n') === '1', 'every keyed row should patch, not just the first');

    assert(await attr('#row-1', 'data-tone') === 'calm');
    await page.locator('#tone').click();
    assert(await attr('#row-1', 'data-tone') === 'loud',
      `a patched row should stay subscribed to an independent signal, got ${await attr('#row-1', 'data-tone')}`);

    for (let i = 0; i < 6; i++) await page.locator('#bump').click();
    assert(await attr('#row-1', 'data-n') === '7', `expected 7 bumps to land, got ${await attr('#row-1', 'data-n')}`);
    await page.locator('#tone').click();
    assert(await attr('#row-1', 'data-tone') === 'calm', 'row should remain reactive after repeated patches');

    const counts = [];
    for (let i = 0; i < 3; i++) {
      await page.locator('#bump').click();
      counts.push(await page.evaluate(() => document.querySelectorAll('#list [data-n]').length));
    }
    assert(counts.every(c => c === 2), `row count should stay 2 across patches, got ${counts}`);
  });
});

test('combobox, treeview, and focus keyboard interactions run in a real browser', async tier => {
  await example(tier, 'combobox', async page => {
    const cb = page.locator('[role=combobox]'); assert(await cb.count() === 1 && await cb.getAttribute('aria-expanded') === null);
    await cb.fill('a'); assert(await page.locator('[role=listbox]').count() === 1 && await page.locator('[role=option]').count() > 0);
    await cb.press('ArrowDown'); assert(await cb.getAttribute('aria-activedescendant') === 'cb-option-0');
  });
  // Two separate pages on purpose. Clicking a twisty also MOVES SELECTION to that node
  // (the handler sets focusedId then toggles), so doing both on one page makes ArrowDown
  // step from `examples`, not from `src`. Sharing a page here previously produced a false
  // "treeview keyboard is broken in a real browser" report.
  await example(tier, 'treeview', async page => {
    assert(await page.locator('#node-examples').getAttribute('aria-expanded') === 'false');
    await page.locator('#node-examples button').click();
    assert(await page.locator('#node-examples').getAttribute('aria-expanded') === 'true');
    assert(await page.locator('#node-examples').getAttribute('aria-selected') === 'true',
      'clicking a twisty should move selection to that node');
  });
  await example(tier, 'treeview', async page => {
    assert(await page.locator('#node-src').getAttribute('aria-selected') === 'true', 'tree should start on src');
    await page.locator('#filetree').focus();
    await page.locator('#filetree').press('ArrowDown');
    const selected = await page.locator('#node-lib').getAttribute('aria-selected');
    assert(selected === 'true', `ArrowDown should select lib, got aria-selected=${selected}`);
    await page.locator('#filetree').press('ArrowRight');
    assert(await page.locator('#node-lib').getAttribute('aria-expanded') === 'true', 'ArrowRight should expand');
    await page.locator('#filetree').press('ArrowLeft');
    assert(await page.locator('#node-lib').getAttribute('aria-expanded') === 'false', 'ArrowLeft should collapse');
  });
  await example(tier, 'focusKeyboard', async page => {
    assert(await page.evaluate(() => document.activeElement.id) === 'chip-one'); await page.locator('#chip-one').press('ArrowRight');
    assert(await page.evaluate(() => document.activeElement.id) === 'chip-two'); await page.locator('#focus-notes').click();
    assert(await page.evaluate(() => document.activeElement.id) === 'notes' && (await page.locator('#focus-status').innerText()).includes('Notes field'));
  });
});

test('browser listener instrumentation proves binding cleanup', async tier => {
  const page = await tier.newPage();
  try {
    await page.goto(`${tier.origin}/blank.html`);
    await page.addScriptTag({ url: `${tier.origin}/browser_cleanup.js` });
    const detail = await page.evaluate(() => window.__ntmlCleanupProbeError || null);
    assert(await page.evaluate(() => window.__ntmlCleanupProbePassed === true),
      `cleanup probe failed: ${detail || 'probe did not complete (no detail recorded)'}`);
  } finally { await page.close(); }
});

(async () => {
  const tier = await openBrowserTier(buildRoot); let failures = 0;
  try {
    for (const entry of cases) {
      try { await entry.fn(tier); console.log(`PASS  ${entry.name}`); }
      catch (error) { failures += 1; console.error(`FAIL  ${entry.name}\n${error.stack || error}`); }
    }
  } finally { await tier.close(); }
  console.log(`Browser suites: ${cases.length}; failures: ${failures}; browser: ${tier.engine}`);
  if (failures) process.exitCode = 1;
})().catch(error => { console.error(error.stack || error); process.exitCode = 1; });
