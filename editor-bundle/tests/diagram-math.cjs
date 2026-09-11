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

  // 2. Test Mermaid Diagram rendering
  const mermaidDoc = '# Test Mermaid\n\n```mermaid\ngraph TD\n    A --> B\n```\n\nAfter diagram';
  await page.evaluate(text => { editor.setContent(text); editor.gotoLine(1); }, mermaidDoc);
  await page.locator('.cm-mermaid-widget').waitFor();
  await page.locator('.cm-mermaid-widget svg').waitFor();
  const svgCount = await page.locator('.cm-mermaid-widget svg').count();
  assert.equal(svgCount, 1, 'Mermaid SVG did not render');

  // Test clicking mermaid widget to edit
  await page.locator('.cm-mermaid-widget').click();
  await page.locator('.cm-code-block-header-line').waitFor();
  const headerLang = await page.locator('.cm-code-lang').innerText();
  assert.equal(headerLang, 'MERMAID', 'Did not enter Mermaid edit mode');

  // Move cursor out to re-render
  await page.evaluate(() => editor.gotoLine(1));
  await page.locator('.cm-mermaid-widget svg').waitFor();

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
