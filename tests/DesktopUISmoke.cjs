const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const http = require("node:http");
const { createRequire } = require("node:module");
const platform = process.cwd();
const { webkit, chromium } = createRequire(path.join(platform, "package.json"))(
  "playwright",
);
const root = path.join(platform, "src");
const server = http.createServer((req, res) => {
  const file = path.join(
    root,
    decodeURIComponent(
      req.url.split("?")[0] === "/" ? "/index.html" : req.url.split("?")[0],
    ),
  );
  if (!file.startsWith(root + path.sep)) {
    res.writeHead(403).end();
    return;
  }
  fs.readFile(file, (error, data) => {
    if (error) {
      res.writeHead(404).end();
      return;
    }
    const types = {
      ".html": "text/html",
      ".js": "text/javascript",
      ".css": "text/css",
      ".woff2": "font/woff2",
    };
    res.setHeader(
      "Content-Type",
      types[path.extname(file)] || "application/octet-stream",
    );
    res.end(data);
  });
});
(async () => {
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const browser = await (
    process.env.UI_BROWSER === "chromium" ? chromium : webkit
  ).launch();
  try {
    const page = await browser.newPage({
      viewport: { width: 1100, height: 760 },
    });
    page.setDefaultTimeout(15000);
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    const url = `http://127.0.0.1:${server.address().port}`;
    await page.goto(url);
    const waitReady = () =>
      page.waitForFunction(() => !document.getElementById("btn-save").disabled);
    const edit = (text) =>
      page.evaluate(
        (text) =>
          document
            .getElementById("editor-frame")
            .contentWindow.editor.setContent(text),
        text,
      );
    const getContent = () =>
      page.evaluate(() =>
        document
          .getElementById("editor-frame")
          .contentWindow.editor.getContent(),
      );
    await waitReady();
    await edit(
      "# 项目笔记\n\n## 本周计划\n\nhello hello\n\n```md\n# not a heading\n```",
    );
    await page.waitForFunction(
      () => document.getElementById("heading-count").textContent === "2",
    );
    assert.match(await page.locator("#save-state").textContent(), /未保存/);
    // A shortcut dispatched inside the editor must be handled by the desktop shell.
    await page.frameLocator("#editor-frame").locator(".cm-content").click();
    await page.keyboard.press("Control+f");
    assert.equal(await page.locator("#searchbar").isVisible(), true);
    await page.locator("#query").fill("hello");
    await page.locator("#replacement").fill("world");
    await page.locator("[data-search=replaceAll]").click();
    assert.match(await getContent(), /world world/);
    await page.locator("#close-search").click();
    const chooserPromise = page.waitForEvent("filechooser");
    await page.locator("#btn-image").click();
    await (
      await chooserPromise
    ).setFiles({
      name: "pixel.png",
      mimeType: "image/png",
      buffer: Buffer.from(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a7WQAAAAASUVORK5CYII=",
        "base64",
      ),
    });
    await page.waitForFunction(() =>
      document
        .getElementById("editor-frame")
        .contentWindow.editor.getContent()
        .includes("data:image/png"),
    );
    const downloadPromise = page.waitForEvent("download");
    await page.locator("#btn-export").click();
    const download = await downloadPromise;
    const exportedHTML = fs.readFileSync(await download.path(), "utf8");
    assert.match(exportedHTML, /data:image\/png/);
    assert.match(exportedHTML, /world world/);
    await page.locator("#btn-new").click();
    await page.locator("#unsaved button[value=cancel]").click();
    assert.match(await getContent(), /项目笔记/);
    await page.locator("#btn-settings").click();
    await page.locator("#theme").selectOption("github-dark");
    await page.locator("#font-size").selectOption("20");
    await page.locator("#line-numbers").check();
    await page.locator("#settings .primary").click();
    assert.equal(await page.locator("html").getAttribute("data-dark"), "true");
    await page.waitForTimeout(700);
    // Recovery survives a page restart, including appearance preferences.
    page.on("dialog", (dialog) => dialog.accept());
    await page.reload();
    await waitReady();
    assert.match(await getContent(), /world world/);
    assert.equal(await page.locator("#theme").inputValue(), "github-dark");
    await page.locator("#btn-source").click();
    assert.equal(
      await page
        .frameLocator("#editor-frame")
        .locator("body")
        .evaluate((el) => el.classList.contains("source-mode")),
      true,
    );
    assert.equal(await page.locator("#btn-focus").count(), 0);
    if (process.env.UI_SCREENSHOT)
      await page.screenshot({ path: process.env.UI_SCREENSHOT });
    await page.locator("#btn-new").click();
    await page.locator("#unsaved button[value=discard]").click();
    await waitReady();
    assert.equal(await getContent(), "");
    await page.frameLocator("#editor-frame").locator(".cm-content").click();
    await page.keyboard.press("Control+z");
    assert.equal(
      await getContent(),
      "",
      "undo must not restore another document",
    );
    for (const width of [640, 720, 800, 1100]) {
      await page.setViewportSize({ width, height: 480 });
      assert.equal(
        await page.evaluate(
          () => document.documentElement.scrollWidth <= innerWidth,
        ),
        true,
        `layout at ${width}px`,
      );
    }
    assert.deepEqual(errors, []);
    await page.close();
    const nativePage = await browser.newPage();
    nativePage.setDefaultTimeout(15000);
    await nativePage.addInitScript(() => {
      const callbacks = new Map();
      let next = 0;
      window.mock = {
        selected: "C:\\笔记\\测试.txt",
        savePath: "C:\\笔记\\保存.txt",
        writes: [],
        fail: false,
        destroyed: false,
      };
      window.__TAURI_INTERNALS__ = {
        metadata: { currentWindow: { label: "main" } },
        transformCallback(callback) {
          callbacks.set(++next, callback);
          return next;
        },
        async invoke(command, args, options) {
          if (command === "plugin:event|listen") {
            if (args.event === "tauri://close-requested")
              window.mock.close = () =>
                callbacks.get(args.handler)({
                  event: args.event,
                  id: 1,
                  payload: null,
                });
            if (args.event === "tauri://focus")
              window.mock.focus = () =>
                callbacks.get(args.handler)({
                  event: args.event,
                  id: 2,
                  payload: true,
                });
            if (args.event === "tauri://blur")
              window.mock.blur = () =>
                callbacks.get(args.handler)({
                  event: args.event,
                  id: 3,
                  payload: false,
                });
            return 1;
          }
          if (command === "plugin:dialog|open") return window.mock.selected;
          if (command === "plugin:dialog|save") return window.mock.savePath;
          if (command === "plugin:fs|read_text_file")
            return Array.from(new TextEncoder().encode("plain text"));
          if (command === "plugin:fs|write_text_file") {
            if (window.mock.fail) throw Error("disk full");
            window.mock.writes.push({
              path: decodeURIComponent(options.headers.path),
              text: new TextDecoder().decode(args),
            });
            return;
          }
          if (command === "plugin:window|destroy") {
            window.mock.destroyed = true;
            return;
          }
          throw Error("Unexpected IPC: " + command);
        },
      };
    });
    await nativePage.goto(url);
    const nativeReady = () =>
      nativePage.waitForFunction(
        () => !document.getElementById("btn-save").disabled,
      );
    await nativeReady();
    await nativePage.locator("#btn-open").click();
    await nativeReady();
    assert.equal(
      await nativePage.locator("#doc-title").textContent(),
      "测试.txt",
    );
    assert.equal(
      await nativePage.locator("#file-type").textContent(),
      "纯文本",
    );
    assert.equal(
      await nativePage.locator("[data-command=bold]").isDisabled(),
      true,
    );
    await nativePage.evaluate(() =>
      document
        .getElementById("editor-frame")
        .contentWindow.editor.setContent("changed"),
    );
    await nativePage.waitForFunction(() =>
      document.getElementById("save-state").textContent.includes("未保存"),
    );
    await nativePage.evaluate(() => {
      window.mock.fail = true;
    });
    await nativePage.locator("#btn-save").click();
    await nativePage.waitForFunction(() =>
      document.getElementById("status").textContent.includes("disk full"),
    );
    assert.match(
      await nativePage.locator("#save-state").textContent(),
      /未保存/,
    );
    await nativePage.evaluate(() => {
      window.mock.fail = false;
      window.mock.savePath = null;
    });
    await nativePage.locator("#btn-save-as").click();
    await nativeReady();
    assert.equal(
      await nativePage.locator("#doc-title").textContent(),
      "● 测试.txt",
    );
    await nativePage.locator("#btn-save").click();
    await nativeReady();
    assert.equal(
      await nativePage.evaluate(() => window.mock.writes[0].text),
      "changed",
    );
    assert.equal(
      await nativePage.evaluate(() => window.mock.writes[0].path),
      "C:\\笔记\\测试.txt",
    );
    // Native focus loss stops polling immediately, then unloads the iframe after 5 minutes.
    await nativePage.clock.install();
    const resumeState = await nativePage.evaluate(() => {
      const e = document.getElementById("editor-frame").contentWindow.editor;
      e.insertAtCursor("idle edit");
      e._view.dispatch({ selection: { anchor: 3 } });
      return {
        text: e.getContent(),
        undo: document
          .getElementById("editor-frame")
          .contentWindow.CM.commands.undoDepth(e._view.state),
      };
    });
    await nativePage.evaluate(() => window.mock.blur());
    await nativePage.evaluate(() => {
      const e = document.getElementById("editor-frame").contentWindow.editor;
      const original = e.getContent.bind(e);
      window.backgroundPolls = 0;
      e.getContent = () => {
        window.backgroundPolls++;
        return original();
      };
    });
    await nativePage.clock.fastForward(60000);
    assert.equal(
      await nativePage.evaluate(() => window.backgroundPolls),
      0,
      "background must not poll the full document",
    );
    await nativePage.evaluate(() => window.mock.focus());
    assert.equal(
      await nativePage.locator("#editor-frame").getAttribute("src"),
      "editor/editor.html",
      "quick return must not unload editor",
    );
    await nativePage.locator("#btn-settings").click();
    await nativePage.evaluate(() => window.mock.blur());
    await nativePage.clock.fastForward(300001);
    await nativePage.waitForFunction(
      () =>
        document.getElementById("editor-frame").getAttribute("src") ===
        "about:blank",
    );
    await nativePage.evaluate(() => window.mock.focus());
    await nativeReady();
    const resumed = await nativePage.evaluate(() => {
      const w = document.getElementById("editor-frame").contentWindow;
      return {
        text: w.editor.getContent(),
        undo: w.CM.commands.undoDepth(w.editor._view.state),
        anchor: w.editor._view.state.selection.main.head,
      };
    });
    assert.deepEqual(resumed, { ...resumeState, anchor: 3 });
    await nativePage.locator("#settings .primary").click();
    await nativePage.evaluate(() =>
      document
        .getElementById("editor-frame")
        .contentWindow.editor.setContent("close draft"),
    );
    await nativePage.evaluate(() => {
      void window.mock.close();
    });
    await nativePage.locator("#unsaved button[value=cancel]").click();
    await nativeReady();
    assert.equal(await nativePage.evaluate(() => window.mock.destroyed), false);
    await nativePage.evaluate(() => {
      void window.mock.close();
    });
    await nativePage.locator("#unsaved button[value=save]").click();
    await nativePage.waitForFunction(() => window.mock.destroyed);
    assert.equal(
      await nativePage.evaluate(() => window.mock.writes.at(-1).text),
      "close draft",
    );
    await nativePage.close();
    console.log(
      "PASS: background polling stopped, timed hibernation and undo restored; mocked native open, Windows paths, TXT mode, write failure, save cancellation, save, close cancellation and save-before-close",
    );
    console.log(
      "PASS: editor initialization, outline/fences, iframe shortcuts, replace all, cancel/discard, recovery, theme, source mode, undo isolation, 640px layout",
    );
  } finally {
    await browser.close();
    server.close();
  }
})().catch((error) => {
  console.error(error);
  server.close();
  process.exitCode = 1;
});
