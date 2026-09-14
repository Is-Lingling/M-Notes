const { webkit } = require('playwright');
const assert = require('node:assert/strict');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

(async () => {
  const browser = await webkit.launch();
  const page = await browser.newPage({ viewport: { width: 900, height: 900 } });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(pathToFileURL(path.resolve(__dirname, '../../MarkdownNotes/Editor/editor.html')).href);
  await page.waitForFunction(() => window.editor?._view);
  await page.evaluate(() => editor.setPreferences({ showLineNumbers: true }));
  async function checkGeometry() {
    await page.waitForTimeout(150);
    const errors = await page.evaluate(() => {
      const view = editor._view;
      const errors = [];
      for (const line of view.contentDOM.querySelectorAll(':scope > .cm-line')) {
        const position = view.posAtDOM(line);
        const number = view.state.doc.lineAt(position).number;
        const gutter = [...document.querySelectorAll('.cm-gutterElement')].find(element => element.style.visibility !== 'hidden' && element.textContent === String(number));
        const top = line.getBoundingClientRect().top;
        if (!gutter || Math.abs(gutter.getBoundingClientRect().top - top) > 1 || Math.abs(view.documentTop + view.lineBlockAt(position).top - top) > 1) errors.push(number);
      }
      const diagram = document.querySelector('.cm-mermaid-widget');
      if (diagram) {
        const gutter = [...document.querySelectorAll('.cm-gutterElement')].find(element => element.textContent === '3–6');
        if (!gutter || Math.abs(gutter.getBoundingClientRect().top - diagram.getBoundingClientRect().top) > 1) errors.push('diagram');
      }
      return errors;
    });
    assert.deepEqual(errors, [], 'Rendered blocks, source lines and gutters must agree');
  }

  // 1. Test Block Math rendering
  const mathDoc = '# Test Math\n\n$$\nf(x) = \\frac{1}{\\sigma \\sqrt{2\\pi}}\n$$\n\nAfter math';
  await page.evaluate(text => { editor.setContent(text); editor.gotoLine(1); }, mathDoc);
  await page.locator('.cm-math-block').waitFor();
  const mathText = await page.locator('.cm-math-block').innerHTML();
  assert(mathText.includes('katex'), 'Math block did not render katex');
  assert(mathText.includes('katex-display'), 'Math block is not in display mode');

  // Test clicking math block to edit
  await page.locator('.cm-math-block').click();
  await page.locator('.cm-math-source-line').first().waitFor();
  const activeLine = await page.evaluate(() => editor._view.state.doc.lineAt(editor._view.state.selection.main.head).text);
  assert(activeLine.includes('f(x)') || activeLine.includes('$$'), 'Clicking math did not move cursor inside: ' + activeLine);
  const mathSelection = await page.evaluate(() => {
    const view = editor._view, line = view.state.doc.line(4);
    const start = view.coordsAtPos(line.from), end = view.coordsAtPos(line.from + 6);
    return { start: { x: start.left, y: (start.top + start.bottom) / 2 }, end: { x: end.left, y: (end.top + end.bottom) / 2 } };
  });
  await page.mouse.move(mathSelection.start.x, mathSelection.start.y);
  await page.mouse.down();
  await page.mouse.move(mathSelection.end.x, mathSelection.end.y, { steps: 8 });
  await page.mouse.up();
  await checkGeometry();
  assert.equal(await page.locator('.cm-math-text-selection').count(), 1);
  const mathHighlight = await page.evaluate(() => {
    const view = editor._view, selection = view.state.selection.main;
    return {
      text: view.state.sliceDoc(selection.from, selection.to),
      native: getSelection().toString(),
      outside: [...document.querySelectorAll('.cm-selectionBackground')].every(element => getComputedStyle(element).backgroundColor === 'rgba(0, 0, 0, 0)'),
      textBackground: getComputedStyle(document.querySelector('.cm-math-source-line'), '::selection').backgroundColor,
    };
  });
  assert.equal(mathHighlight.text, 'f(x) =');
  assert.equal(mathHighlight.native, mathHighlight.text);
  assert(mathHighlight.outside);
  assert.notEqual(mathHighlight.textBackground, 'rgba(0, 0, 0, 0)');
  await page.screenshot({ path: '/tmp/mnotes-math-selection.png' });
  await page.locator('.cm-line').filter({ hasText: 'After math' }).click();
  assert.equal(await page.locator('.cm-math-text-selection').count(), 0);

  // 2. Test Mermaid Diagram rendering
  const mermaidDoc = '# Test Mermaid\n\n```mermaid\ngraph TD\n    A --> B\n```\n\nAfter diagram';
  await page.evaluate(text => { editor.setContent(text); editor.gotoLine(1); }, mermaidDoc);
  await page.locator('.cm-mermaid-widget').waitFor();
  await page.locator('.cm-mermaid-widget svg').waitFor();
  const svgCount = await page.locator('.cm-mermaid-widget svg').count();
  assert.equal(svgCount, 1, 'Mermaid SVG did not render');
  await checkGeometry();
  await page.setViewportSize({ width: 480, height: 900 });
  await checkGeometry();
  await page.setViewportSize({ width: 900, height: 900 });
  await checkGeometry();

  // Test clicking mermaid widget to edit
  await page.locator('.cm-mermaid-widget').click();
  await page.locator('.cm-code-block-header-line').waitFor();
  const headerLang = await page.locator('.cm-code-lang').innerText();
  assert.equal(headerLang, 'MERMAID', 'Did not enter Mermaid edit mode');
  await page.locator('.cm-code-header-widget').click();
  assert.equal(await page.locator('.cm-editor.cm-code-block-selection').count(), 1);
  assert.equal(await page.locator('.cm-code-block-line.cm-code-selected').count(), 2);
  const styles = await page.evaluate(() => {
    const line = document.querySelector('.cm-code-block-line');
    const header = document.querySelector('.cm-code-block-header-line');
    return {
      lineBorder: getComputedStyle(line).borderLeftColor,
      headerBorder: getComputedStyle(header).borderTopColor,
      outside: [...document.querySelectorAll('.cm-selectionBackground')].every(element => getComputedStyle(element).backgroundColor === 'rgba(0, 0, 0, 0)'),
    };
  });
  assert.equal(styles.lineBorder, styles.headerBorder);
  assert.equal(styles.headerBorder, 'rgb(255, 214, 10)');
  assert(styles.outside, 'Whole-code selection must not paint behind the block');
  await page.evaluate(() => {
    const view = editor._view, line = view.state.doc.line(4);
    view.dispatch({ selection: { anchor: line.from, head: line.to } });
  });
  assert.equal(await page.locator('.cm-editor.cm-code-text-selection').count(), 1);
  assert.equal(await page.locator('.cm-code-selected').count(), 0);
  await checkGeometry();

  // Move cursor out to re-render
  await page.evaluate(() => editor.gotoLine(1));
  await page.locator('.cm-mermaid-widget svg').waitFor();
  await checkGeometry();
  assert.equal(await page.locator('.cm-code-block-selection, .cm-code-text-selection').count(), 0);

  // 3. Test HTML img tag
  const htmlDoc = 'Before\n\n<img src="https://example.com/logo.png" alt="Logo" />\n\nAfter';
  await page.evaluate(text => { editor.setContent(text); editor.gotoLine(1); }, htmlDoc);
  await page.locator('.cm-image-widget').waitFor();

  console.log('PASS: block math KaTeX, click-to-edit, mermaid diagram SVG rendering, click-to-edit, and HTML img');
  await browser.close();
  if (errors.length) {
    console.error('Page errors:', errors);
    process.exit(1);
  }
})();
