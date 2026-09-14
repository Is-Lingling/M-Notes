const {webkit} = require('playwright');
const assert = require('node:assert/strict');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
(async()=>{
 const browser=await webkit.launch();
 const page=await browser.newPage({viewport:{width:940,height:840}});
 const errors=[];page.on('pageerror', e=>errors.push(e.message));
 await page.goto(pathToFileURL(path.resolve(__dirname,'../../MarkdownNotes/Editor/editor.html')).href);
 await page.waitForFunction(()=>window.editor?._view);
 const doc='# 标题\n\n```javascript\nconst first = 123;\nconst second = 456;\n```\n\n**加粗** 与正文\n下一行必须保持未选中\n\n| A | B |\n| --- | --- |\n| one | two |\n\nEnd';
 await page.evaluate(doc=>editor.openDocument(doc,'test.md',{},false),doc);
 await page.waitForTimeout(150);
  // Verify heading and markdown syntax hiding without occupying space on inactive lines
  // Move cursor to line 4 (inside code block) so heading and bold lines are inactive
  await page.evaluate(() => editor.gotoLine(4));
  await page.waitForTimeout(100);

  const inactiveH1 = await page.evaluate(() => {
    const h1 = document.querySelector('.cm-heading-1');
    const hidden = h1.querySelector('.cm-md-syntax-hidden');
    return { text: h1.innerText.trim(), hasHidden: !!hidden, hiddenWidth: hidden?.getBoundingClientRect().width };
  });
  assert.equal(inactiveH1.text, '标题');
  assert.equal(inactiveH1.hasHidden, true);
  assert.equal(inactiveH1.hiddenWidth, 0);

  const inactiveBold = await page.evaluate(() => {
    const line = [...document.querySelectorAll('.cm-line')].find(l => l.innerText.includes('加粗'));
    const hidden = line?.querySelectorAll('.cm-md-syntax-hidden');
    return { text: line?.innerText.trim(), hiddenCount: hidden ? hidden.length : 0 };
  });
  assert.equal(inactiveBold.text, '加粗 与正文');
  assert.equal(inactiveBold.hiddenCount, 2);

  // When cursor is on heading line, # is shown and occupies space
  await page.locator('.cm-line').filter({hasText:'标题'}).click();
  await page.waitForTimeout(100);
  const activeH1 = await page.evaluate(() => {
    const h1 = document.querySelector('.cm-heading-1');
    return h1.innerText.trim();
  });
  assert.equal(activeH1, '# 标题');

  // When cursor is on bold line, ** is shown and occupies space
  await page.locator('.cm-line').filter({hasText:'加粗'}).click();
  await page.waitForTimeout(100);
  const activeBold = await page.evaluate(() => {
    const line = [...document.querySelectorAll('.cm-line')].find(l => l.innerText.includes('加粗'));
    return line?.innerText.trim();
  });
  assert.equal(activeBold, '**加粗** 与正文');

  async function dragText(text, begin, end) {
   const lineLoc = page.locator('.cm-line').filter({hasText:text.includes('加粗')?'加粗':text});
   await lineLoc.click();
   await page.waitForTimeout(50);
   const coords=await page.evaluate(({text,begin,end})=>{let view=editor._view;let start=view.state.doc.toString().indexOf(text);let a=view.coordsAtPos(start+begin),b=view.coordsAtPos(start+end);return {ax:a.left,ay:(a.top+a.bottom)/2,bx:b.left,by:(b.top+b.bottom)/2};},{text,begin,end});
   await page.mouse.move(coords.ax,coords.ay);await page.mouse.down();await page.mouse.move(coords.bx,coords.by,{steps:12});await page.mouse.up();
   await page.waitForTimeout(50);
   return page.evaluate(()=>({cm:editor._view.state.sliceDoc(editor._view.state.selection.main.from,editor._view.state.selection.main.to),native:getSelection().toString(),rects:[...getSelection().getRangeAt(0).getClientRects()].map(r=>({top:r.top,bottom:r.bottom}))}));
  }
  for(const text of ['const first = 123;','const second = 456;','**加粗** 与正文']) {
   const result=await dragText(text,0,text.length);
   assert.equal(result.cm,text);assert.equal(result.native,text);
   const line=await page.locator('.cm-line').filter({hasText:text.includes('加粗')?'加粗':text}).boundingBox();
   assert(result.rects.every(r=>r.top>=line.y-1&&r.bottom<=line.y+line.height+1));
  }
 await page.screenshot({path:'/tmp/mnotes-selection.png'});
 await page.locator('.cm-code-header-widget').click({position:{x:60,y:10}});
 assert.equal(await page.evaluate(()=>editor._view.state.sliceDoc(editor._view.state.selection.main.from,editor._view.state.selection.main.to)), '```javascript\nconst first = 123;\nconst second = 456;\n```');
 await page.keyboard.press('Backspace');
 assert(!(await page.evaluate(()=>editor.getContent())).includes('const first'));
 await page.keyboard.press('Meta+z');
 assert((await page.evaluate(()=>editor.getContent())).includes('const first'));
 await page.locator('.cm-table-hint').click();
 await page.keyboard.press('Backspace');
 assert.equal(await page.locator('.cm-live-table').count(),0);
 await page.keyboard.press('Meta+z');
 assert.equal(await page.locator('.cm-live-table').count(),1);
 await page.evaluate(()=>{editor.openDocument('# Literal\n**no bold**\n```js\nplain text','test.txt',{},true)});
 assert.equal(await page.locator('.cm-code-header-widget').count(),0);
 assert.equal(await page.locator('.cm-heading-1').count(),0);
 const exp=await page.evaluate(()=>editor.getExportDocument());
 assert(exp.html.includes('plain-text'));assert(exp.html.includes('**no bold**'));
 // Restore the exact reading position without reusing another document's offsets.
 await page.evaluate(async()=>{
  window.positions={};window.webkit={messageHandlers:{scrollInfo:{postMessage:p=>window.positions[p.documentID]=p}}};
  const text=Array.from({length:200},(_,i)=>`Line ${i}`).join('\n');
  editor.openDocument(text,'long.md',{},false);
  await new Promise(r=>setTimeout(r,120));
  editor._view.scrollDOM.scrollTop=1200;
  await new Promise(r=>setTimeout(r,160));
  editor.openDocument('B','b.md',{},false);
  editor.openDocument(text,'long.md',window.positions['long.md'],false);
 });
 await page.waitForTimeout(180);
 assert(Math.abs(await page.evaluate(()=>editor._view.scrollDOM.scrollTop)-1200)<1);
 assert.deepEqual(errors,[]);
 console.log('PASS: native/CM drag ranges and geometry, block deletion+undo, TXT literal rendering/export');
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
