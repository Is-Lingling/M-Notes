const { webkit } = require('playwright');
const assert = require('node:assert/strict');
const { pathToFileURL } = require('node:url');
const path = require('node:path');
(async () => {
  const browser = await webkit.launch();
  const page = await browser.newPage({ viewport: { width: 900, height: 900 } });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(pathToFileURL(path.resolve(__dirname, '../../MarkdownNotes/Editor/editor.html')).href);
  await page.waitForFunction(() => window.editor?._view);
  const load = async text => {
    await page.evaluate(text => { editor.setContent(text); editor.gotoLine(1); }, text);
  };
  await load('Start\n\n```javascript\nconst n = 1;\n```\n\n- [ ] Task label\n\n---\n\nEnd\n\n![missing](not-found.png)');
  const header = await page.locator('.cm-code-block-header-line').boundingBox();
  assert(header.height <= 32, `header too tall: ${header.height}`);
  const circle = page.locator('.cm-task-circle');
  const before = await circle.boundingBox();
  await circle.click();
  assert.equal(await circle.getAttribute('aria-checked'), 'true');
  const after = await circle.boundingBox();
  assert(Math.abs(before.y - after.y) < 1, `checkbox shifted ${after.y - before.y}px`);
  const rule = page.locator('.cm-hr-line');
  const ruleBefore = await rule.boundingBox();
  await rule.click();
  await page.locator('.cm-hr-source-line').waitFor();
  const selected = await page.evaluate(() => editor._view.state.doc.lineAt(editor._view.state.selection.main.head).text);
  assert.equal(selected, '---');
  const ruleAfter = await page.locator('.cm-hr-source-line').boundingBox();
  assert(Math.abs(ruleAfter.height - ruleBefore.height) < 1, 'rule changes height');
  assert.notEqual(await page.locator('.cm-hr-source-line').evaluate(el => getComputedStyle(el).color), 'rgba(0, 0, 0, 0)');
  await page.locator('.cm-image-placeholder').waitFor();
  await page.locator('.cm-image-placeholder').click();
  await page.locator('.cm-image-path').waitFor({ state: 'visible' });
  await page.locator('.cm-image-path').press('Escape');
  await page.evaluate(() => { editor.setLanguage('en'); editor.setContent('```js\nconst x = 1;\n```\n\n![missing](not-found.png)\n\n| A | B |\n| --- | --- |\n| 1 | 2 |'); });
  await page.locator('.cm-image-placeholder').waitFor();
  assert.equal(await page.locator('.cm-code-copy-btn').innerText(), 'Copy');
  assert.equal(await page.locator('.cm-image-placeholder strong').innerText(), 'Image unavailable');
  assert.equal(await page.locator('[data-action="addRow"]').innerText(), '+ Row');
  await page.evaluate(() => editor.setLanguage('zh-Hans'));
  await page.evaluate(() => editor.setPreferences({ fontSize: 21, lineHeight: 2.1, maxWidth: 620, showLineNumbers: true, spellCheck: false, smartQuotes: true, smartDashes: true }));
  assert.equal(await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--font-size').trim()), '21px');
  assert.equal(await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--line-height').trim()), '2.1');
  assert.equal(await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--max-width').trim()), '620px');
  assert.equal(await page.locator('.cm-content').getAttribute('spellcheck'), 'false');
  await load('');
  await page.locator('.cm-content').click();
  await page.keyboard.type('"hello" --');
  assert.equal(await page.evaluate(() => editor.getContent()), '“hello” —');
  await page.evaluate(() => editor.setPreferences({ fontSize: 16, lineHeight: 1.75, maxWidth: 740, showLineNumbers: false, spellCheck: true, smartQuotes: false, smartDashes: false }));
  await load('Intro\n\n| Name | Value |\n| :--- | ---: |\n| **bold** | 10 |\n| other | 20 |\n\nAfter table');
  const table = page.locator('.cm-live-table');
  await table.waitFor();
  assert.equal(await table.locator('tr').count(), 3);
  assert.equal(await table.locator('strong').innerText(), 'bold');
  const beforeSelection = await table.boundingBox();
  await table.locator('.cm-table-hint').click();
  await page.waitForTimeout(100);
  assert.equal(await page.locator('.cm-table-block-selection').count(), 1);
  const tableFrame = await table.evaluate(element => {
    const frame = getComputedStyle(element, '::after');
    return {
      width: parseFloat(frame.width), height: parseFloat(frame.height),
      expectedWidth: element.clientWidth, expectedHeight: element.clientHeight,
      pointerEvents: frame.pointerEvents, zIndex: Number(frame.zIndex),
      outside: [...document.querySelectorAll('.cm-selectionBackground')].every(layer => getComputedStyle(layer).backgroundColor === 'rgba(0, 0, 0, 0)'),
    };
  });
  assert(Math.abs(tableFrame.width - tableFrame.expectedWidth) < 1);
  assert(Math.abs(tableFrame.height - tableFrame.expectedHeight) < 1);
  assert.equal(tableFrame.pointerEvents, 'none');
  assert(tableFrame.zIndex > 0 && tableFrame.outside);
  assert.deepEqual(await table.boundingBox(), beforeSelection);
  await page.screenshot({ path: '/tmp/mnotes-table-selection.png' });
  await table.locator('td').first().click();
  assert.equal(await page.locator('.cm-table-block-selection').count(), 0);
  const firstCell = table.locator('input[data-row="1"][data-col="0"]');
  await firstCell.focus();
  await firstCell.fill('changed | escaped');
  assert((await page.evaluate(() => editor.getContent())).includes('changed \\| escaped'));
  await table.locator('[data-action="addRow"]').click();
  assert.equal(await table.locator('tr').count(), 4);
  await page.waitForFunction(() => document.activeElement?.dataset.row === '2');
  await table.locator('[data-action="addColumn"]').click();
  assert.equal(await table.locator('tr').first().locator('th').count(), 3);
  await page.waitForFunction(() => document.activeElement?.dataset.col === '1');
  await table.locator('[data-action="removeColumn"]').click();
  assert.equal(await table.locator('tr').first().locator('th').count(), 2);
  await page.waitForFunction(() => document.activeElement?.dataset.row === '2');
  await table.locator('[data-action="removeRow"]').click();
  assert.equal(await table.locator('tr').count(), 3);
  await page.waitForFunction(() => document.activeElement?.dataset.row === '2');
  await page.keyboard.press('Meta+Alt+ArrowDown');
  assert.equal(await table.locator('tr').count(), 4);
  await page.waitForFunction(() => document.activeElement?.dataset.row === '3');
  await page.keyboard.press('Meta+z');
  assert.equal(await table.locator('tr').count(), 3);
  await page.waitForFunction(() => document.activeElement?.dataset.row === '2');
  await page.keyboard.press('Meta+Shift+z');
  assert.equal(await table.locator('tr').count(), 4);
  await table.locator('input[data-row="3"][data-col="1"]').focus();
  await page.keyboard.press('Tab');
  assert.equal(await table.locator('tr').count(), 5);
  await page.evaluate(() => editor.setSourceMode(true));
  assert.equal(await table.count(), 0);
  assert((await page.locator('.cm-content').innerText()).includes('changed \\| escaped'));
  await page.evaluate(() => editor.setSourceMode(false));
  await table.waitFor();
  const afterText = page.locator('.cm-line').filter({ hasText: 'After table' });
  await afterText.click();
  assert.equal(await page.evaluate(() => editor._view.state.doc.lineAt(editor._view.state.selection.main.head).text), 'After table');
  await load('Intro\n\n| A | B |\n| --- | --- |\n| one |\n\nEnd');
  const absentCell = page.locator('.cm-live-table input[data-row="1"][data-col="1"]');
  await absentCell.focus();
  await absentCell.fill('new value');
  assert((await page.evaluate(() => editor.getContent())).includes('| one | new value |'));
  await page.setViewportSize({ width: 480, height: 800 });
  await page.evaluate(() => editor.setContent('Intro\n\n| A | B | C | D | E |\n| --- | --- | --- | --- | --- |\n| 1 | 2 | 3 | 4 | 5 |'));
  assert(await page.locator('.cm-table-scroll').evaluate(el => el.scrollWidth > el.clientWidth));
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.screenshot({ path: '/tmp/typora-table-dark.png', fullPage: true });

  // Test instant built-in theme switching
  await page.evaluate(() => editor.setTheme('dracula'));
  assert.equal(await page.evaluate(() => document.body.dataset.theme), 'dracula');
  assert.equal(await page.evaluate(() => getComputedStyle(document.body).getPropertyValue('--accent').trim()), '#bd93f9');

  await page.evaluate(() => editor.setTheme('liquid-glass-dark'));
  assert.equal(await page.evaluate(() => document.body.dataset.theme), 'liquid-glass-dark');
  assert.equal(await page.evaluate(() => getComputedStyle(document.body).getPropertyValue('--accent').trim()), '#38bdf8');

  await page.evaluate(() => editor.setTheme('liquid-glass-light'));
  assert.equal(await page.evaluate(() => document.body.dataset.theme), 'liquid-glass-light');
  assert.equal(await page.evaluate(() => getComputedStyle(document.body).getPropertyValue('--accent').trim()), '#0077ff');

  await page.evaluate(() => editor.setTheme('system'));
  assert.equal(await page.evaluate(() => Boolean(document.body.dataset.theme)), false);

  assert.deepEqual(errors, []);
  console.log('PASS: compact header, stable checkbox, editable rule, missing-image card, live tables, row/column actions, shortcuts, undo/redo, Tab, source mode, and instant theme switching');
  await browser.close();
})().catch(error => { console.error(error); process.exit(1); });
