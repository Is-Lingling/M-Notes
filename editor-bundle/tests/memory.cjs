const { webkit, chromium } = require('playwright');
const assert = require('node:assert/strict');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const editorURL = pathToFileURL(path.resolve(__dirname, '../../shared/editor/editor.html')).href;
(async () => {
  const browser = await webkit.launch();
  try {
    const page = await browser.newPage();
    page.setDefaultTimeout(15000);
    const errors = []; page.on('pageerror', error => errors.push(error.message));
    await page.goto(editorURL); await page.waitForFunction(() => window.editor?._view);
    assert.equal(await page.evaluate(() => typeof window.mermaid), 'undefined');
    await page.evaluate(() => {
      editor.openDocument('# Ordinary note\n\nText and $x^2$\n', 'plain');
      editor.setTheme('github-dark'); editor.setLanguage('en');
    });
    await page.evaluate(() => editor.getExportDocument());
    assert.equal(await page.evaluate(() => typeof window.mermaid), 'undefined', 'ordinary notes/export must not load Mermaid');
    const history = await page.evaluate(() => {
      for (let i = 0; i < 30; i++) {
        editor.openDocument('Document ' + i + '\n' + 'body\n'.repeat(1000), String(i));
        editor.insertAtCursor('an edit');
      }
      editor.openDocument('Final document', 'final');
      const initial = CM.commands.undoDepth(editor._view.state);
      CM.commands.undo(editor._view);
      const afterUndo = editor.getContent();
      editor.insertAtCursor('new edit');
      const edited = CM.commands.undoDepth(editor._view.state);
      CM.commands.undo(editor._view);
      return { initial, afterUndo, edited, afterEditUndo: editor.getContent() };
    });
    assert.deepEqual(history, { initial: 0, afterUndo: 'Final document', edited: 1, afterEditUndo: 'Final document' });
    const snapshot = await page.evaluate(() => {
      editor.openDocument('# Resume test\n\noriginal', 'sleep-test');
      editor.insertAtCursor('edited');
      editor.setSourceMode(true);
      editor._view.dispatch({ selection: { anchor: 3, head: 7 } });
      editor.setBackgrounded(true);
      return editor.captureSession();
    });
    const stored = JSON.parse(snapshot);
    await page.reload(); await page.waitForFunction(() => window.editor?._view);
    const restored = await page.evaluate(snapshot => {
      const session = JSON.parse(snapshot);
      editor.openDocument(session.state.doc, session.documentID);
      const ok = editor.restoreSession(snapshot);
      editor.setBackgrounded(false);
      const selection = editor._view.state.selection.main;
      const result = { ok, from: selection.from, to: selection.to, undo: CM.commands.undoDepth(editor._view.state), source: document.body.classList.contains('source-mode') };
      CM.commands.undo(editor._view);
      result.undone = editor.getContent();
      editor.openDocument('External edit', session.documentID);
      result.rejectStale = !editor.restoreSession(snapshot) && editor.getContent() === 'External edit';
      return result;
    }, snapshot);
    assert.deepEqual(restored, { ok: true, from: 3, to: 7, undo: 1, source: true, undone: '# Resume test\n\noriginal', rejectStale: true });
    await page.evaluate(() => {
      editor.setSourceMode(false); editor.setBackgrounded(true);
      document.dispatchEvent(new Event('visibilitychange'));
      editor.setContent('# Background\n\n```mermaid\ngraph TD\nA-->B\n```\n');
    });
    assert.equal(await page.evaluate(() => typeof window.mermaid), 'undefined', 'background changes must not start diagram rendering');
    await page.evaluate(() => { editor.setSourceMode(true); editor.setBackgrounded(false); });
    // Source mode has no preview widget; export must still load/render the diagram.
    await page.evaluate(() => {
      editor.setSourceMode(true);
      editor.setContent('# Diagram\n\n```mermaid\ngraph TD\nA-->B\n```\n');
    });
    assert.equal(await page.evaluate(() => typeof window.mermaid), 'undefined');
    const exports = await page.evaluate(() => Promise.all([editor.getExportDocument(), editor.getExportDocument()]));
    assert(exports.every(item => item.html.includes('<svg')), 'first/concurrent exports must render diagrams');
    assert.equal(await page.locator('script[src="mermaid/mermaid.min.js"]').count(), 1);
    await page.evaluate(() => { editor.setSourceMode(false); editor.gotoLine(1); });
    await page.locator('.cm-mermaid-widget svg').waitFor();
    assert.deepEqual(errors, []);
    console.log('PASS: Mermaid stays unloaded for text/math/theme/export, first/concurrent diagram export, preview, document history release and current-document undo');
  } finally { await browser.close(); }
  if (process.argv[2]) {
    const results = {};
    for (const [label, url] of Object.entries({ baseline: pathToFileURL(path.resolve(process.argv[2])).href, optimized: editorURL })) {
      const samples = [];
      for (let i = 0; i < 3; i++) {
        const browser = await chromium.launch();
        try {
          const page = await browser.newPage();
          await page.goto(url); await page.waitForFunction(() => window.editor?._view);
          await page.evaluate(() => editor.openDocument('# Note\n\nA short Markdown document.', 'benchmark'));
          const cdp = await page.context().newCDPSession(page);
          await cdp.send('Performance.enable'); await cdp.send('HeapProfiler.collectGarbage');
          const { metrics } = await cdp.send('Performance.getMetrics');
          samples.push(metrics.find(metric => metric.name === 'JSHeapUsedSize').value);
        } finally { await browser.close(); }
      }
      results[label] = { samplesBytes: samples, medianBytes: samples.sort((a,b) => a-b)[1] };
    }
    console.log('Chromium JS heap only (not macOS total process memory):', JSON.stringify(results));
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
