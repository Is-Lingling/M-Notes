const { webkit } = require('playwright');
const assert = require('node:assert/strict');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

(async () => {
  const browser = await webkit.launch();
  try {
    const page = await browser.newPage({ viewport: { width: 940, height: 840 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(pathToFileURL(path.resolve(__dirname, '../../shared/editor/editor.html')).href);
    await page.waitForFunction(() => window.editor?._view);
    const section = ['正文', '', '| A | B |', '| --- | --- |', '| one | two |', '',
      '```js', 'const a = 1;', 'const b = 2;', '```', '', '$$', 'x^2', '$$', '',
      '公式后的正文', ''];
    await page.evaluate(doc => {
      editor.openDocument(doc, 'line-numbers.md');
      editor.setPreferences({ showLineNumbers: true });
    }, [...section, ...section, ...section, 'End'].join('\n'));

    async function checkGeometry() {
      await page.waitForTimeout(150);
      const mismatches = await page.evaluate(() => {
        const view = editor._view;
        const failures = [];
        for (const node of view.contentDOM.querySelectorAll(':scope > .cm-line')) {
          const line = view.state.doc.lineAt(view.posAtDOM(node));
          const rect = node.getBoundingClientRect();
          const gutter = [...document.querySelectorAll('.cm-lineNumbers .cm-gutterElement')]
            .find(el => el.style.visibility !== 'hidden' && el.textContent === String(line.number));
          if (!gutter || Math.abs(gutter.getBoundingClientRect().top - rect.top) > 1)
            failures.push({ line: line.number, content: rect.top, gutter: gutter?.getBoundingClientRect().top });
          const block = view.lineBlockAt(line.from);
          if (Math.abs(view.documentTop + block.top - rect.top) > 1)
            failures.push({ line: line.number, content: rect.top, measured: view.documentTop + block.top });
        }
        return failures;
      });
      assert.deepEqual(mismatches, [], 'Gutters and hit-test height map must match DOM lines');
    }
    await checkGeometry();
    assert.equal(await page.locator('.cm-hidden-fence').count(), 3);
    assert(await page.locator('.cm-hidden-fence').evaluateAll(nodes => nodes.every(el => el.getBoundingClientRect().height === 0 && el.textContent === '')));
    assert(await page.locator('.cm-lineNumbers').innerText().then(text => text.includes('3–5')));
    await page.locator('.cm-code-header-widget').first().click();
    assert.equal(await page.evaluate(() => {
      const v = editor._view, s = v.state.selection.main;
      return v.state.sliceDoc(s.from, s.to);
    }), '```js\nconst a = 1;\nconst b = 2;\n```');
    await checkGeometry();
    await page.locator('.cm-table-hint').first().click();
    assert.equal(await page.evaluate(() => {
      const v = editor._view, s = v.state.selection.main;
      return v.state.sliceDoc(s.from, s.to);
    }), '| A | B |\n| --- | --- |\n| one | two |');
    await checkGeometry();
    // Clicking below rendered blocks must resolve to the actual source line.
    for (const text of ['const a = 1;', '公式后的正文']) {
      const line = page.locator('.cm-line').filter({ hasText: text }).first();
      await line.click({ position: { x: 30, y: 10 } });
      assert.equal(await page.evaluate(() => editor._view.state.doc.lineAt(editor._view.state.selection.main.head).text), text);
      await checkGeometry();
    }
    // Table DOM reuse must still update the inner model after adding a wrapper.
    const cell = page.locator('.cm-live-table input').first();
    await cell.focus();
    await cell.fill('Updated');
    await cell.press('Tab');
    assert((await page.evaluate(() => editor.getContent())).includes('Updated'));
    await checkGeometry();
    await page.locator('.cm-math-block').first().click();
    await checkGeometry();
    await page.evaluate(() => editor.gotoLine(editor._view.state.doc.lines));
    await checkGeometry();
    await page.evaluate(() => editor.setPreferences({ fontSize: 20, lineHeight: 2 }));
    await checkGeometry();
    await page.evaluate(() => editor.setPreferences({ showLineNumbers: false }));
    assert.equal(await page.locator('.cm-lineNumbers').count(), 0);
    await page.evaluate(() => editor.setPreferences({ showLineNumbers: true }));
    await checkGeometry();
    // A delayed image must update short-note geometry, not just long documents.
    let releaseImage;
    const imageReady = new Promise(resolve => { releaseImage = resolve; });
    await page.route('https://image.test/preview.svg', async route => {
      await imageReady;
      await route.fulfill({ contentType: 'image/svg+xml', body: '<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900"><rect width="1600" height="900" fill="blue"/></svg>' });
    });
    await page.evaluate(() => editor.openDocument('Start\n  ![preview](https://image.test/preview.svg)  \nAfter image', 'image.md'));
    await checkGeometry();
    releaseImage();
    await page.waitForFunction(() => document.querySelector('.cm-rendered-image')?.naturalHeight === 900);
    await checkGeometry();
    await page.locator('.cm-line').filter({ hasText: 'After image' }).click();
    assert.equal(await page.evaluate(() => editor._view.state.doc.lineAt(editor._view.state.selection.main.head).text), 'After image');
    // Check the rendered image itself, not merely its enclosing CodeMirror line.
    async function checkImageTop() {
      const positions = await page.evaluate(() => {
        const image = document.querySelector('.cm-rendered-image');
        const line = image.closest('.cm-line');
        const number = editor._view.state.doc.lineAt(editor._view.posAtDOM(line)).number;
        const gutter = [...document.querySelectorAll('.cm-gutterElement')].find(el => el.style.visibility !== 'hidden' && el.textContent === String(number));
        return [image.getBoundingClientRect().top, line.getBoundingClientRect().top, gutter.getBoundingClientRect().top];
      });
      assert(Math.max(...positions) - Math.min(...positions) < 1, `Image must start at its numbered row: ${positions}`);
    }
    for (const width of [940, 480, 320]) {
      await page.setViewportSize({ width, height: 840 });
      await checkGeometry();
      await checkImageTop();
    }
    await page.setViewportSize({ width: 940, height: 840 });
    await checkGeometry();
    const nextLine = page.locator('.cm-line').filter({ hasText: 'After image' });
    const beforePath = await nextLine.boundingBox();
    for (let i = 0; i < 3; i++) {
      await page.locator('.cm-image-widget').click();
      assert.equal(await page.locator('.cm-image-path:visible').count(), 1);
      await checkImageTop();
      await checkGeometry();
      assert(Math.abs((await nextLine.boundingBox()).y - beforePath.y) < 1, 'Showing path must not move the next line');
      await nextLine.click();
      assert.equal(await page.locator('.cm-image-path:visible').count(), 0);
      await checkGeometry();
      assert(Math.abs((await nextLine.boundingBox()).y - beforePath.y) < 1, 'Hiding path must not move the next line');
    }
    await page.locator('.cm-image-widget').click();
    await page.locator('.cm-image-path').press('Escape');
    await checkGeometry();
    await page.evaluate(() => editor.openDocument(editor.getContent(), 'source.txt', {}, true));
    await checkGeometry();
    assert.deepEqual(errors, []);
    console.log('Line number geometry and selection tests passed');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
