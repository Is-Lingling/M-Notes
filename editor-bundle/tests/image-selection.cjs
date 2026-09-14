const { webkit } = require('playwright');
const assert = require('node:assert/strict');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

(async () => {
  const browser = await webkit.launch();
  try {
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.goto(pathToFileURL(path.resolve(__dirname, '../../shared/editor/editor.html')).href);
    await page.waitForFunction(() => window.editor?._view);
    const src = 'data:image/svg+xml;base64,' + Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60"><rect width="80" height="60" fill="blue"/></svg>').toString('base64');
    for (const syntax of [`![preview](${src})`, `![missing](not-found.png)`, `<img src="${src}" alt="preview" />`]) {
      for (const key of ['Backspace', 'Delete']) {
        const doc = `Before\nleft ${syntax} right\nAfter`;
        await page.evaluate(doc => editor.openDocument(doc, 'image.md'), doc);
        const widget = page.locator('.cm-image-widget');
        await widget.click();
        assert.equal(await page.evaluate(() => { const v = editor._view, s = v.state.selection.main; return v.state.sliceDoc(s.from, s.to); }), syntax);
        assert(await widget.evaluate(el => el.classList.contains('cm-block-selected')));
        assert.equal(await page.locator('.cm-image-path:visible').count(), 1);
        assert(await widget.evaluate(el => {
          const wrapper = getComputedStyle(el), input = getComputedStyle(el.querySelector('input'));
          return wrapper.boxShadow === 'none' && input.borderTopWidth === '0px' && input.outlineStyle === 'none';
        }), 'Selection must not add wrapper or path-input frames');
        await page.keyboard.press(key);
        assert.equal(await page.evaluate(() => editor.getContent()), 'Before\nleft  right\nAfter');
        assert.equal(await page.locator('.cm-image-widget').count(), 0);
        await page.keyboard.press('Meta+z');
        assert.equal(await page.evaluate(() => editor.getContent()), doc);
      }
    }
    await page.evaluate(() => editor.openDocument('Start\n![first](first.png) ![second](second.png)\nEnd', 'two.md'));
    await page.locator('.cm-image-widget').nth(1).click();
    await page.keyboard.press('Backspace');
    assert.equal(await page.evaluate(() => editor.getContent()), 'Start\n![first](first.png) \nEnd');
    // Moving away clears the selection; single-click shows the path editor.
    await page.locator('.cm-image-widget').click();
    await page.locator('.cm-line').filter({ hasText: 'Start' }).click();
    assert.equal(await page.locator('.cm-image-widget.cm-block-selected').count(), 0);
    await page.locator('.cm-image-widget').click();
    const input = page.locator('.cm-image-path');
    await input.fill('updated.png');
    await input.press('Enter');
    assert.equal(await page.evaluate(() => editor.getContent()), 'Start\n![first](updated.png) \nEnd');
    await page.locator('.cm-image-widget').click();
    await page.keyboard.press('Backspace');
    assert.equal(await page.evaluate(() => editor.getContent()), 'Start\n \nEnd');
    assert.deepEqual(errors, []);
    console.log('PASS: image selection, complete syntax deletion, undo, adjacent text/images and path editing');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
