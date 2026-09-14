import { open, save } from "@tauri-apps/plugin-dialog";
import { readTextFile, writeTextFile, readFile } from "@tauri-apps/plugin-fs";
import { getCurrentWindow } from "@tauri-apps/api/window";

const $ = (id) => document.getElementById(id);
const frame = $("editor-frame");
const native = !!window.__TAURI_INTERNALS__;
const basename = (path) => path.split(/[\\/]/).pop();
const filters = [
  { name: "Markdown / 纯文本", extensions: ["md", "markdown", "txt"] },
];
let path = null,
  name = "未命名.md",
  content = "",
  saved = "",
  ready = false,
  busy = false;
let source = false,
  draftTimer,
  initializedDocument;
let foreground = !document.hidden,
  nativeFocused = true;
let pollTimer,
  sleepTimer,
  sleepingSession = null;
const backgroundSleepDelay = 5 * 60 * 1000;
let settings = {
  theme: "system",
  fontSize: 16,
  showLineNumbers: false,
  typewriter: false,
};
try {
  settings = {
    ...settings,
    ...JSON.parse(localStorage.getItem("mnotes.settings") || "{}"),
  };
} catch (_) {}
try {
  const draft = JSON.parse(localStorage.getItem("mnotes.draft") || "null");
  if (draft && typeof draft.content === "string") {
    content = draft.content;
    name = typeof draft.name === "string" ? draft.name : name;
    // Recovery never silently overwrites a file changed outside the app.
    saved = null;
    status("已恢复未保存的草稿，请另存为文件。");
  }
} catch (_) {}
$("platform").textContent = navigator.userAgent.includes("Windows")
  ? "Windows"
  : navigator.userAgent.includes("Linux")
    ? "Linux"
    : "Desktop";
const editor = () => frame.contentWindow?.editor;
const dirty = () => content !== saved;
function status(message, error = false) {
  $("status").textContent = message;
  $("status").title = message;
  $("status").classList.toggle("error", error);
}
function persistDraft() {
  try {
    if (dirty())
      localStorage.setItem("mnotes.draft", JSON.stringify({ name, content }));
    else localStorage.removeItem("mnotes.draft");
  } catch (_) {
    status("无法保存恢复草稿，请及时保存到文件。", true);
  }
}
function sync() {
  if (!ready) return;
  const next = editor().getContent();
  if (next !== content) {
    content = next;
    render();
    clearTimeout(draftTimer);
    draftTimer = setTimeout(persistDraft, 500);
  }
}
function render() {
  $("doc-title").textContent = `${dirty() ? "● " : ""}${name}`;
  $("doc-title").title = path || name;
  document.title = `${dirty() ? "● " : ""}${name} — M Notes`;
  $("save-state").textContent = !ready
    ? sleepingSession
      ? "后台休眠中"
      : "正在加载编辑器…"
    : dirty()
      ? "有未保存的更改"
      : "所有更改已保存";
  $("file-type").textContent = /\.txt$/i.test(name) ? "纯文本" : "Markdown";
  $("statistics").textContent =
    `${Array.from(content.replace(/\s/g, "")).length.toLocaleString()} 字符 · ${content.split("\n").length.toLocaleString()} 行`;
  const outline = $("outline");
  outline.replaceChildren();
  let count = 0,
    fence = null;
  if (!/\.txt$/i.test(name))
    content.split("\n").forEach((line, index) => {
      const marker = line.match(/^\s{0,3}(`{3,}|~{3,})/);
      if (marker) {
        if (!fence) fence = marker[1];
        else if (marker[1][0] === fence[0] && marker[1].length >= fence.length)
          fence = null;
        return;
      }
      const heading = !fence && line.match(/^\s{0,3}(#{1,6})\s+(.+?)\s*#*$/);
      if (!heading) return;
      const button = document.createElement("button");
      button.textContent = heading[2];
      button.style.paddingLeft = `${10 + (heading[1].length - 1) * 12}px`;
      button.onclick = () => editor()?.gotoLine(index + 1);
      outline.append(button);
      count++;
    });
  $("heading-count").textContent = count;
  if (!count) {
    const p = document.createElement("p");
    p.className = "empty";
    p.textContent = "添加 Markdown 标题后，即可在这里导航。";
    outline.append(p);
  }
  updateControls();
}
function updateControls() {
  document
    .querySelectorAll("nav button, #formatbar button")
    .forEach((button) => {
      button.disabled = busy || !ready;
    });
  if (/\.txt$/i.test(name))
    document
      .querySelectorAll("#formatbar button, #btn-source")
      .forEach((button) => {
        button.disabled = true;
      });
}
function applySettings() {
  const dark =
    ["github-dark", "liquid-glass-dark", "dracula"].includes(settings.theme) ||
    (settings.theme === "system" &&
      matchMedia("(prefers-color-scheme: dark)").matches);
  document.documentElement.dataset.dark = dark;
  if (ready) {
    editor().setTheme(settings.theme);
    editor().setPreferences(settings);
    editor().setTypewriterMode(settings.typewriter);
  }
  try {
    localStorage.setItem("mnotes.settings", JSON.stringify(settings));
  } catch (_) {}
}
async function initialize() {
  if (frame.getAttribute("src") === "about:blank") return;
  const doc = frame.contentDocument;
  if (initializedDocument === doc) return;
  initializedDocument = doc;
  doc.addEventListener("keydown", shortcuts, true);
  for (let i = 0; i < 100; i++) {
    if (frame.contentDocument !== doc) return;
    if (editor()?._view) {
      ready = true;
      editor().setBackgrounded(!foreground);
      editor().openDocument(
        content,
        sleepingSession
          ? JSON.parse(sleepingSession).documentID
          : `${Date.now()}`,
        {},
        /\.txt$/i.test(name),
      );
      editor().setLanguage("zh-Hans");
      editor().setSourceMode(source);
      applySettings();
      if (sleepingSession) {
        try {
          editor().restoreSession(sleepingSession);
        } catch (error) {
          status(`恢复撤销记录失败：${error.message}`, true);
        }
        sleepingSession = null;
      }
      editor().setBackgrounded(!foreground);
      if (!$("searchbar").hidden) search();
      render();
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  status("编辑器加载失败，请重新启动应用。恢复草稿已保留。", true);
}
frame.addEventListener("load", initialize);
if (frame.contentDocument?.readyState === "complete") initialize();
function replaceDocument(text, filePath, fileName) {
  sleepingSession = null;
  content = saved = text;
  path = filePath;
  name = fileName;
  ready = false;
  source = false;
  $("btn-source").setAttribute("aria-pressed", "false");
  $("searchbar").hidden = true;
  $("query").value = "";
  $("replacement").value = "";
  persistDraft();
  render();
  // A fresh editor also resets undo history, preventing edits leaking between documents.
  frame.src = "editor/editor.html";
}
function askUnsaved() {
  const dialog = $("unsaved");
  $("unsaved-description").textContent = `“${name}”有未保存的更改。`;
  return new Promise((resolve) => {
    dialog.returnValue = "cancel";
    dialog.addEventListener("close", () => resolve(dialog.returnValue), {
      once: true,
    });
    dialog.showModal();
  });
}
async function allowDiscard() {
  sync();
  if (!dirty()) return true;
  const answer = await askUnsaved();
  return (
    answer === "discard" ||
    (answer === "save" && (await saveDocument(false)) && !dirty())
  );
}
async function action(fn, allowLoading = false) {
  if (busy || (!ready && !allowLoading)) return;
  busy = true;
  updateControls();
  try {
    await fn();
  } catch (error) {
    status(`操作失败：${error.message || error}`, true);
  } finally {
    busy = false;
    updateControls();
  }
}
async function saveDocument(saveAs) {
  sync();
  const snapshot = content;
  let destination = path;
  if (native) {
    if (saveAs || !destination)
      destination = await save({ defaultPath: path || name, filters });
    if (!destination) return false;
    await writeTextFile(destination, snapshot);
    path = destination;
    name = basename(destination);
  } else {
    const link = document.createElement("a");
    const url = URL.createObjectURL(
      new Blob([snapshot], { type: "text/plain;charset=utf-8" }),
    );
    link.href = url;
    link.download = name;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  saved = snapshot;
  sync();
  persistDraft();
  render();
  editor()?.openDocument(
    content,
    editor().documentID,
    {
      anchor: editor()._view.state.selection.main.head,
      scrollTop: editor()._view.scrollDOM.scrollTop,
    },
    /\.txt$/i.test(name),
  );
  editor()?.setSourceMode(source);
  status(native ? "文档已保存" : "已生成下载文件，请确认浏览器下载完成");
  return true;
}
async function openDocument() {
  if (native) {
    const selected = await open({ multiple: false, filters });
    if (!selected) return;
    const text = await readTextFile(selected);
    if (await allowDiscard()) {
      replaceDocument(text, selected, basename(selected));
      status("文档已打开");
    }
  } else {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = ".md,.markdown,.txt";
    input.onchange = () =>
      action(async () => {
        const file = input.files[0];
        if (!file) return;
        const text = await file.text();
        if (await allowDiscard()) replaceDocument(text, null, file.name);
      });
    input.click();
  }
}
function toggleSearch(show = $("searchbar").hidden) {
  $("searchbar").hidden = !show;
  if (show) {
    $("query").focus();
    $("query").select();
  } else {
    editor()?.execCommand("find:");
    editor()?._view.focus();
  }
}
function search(command) {
  editor()?.execCommand(
    `findWithOptions:${JSON.stringify({ query: $("query").value, replace: $("replacement").value, caseSensitive: $("match-case").checked, regexp: false })}`,
  );
  if (command) editor()?.execCommand(command);
}
function shortcuts(event) {
  if (
    !(event.ctrlKey || event.metaKey) ||
    event.altKey ||
    $("unsaved").open ||
    $("settings").open
  )
    return;
  const key = event.key.toLowerCase();
  const operations = {
    s: () => action(() => saveDocument(event.shiftKey)),
    o: () => action(openDocument),
    n: () =>
      action(async () => {
        if (await allowDiscard()) replaceDocument("", null, "未命名.md");
      }),
    f: () => toggleSearch(true),
    h: () => toggleSearch(true),
    "\\": () => $("btn-sidebar").click(),
  };
  if (operations[key]) {
    event.preventDefault();
    event.stopPropagation();
    if (ready && !busy) operations[key]();
  }
}
window.addEventListener("keydown", shortcuts, true);
$("btn-new").onclick = () =>
  action(async () => {
    if (await allowDiscard()) replaceDocument("", null, "未命名.md");
  });
$("btn-open").onclick = () => action(openDocument);
$("btn-save").onclick = () => action(() => saveDocument(false));
$("btn-save-as").onclick = () => action(() => saveDocument(true));
$("btn-sidebar").onclick = () => {
  $("sidebar").hidden = !$("sidebar").hidden;
  $("btn-sidebar").setAttribute("aria-expanded", String(!$("sidebar").hidden));
};
$("btn-source").onclick = () => {
  source = !source;
  editor().setSourceMode(source);
  $("btn-source").setAttribute("aria-pressed", String(source));
};
$("btn-search").onclick = () => toggleSearch();
$("close-search").onclick = () => toggleSearch(false);
$("searchbar").onkeydown = (event) => {
  if (event.key === "Escape") toggleSearch(false);
  if (event.key === "Enter") {
    event.preventDefault();
    search(event.shiftKey ? "findPrev" : "findNext");
  }
};
["query", "replacement", "match-case"].forEach((id) =>
  $(id).addEventListener("input", () => search()),
);
document.querySelectorAll("[data-search]").forEach((button) => {
  button.onclick = () => search(button.dataset.search);
});
document.querySelectorAll("[data-command]").forEach((button) => {
  button.onmousedown = (event) => event.preventDefault();
  button.onclick = () => {
    editor()?.execCommand(button.dataset.command);
    editor()?._view.focus();
    sync();
  };
});
async function insertImage(file) {
  const dataURL = await new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
  editor().insertAtCursor(`![图片](${dataURL})`);
  sync();
}
$("btn-image").onclick = () =>
  action(async () => {
    if (native) {
      const selected = await open({
        multiple: false,
        filters: [
          { name: "图片", extensions: ["png", "jpg", "jpeg", "gif", "webp"] },
        ],
      });
      if (!selected) return;
      const extension = selected.split(".").pop().toLowerCase();
      const mime = extension === "jpg" ? "jpeg" : extension;
      await insertImage(
        new Blob([await readFile(selected)], { type: `image/${mime}` }),
      );
    } else {
      const input = document.createElement("input");
      input.type = "file";
      input.accept = "image/png,image/jpeg,image/gif,image/webp";
      input.onchange = () =>
        action(async () => {
          if (input.files[0]) await insertImage(input.files[0]);
        });
      input.click();
    }
  });
$("btn-export").onclick = () =>
  action(async () => {
    sync();
    const exported = await editor().getExportDocument();
    const doc = new DOMParser().parseFromString(exported.html, "text/html");
    for (const image of exported.images) {
      const element = doc.querySelector(`img[src="${image.token}"]`);
      if (element && /^(https?:|data:image\/)/i.test(image.src || ""))
        element.setAttribute("src", image.src);
      else if (element) {
        element.removeAttribute("src");
        element.alt = `图片未嵌入：${image.src || ""}`;
      }
    }
    const html = "<!doctype html>\n" + doc.documentElement.outerHTML;
    const exportName = name.replace(/\.[^.]+$/, "") + ".html";
    if (native) {
      const destination = await save({
        defaultPath: exportName,
        filters: [{ name: "HTML", extensions: ["html"] }],
      });
      if (!destination) return;
      await writeTextFile(destination, html);
    } else {
      const url = URL.createObjectURL(
        new Blob([html], { type: "text/html;charset=utf-8" }),
      );
      const link = document.createElement("a");
      link.href = url;
      link.download = exportName;
      link.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    }
    status("HTML 已导出；相对路径图片需先使用“图片”按钮嵌入。");
  });
$("btn-settings").onclick = () => $("settings").showModal();
$("theme").value = settings.theme;
$("font-size").value = settings.fontSize;
$("line-numbers").checked = settings.showLineNumbers;
$("typewriter").checked = settings.typewriter;
$("settings").onchange = () => {
  settings = {
    theme: $("theme").value,
    fontSize: Number($("font-size").value),
    showLineNumbers: $("line-numbers").checked,
    typewriter: $("typewriter").checked,
  };
  applySettings();
};
matchMedia("(prefers-color-scheme: dark)").addEventListener(
  "change",
  applySettings,
);
window.addEventListener("beforeunload", (event) => {
  sync();
  persistDraft();
  if (!native && dirty()) {
    event.preventDefault();
    event.returnValue = "";
  }
});
if (native)
  getCurrentWindow()
    .onCloseRequested(async (event) => {
      event.preventDefault();
      await action(async () => {
        if (await allowDiscard()) {
          clearTimeout(draftTimer);
          localStorage.removeItem("mnotes.draft");
          await getCurrentWindow().destroy();
        }
      }, true);
    })
    .catch((error) => status(`无法启用关闭保护：${error}`, true));
function hibernateEditor() {
  if (foreground || sleepingSession) return;
  if (busy || !ready || $("unsaved").open) {
    sleepTimer = setTimeout(hibernateEditor, 60000);
    return;
  }
  try {
    const snapshot = editor().captureSession();
    if (!snapshot) {
      sleepTimer = setTimeout(hibernateEditor, 60000);
      return;
    }
    sync();
    clearTimeout(draftTimer);
    persistDraft();
    sleepingSession = snapshot;
    ready = false;
    frame.src = "about:blank";
    status("后台休眠中，返回后自动恢复");
    render();
  } catch (error) {
    status(`暂未进入休眠：${error.message}`, true);
  }
}
function setActivity(active) {
  const wasForeground = foreground;
  foreground = active;
  clearInterval(pollTimer);
  pollTimer = null;
  clearTimeout(sleepTimer);
  sleepTimer = null;
  if (active) {
    if (sleepingSession) frame.src = "editor/editor.html";
    else editor()?.setBackgrounded(false);
    pollTimer = setInterval(sync, 250);
    if (!wasForeground) status("已返回前台");
  } else {
    sync();
    clearTimeout(draftTimer);
    persistDraft();
    editor()?.setBackgrounded(true);
    if (!sleepingSession)
      sleepTimer = setTimeout(hibernateEditor, backgroundSleepDelay);
  }
}
document.addEventListener("visibilitychange", () =>
  setActivity(!document.hidden && nativeFocused),
);
if (native)
  getCurrentWindow()
    .onFocusChanged(({ payload }) => {
      nativeFocused = payload;
      setActivity(payload && !document.hidden);
    })
    .catch((error) => status(`后台节能监听失败：${error}`, true));
setActivity(foreground);
applySettings();
render();
