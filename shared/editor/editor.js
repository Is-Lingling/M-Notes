/**
 * MarkdownNotes Editor — Main JavaScript
 * WYSIWYG Markdown editor powered by CodeMirror 6 + markdown-it
 *
 * Architecture:
 *  - CodeMirror 6: Core editor engine (source mode + WYSIWYG mode)
 *  - markdown-it: Markdown parsing & rendering
 *  - KaTeX: Math formula rendering
 *  - Mermaid: Diagram rendering
 *  - highlight.js: Code syntax highlighting
 *  - Swift Bridge: webkit.messageHandlers for Swift↔JS communication
 */

"use strict";

// ============================================================
// Swift Bridge Helpers
// ============================================================
const swift = {
  send(handler, body) {
    if (window.webkit?.messageHandlers?.[handler]) {
      window.webkit.messageHandlers[handler].postMessage(body);
    }
  },
};

// ============================================================
// markdown-it Setup
// ============================================================
const md = window.markdownit({
  html: true,
  linkify: true,
  typographer: true,
  highlight(str, lang) {
    if (lang && hljs.getLanguage(lang)) {
      try {
        return `<pre class="hljs"><code>${hljs.highlight(str, { language: lang, ignoreIllegals: true }).value}</code></pre>`;
      } catch (_) {}
    }
    return `<pre class="hljs"><code>${md.utils.escapeHtml(str)}</code></pre>`;
  },
})
  .use(window.markdownitTaskLists, { enabled: true, label: true })
  .use(markdownItMath)
  .use(markdownItMermaid);
md.disable(["lheading"]);

// ── math plugin ──
function markdownItMath(md) {
  // Inline math $...$
  md.inline.ruler.after("escape", "math_inline", (state, silent) => {
    if (state.src[state.pos] !== "$") return false;
    const start = state.pos + 1;
    const end = state.src.indexOf("$", start);
    if (end === -1) return false;
    if (!silent) {
      const token = state.push("math_inline", "", 0);
      token.markup = "$";
      token.content = state.src.slice(start, end);
    }
    state.pos = end + 1;
    return true;
  });

  // Block math $$...$$
  md.block.ruler.after("fence", "math_block", (state, start, end, silent) => {
    const pos = state.bMarks[start] + state.tShift[start];
    const max = state.eMarks[start];
    if (state.src.slice(pos, pos + 2) !== "$$") return false;
    if (silent) return true;

    // Check single-line block math: "$$ formula $$"
    const firstLineTrimmed = state.src.slice(pos, max).trim();
    if (firstLineTrimmed.length > 4 && firstLineTrimmed.endsWith("$$")) {
      const token = state.push("math_block", "", 0);
      token.block = true;
      token.markup = "$$";
      token.content = firstLineTrimmed.slice(2, -2).trim();
      state.line = start + 1;
      return true;
    }

    let nextLine = start + 1;
    while (nextLine < end) {
      const lineStart = state.bMarks[nextLine] + state.tShift[nextLine];
      const lineEnd = state.eMarks[nextLine];
      if (state.src.slice(lineStart, lineEnd).trim() === "$$") break;
      nextLine++;
    }
    const content = state.getLines(start + 1, nextLine, 0, true);
    const token = state.push("math_block", "", 0);
    token.block = true;
    token.markup = "$$";
    token.content = content;
    state.line = nextLine + 1;
    return true;
  });

  md.renderer.rules.math_inline = (tokens, idx) => {
    try {
      return katex.renderToString(tokens[idx].content, { throwOnError: false });
    } catch (e) {
      return `<code>${md.utils.escapeHtml(tokens[idx].content)}</code>`;
    }
  };

  md.renderer.rules.math_block = (tokens, idx) => {
    try {
      return `<div class="md-math-block">${katex.renderToString(tokens[idx].content, {
        throwOnError: false, displayMode: true
      })}</div>`;
    } catch (e) {
      return `<pre>${md.utils.escapeHtml(tokens[idx].content)}</pre>`;
    }
  };
}

// ── mermaid plugin ──
function markdownItMermaid(md) {
  const defaultFence = md.renderer.rules.fence?.bind(md.renderer) ||
    ((tokens, idx, options, env, self) => self.renderToken(tokens, idx, options));

  md.renderer.rules.fence = (tokens, idx, options, env, self) => {
    const token = tokens[idx];
    if (token.info.trim().toLowerCase() === "mermaid") {
      const id = `mermaid_${idx}_${Date.now()}`;
      setTimeout(() => {
        const el = document.getElementById(id);
        if (el) {
          renderMermaid(`svg_${id}`, token.content.trim()).then(({ svg }) => {
            el.innerHTML = svg;
          }).catch(e => {
            const tempErr = document.getElementById(`dsvg_${id}`);
            if (tempErr) tempErr.remove();
            el.textContent = "Diagram error: " + (e.message || String(e));
          });
        }
      }, 50);
      return `<div class="md-mermaid" id="${id}"><span>Loading diagram…</span></div>`;
    }
    return defaultFence(tokens, idx, options, env, self);
  };
}

// ============================================================
// Mermaid is optional: ordinary Markdown/TXT does not need its parser/runtime.
// Share one in-flight load, and allow retry after a failed resource load.
// ============================================================
let mermaidLoadPromise = null;
function configureMermaid() {
  window.mermaid?.initialize({
    startOnLoad: false,
    theme: window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "default",
    securityLevel: "loose",
    fontFamily: "-apple-system, 'SF Pro Text', sans-serif",
  });
}
function ensureMermaid() {
  if (window.mermaid) return Promise.resolve(window.mermaid);
  if (!mermaidLoadPromise) {
    mermaidLoadPromise = new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = "mermaid/mermaid.min.js";
      script.onload = () => {
        if (!window.mermaid) { script.remove(); reject(new Error("Mermaid did not initialize")); return; }
        configureMermaid();
        resolve(window.mermaid);
      };
      script.onerror = () => { script.remove(); reject(new Error("Unable to load Mermaid")); };
      document.head.appendChild(script);
    }).catch(error => { mermaidLoadPromise = null; throw error; });
  }
  return mermaidLoadPromise;
}
async function renderMermaid(id, code) {
  const renderer = await ensureMermaid();
  return renderer.render(id, code);
}

// ============================================================
// WYSIWYG Editor State
// ============================================================
let editorState = {
  content: "",
  isSourceMode: false,
  backgrounded: false,
  hostBackgrounded: false,
  isTypewriterMode: false,
  isReady: false,
  language: "zh-Hans",
  preferences: { showLineNumbers: false, spellCheck: true, smartQuotes: true, smartDashes: true },
};

const uiStrings = {
  "zh-Hans": {
    taskDone: "点击标记为未完成", taskOpen: "点击标记为完成", editMath: "点击编辑公式源码", editMermaid: "点击编辑图表源码",
    selectCode: "点击选中整个代码块，按 Delete 删除", copy: "复制", copied: "已复制 ✓",
    imagePath: "点击选中图片并显示路径，按 Delete 删除", imageMissing: "无法加载图片", imageHint: "点击选中并显示图片路径",
    imagePathLabel: "图片文件路径", tableActions: "表格操作", selectTable: "点击空白处选中整个表格，按 Delete 删除",
    addRow: "＋ 行", addRowTitle: "在当前行下方插入行 · ⌘⌥↓", removeRow: "− 行", removeRowTitle: "删除当前内容行 · ⌘⌥⌫",
    addColumn: "＋ 列", addColumnTitle: "在当前列右侧插入列 · ⌘⌥→", removeColumn: "− 列", removeColumnTitle: "删除当前列 · ⌘⌥⇧⌫",
    tableHint: "Tab 切换单元格", rowColumn: (r, c) => `第 ${r} 行，第 ${c} 列`, diagramError: "图表无法渲染", imageExportMissing: "图片无法加载"
  },
  en: {
    taskDone: "Mark as incomplete", taskOpen: "Mark as complete", editMath: "Edit equation source", editMermaid: "Click to edit diagram source",
    selectCode: "Select this code block; press Delete to remove it", copy: "Copy", copied: "Copied ✓",
    imagePath: "Click to select and show path; Delete to remove", imageMissing: "Image unavailable", imageHint: "Click to select and show the image path",
    imagePathLabel: "Image file path", tableActions: "Table actions", selectTable: "Select this table; press Delete to remove it",
    addRow: "+ Row", addRowTitle: "Insert a row below · ⌘⌥↓", removeRow: "− Row", removeRowTitle: "Delete current row · ⌘⌥⌫",
    addColumn: "+ Column", addColumnTitle: "Insert a column to the right · ⌘⌥→", removeColumn: "− Column", removeColumnTitle: "Delete current column · ⌘⌥⇧⌫",
    tableHint: "Tab moves between cells", rowColumn: (r, c) => `Row ${r}, column ${c}`, diagramError: "Diagram could not be rendered", imageExportMissing: "Image unavailable"
  }
};
function ui(key, ...args) {
  const value = (uiStrings[editorState.language] || uiStrings["zh-Hans"])[key];
  return typeof value === "function" ? value(...args) : value;
}

// ============================================================
// CodeMirror 6 Setup
// ============================================================
const { EditorView, keymap, highlightSpecialChars, drawSelection,
        dropCursor, rectangularSelection, crosshairCursor,
        highlightActiveLine, highlightActiveLineGutter,
        lineNumbers, lineNumberWidgetMarker, GutterMarker, Decoration, ViewPlugin, WidgetType } = CM.view;
const { EditorState, StateEffect, StateField, Compartment, RangeSetBuilder } = CM.state;
const { defaultKeymap, historyKeymap, history } = CM.commands;
const { markdown, markdownLanguage } = CM.lang_markdown;
const { syntaxHighlighting, defaultHighlightStyle, HighlightStyle, syntaxTree } = CM.language;
const { tags } = CM.highlight;
const { searchKeymap, search } = CM.search;
const { lintKeymap } = CM.lint;

// ── Theme-aware WYSIWYG rendering ──
const wysiwygTheme = EditorView.theme({
  "&": {
    backgroundColor: "transparent",
    height: "100%",
  },
  ".cm-content": {
    fontFamily: "var(--font-body)",
    fontSize: "var(--font-size)",
    lineHeight: "var(--line-height)",
    caretColor: "var(--accent)",
  },
  ".cm-cursor, .cm-dropCursor": {
    borderLeftColor: "var(--accent)",
    borderLeftWidth: "2px",
  },
  ".cm-selectionBackground, ::selection": {
    backgroundColor: "var(--selection-bg) !important",
  },
  ".cm-gutters": {
    backgroundColor: "transparent",
    border: "none",
    color: "var(--text-tertiary)",
  },
  ".cm-activeLineGutter": { backgroundColor: "var(--accent-dim)" },
  ".cm-activeLine": { backgroundColor: "var(--accent-dim)" },
}, { dark: window.matchMedia("(prefers-color-scheme: dark)").matches });

// ── WYSIWYG markdown syntax highlight style ──
const markdownHighlight = HighlightStyle.define([
  { tag: tags.heading1, fontSize: "1.45em", fontWeight: "700", color: "var(--heading-color)" },
  { tag: tags.heading2, fontSize: "1.25em", fontWeight: "600", color: "var(--heading-color)" },
  { tag: tags.heading3, fontSize: "1.12em", fontWeight: "600", color: "var(--heading-color)" },
  { tag: tags.heading4, fontSize: "1.04em", fontWeight: "600", color: "var(--text-secondary)" },
  { tag: tags.heading5, fontSize: "0.96em", fontWeight: "600", color: "var(--text-secondary)" },
  { tag: tags.heading6, fontSize: "0.9em", fontWeight: "600", color: "var(--text-tertiary)" },
  { tag: tags.strong, fontWeight: "700" },
  { tag: tags.emphasis, fontStyle: "italic" },
  { tag: tags.strikethrough, textDecoration: "line-through", color: "var(--text-tertiary)" },
  { tag: tags.link, color: "var(--link)", textDecoration: "underline" },
  { tag: tags.url, color: "var(--link)" },
  { tag: tags.monospace, fontFamily: "var(--font-mono)", fontSize: "0.875em",
    background: "var(--code-bg)", padding: "0.1em 0.3em", borderRadius: "3px", color: "#E83E8C" },
  { tag: tags.blockComment, color: "var(--text-tertiary)", fontStyle: "italic" },
  { tag: tags.lineComment, color: "var(--text-tertiary)" },
  { tag: tags.processingInstruction, color: "var(--text-tertiary)" },
  { tag: tags.meta, color: "var(--text-tertiary)" },
  { tag: tags.atom, color: "var(--accent)" },
  { tag: tags.keyword, color: "#AF52DE" },
  { tag: tags.string, color: "#D73A49" },
  { tag: tags.number, color: "#005CC5" },
  { tag: tags.bool, color: "#005CC5" },
  { tag: tags.comment, color: "#6A737D", fontStyle: "italic" },
  { tag: tags.function(tags.variableName), color: "#6F42C1" },
  { tag: tags.typeName, color: "#E36209" },
  { tag: tags.operator, color: "#D73A49" },
  { tag: tags.punctuation, color: "var(--text-tertiary)" },
]);

// Compartments for dynamic config
const lineNumbersComp = new Compartment();
const readOnlyComp = new Compartment();
const languageComp = new Compartment();
const historyComp = new Compartment();
const revealLine = StateEffect.define();
const editingLine = StateField.define({
  create: state => (state?.selection?.main ? state.selection.main.head : 0),
  update(value, tr) {
    for (const effect of tr.effects) if (effect.is(revealLine)) return effect.value;
    if (tr.selection || tr.docChanged) return tr.state.selection.main.head;
    return tr.changes.mapPos(value);
  },
});
function selectBlock(view, from, to) {
  view.dispatch({ selection: { anchor: from, head: to }, userEvent: "select.block" });
  view.focus();
}

// ============================================================
// Typora Interactive Widgets (Checklist, Math, Code Header)
// ============================================================

// Keep block margins inside the DOM that CodeMirror measures. External vertical
// margins are absent from its height map, shifting gutters and pointer hit testing.
function measuredBlockWidget(content) {
  const outer = document.createElement("div");
  outer.className = "cm-measured-block";
  outer.appendChild(content);
  return outer;
}

// 1. 原生备忘录琥珀黄圆圈任务列表 Widget
class TaskWidget extends WidgetType {
  constructor(checked, from, to) {
    super();
    this.checked = checked;
    this.from = from;
    this.to = to;
  }
  eq(other) {
    return this.checked === other.checked && this.from === other.from && this.to === other.to;
  }
  toDOM(view) {
    const circle = document.createElement("span");
    circle.className = "cm-task-circle";
    circle.dataset.checked = this.checked ? "true" : "false";
    circle.setAttribute("role", "checkbox");
    circle.setAttribute("aria-checked", String(this.checked));
    circle.title = this.checked ? ui("taskDone") : ui("taskOpen");
    circle.addEventListener("mousedown", (e) => {
      e.preventDefault();
      e.stopPropagation();
      const newText = this.checked ? "[ ]" : "[x]";
      view.dispatch({
        changes: { from: this.from, to: this.to, insert: newText },
      });
    });
    return circle;
  }
  ignoreEvent() { return true; }
}

// 2. LaTeX 数学公式即时渲染 Widget（点击就地展开源码编辑）
class MathWidget extends WidgetType {
  constructor(formula, isBlock, from, to) {
    super();
    this.formula = formula;
    this.isBlock = isBlock;
    this.from = from;
    this.to = to;
  }
  eq(other) {
    return this.formula === other.formula && this.isBlock === other.isBlock && this.from === other.from && this.to === other.to;
  }
  toDOM(view) {
    const el = document.createElement(this.isBlock ? "div" : "span");
    el.className = `cm-math-widget ${this.isBlock ? "cm-math-block" : "cm-math-inline"}`;
    el.title = ui("editMath");
    try {
      el.innerHTML = katex.renderToString(this.formula, {
        displayMode: this.isBlock,
        throwOnError: false,
      });
    } catch (_) {
      el.textContent = (this.isBlock ? "$$\n" : "$") + this.formula + (this.isBlock ? "\n$$" : "$");
    }
    el.addEventListener("mousedown", (e) => {
      e.preventDefault();
      e.stopPropagation();
      // 就地定位光标展开公式源码供编辑
      const targetPos = Math.min(this.from + (this.isBlock ? 2 : 1), this.to);
      view.dispatch({
        selection: { anchor: targetPos },
        effects: revealLine.of(this.from),
      });
      view.focus();
    });
    return this.isBlock ? measuredBlockWidget(el) : el;
  }
  ignoreEvent() { return true; }
}

// 2.1 Mermaid 图表即时渲染 Widget（点击就地展开源码编辑）
class MermaidWidget extends WidgetType {
  constructor(code, from, to) {
    super();
    this.code = code;
    this.from = from;
    this.to = to;
  }
  eq(other) {
    return this.code === other.code && this.from === other.from && this.to === other.to;
  }
  toDOM(view) {
    const wrap = document.createElement("div");
    wrap.className = "cm-mermaid-widget md-mermaid";
    wrap.title = ui("editMermaid");

    const container = document.createElement("div");
    container.className = "cm-mermaid-content";
    container.innerHTML = `<span class="cm-mermaid-loading">Loading diagram…</span>`;
    wrap.appendChild(container);

    wrap.addEventListener("mousedown", (e) => {
      e.preventDefault();
      e.stopPropagation();
      // 点击展开 Mermaid 源码
      const line = view.state.doc.lineAt(this.from);
      const targetPos = Math.min(line.to + 1, this.to);
      view.dispatch({
        selection: { anchor: targetPos },
        effects: revealLine.of(this.from),
      });
      view.focus();
    });

    const id = "mmd_" + Math.random().toString(36).slice(2, 10);
    try {
      renderMermaid(id, this.code).then(({ svg }) => {
        container.innerHTML = svg;
        view.requestMeasure();
      }).catch((err) => {
        const tempErr = document.getElementById("d" + id);
        if (tempErr) tempErr.remove();
        container.innerHTML = `<div class="cm-mermaid-error"><div style="font-weight:600;margin-bottom:6px;color:var(--danger,#e11d48)">⚠️ Mermaid 图表解析错误</div><pre style="margin:0;font-size:12px;white-space:pre-wrap">${md.utils.escapeHtml(err.message || String(err))}</pre></div>`;
        view.requestMeasure();
      });
    } catch (err) {
      container.innerHTML = `<div class="cm-mermaid-error"><pre style="margin:0;font-size:12px;white-space:pre-wrap">${md.utils.escapeHtml(err.message || String(err))}</pre></div>`;
    }

    return measuredBlockWidget(wrap);
  }
  ignoreEvent() { return true; }
}

// A closing fence belongs to the source selection, but has no preview row.
class HiddenFenceWidget extends WidgetType {
  eq() { return true; }
  toDOM() {
    const el = document.createElement("div");
    el.className = "cm-hidden-fence";
    return el;
  }
  get estimatedHeight() { return 0; }
  ignoreEvent() { return true; }
}

// 3. 代码块语言标签与一键复制 Widget（就地替换 fence 行文本，保证 DOM 行 1:1 映射）
class CodeHeaderWidget extends WidgetType {
  constructor(lang, code, from, to) {
    super();
    this.lang = (lang || "CODE").toUpperCase();
    this.code = code;
    this.from = from;
    this.to = to;
  }
  eq(other) {
    return this.lang === other.lang && this.code === other.code && this.from === other.from && this.to === other.to;
  }
  toDOM(view) {
    const header = document.createElement("span");
    header.className = "cm-code-header-widget";
    header.title = ui("selectCode");
    header.dataset.blockFrom = this.from;
    header.dataset.blockTo = this.to;
    header.addEventListener("mousedown", e => {
      if (e.target.closest("button")) return;
      e.preventDefault();
      selectBlock(view, this.from, this.to);
    });

    const langLabel = document.createElement("span");
    langLabel.className = "cm-code-lang";
    langLabel.textContent = this.lang;
    header.appendChild(langLabel);

    const copyBtn = document.createElement("button");
    copyBtn.className = "cm-code-copy-btn";
    copyBtn.textContent = ui("copy");
    copyBtn.addEventListener("mousedown", (e) => {
      e.preventDefault();
      e.stopPropagation();
      navigator.clipboard.writeText(this.code).then(() => {
        copyBtn.textContent = ui("copied");
        setTimeout(() => { copyBtn.textContent = ui("copy"); }, 1600);
      });
    });
    header.appendChild(copyBtn);

    return header;
  }
  ignoreEvent() { return true; }
}

// Whitespace around an image-only source line must not push a full-width
// inline widget onto a second visual row. Preserve it in the document.
function hideImageIndent(items, line, from, to) {
  if (line.text.slice(0, from - line.from).trim() || line.text.slice(to - line.from).trim()) return;
  if (from > line.from) items.push({ from: line.from, to: from, deco: Decoration.replace({}) });
  if (to < line.to) items.push({ from: to, to: line.to, deco: Decoration.replace({}) });
}

// 4. 图片即时渲染 Widget（单击选中完整语法并显示路径浮层）
class ImageWidget extends WidgetType {
  constructor(alt, src, from, to) {
    super();
    this.alt = alt;
    this.src = src;
    this.from = from;
    this.to = to;
  }
  eq(other) {
    return this.alt === other.alt && this.src === other.src && this.from === other.from && this.to === other.to;
  }
  toDOM(view) {
    const wrap = document.createElement("span");
    wrap.className = "cm-image-widget";
    wrap.dataset.imageFrom = this.from;
    wrap.dataset.imageTo = this.to;
    wrap.title = ui("imagePath");

    let resolvedSrc = (this.src || "").trim();
    if (resolvedSrc.startsWith("file://") || resolvedSrc.startsWith("http://") || resolvedSrc.startsWith("https://") || resolvedSrc.startsWith("data:")) {
      // Direct URI format
    } else if (resolvedSrc.startsWith("/")) {
      resolvedSrc = "file://" + encodeURI(resolvedSrc);
    } else if (window.currentDocDir) {
      const baseDir = window.currentDocDir.replace(/\/$/, "");
      resolvedSrc = "file://" + encodeURI(baseDir + "/" + resolvedSrc);
    }

    // Native WebKit reads note images separately from the bundled editor resources.
    if (window.localImageScheme && resolvedSrc.startsWith("file://")) {
      const fileURL = new URL(resolvedSrc);
      resolvedSrc = `${window.localImageScheme}://local${fileURL.pathname}`;
    }

    const img = document.createElement("img");
    img.className = "cm-rendered-image";
    img.draggable = false;
    img.src = resolvedSrc;
    img.alt = this.alt;
    img.onload = () => {
      try { view?.requestMeasure(); } catch (_) {}
    };
    img.onerror = () => {
      wrap.classList.add("cm-image-error");
      img.hidden = true;
      const placeholder = document.createElement("span");
      placeholder.className = "cm-image-placeholder";
      const icon = placeholder.appendChild(document.createElement("span"));
      icon.className = "cm-image-placeholder-icon";
      icon.setAttribute("aria-hidden", "true");
      icon.innerHTML = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="3" y="3" width="18" height="18" rx="3"/><circle cx="8" cy="8" r="1.5"/><path d="m3 17 5-5 4 4 3-3 6 6"/></svg>';
      const label = placeholder.appendChild(document.createElement("span"));
      const title = label.appendChild(document.createElement("strong"));
      title.textContent = ui("imageMissing");
      const hint = label.appendChild(document.createElement("span"));
      hint.textContent = ui("imageHint");
      wrap.prepend(placeholder);
      view.requestMeasure();
    };

    wrap.appendChild(img);

    const path = document.createElement("input");
    path.className = "cm-image-path";
    path.type = "text";
    path.value = this.src;
    path.setAttribute("aria-label", ui("imagePathLabel"));
    path.hidden = true;
    wrap.appendChild(path);
    wrap.addEventListener("mousedown", e => {
      e.stopPropagation();
      if (e.target === path) return;
      e.preventDefault();
      const from = view.posAtDOM(wrap);
      view.dispatch({ selection: { anchor: from, head: from + this.to - this.from }, userEvent: "select.image" });
      view.focus();
    });
    path.addEventListener("keydown", e => {
      e.stopPropagation();
      if (e.key === "Enter") {
        e.preventDefault();
        path.blur();
        view.focus();
      } else if (e.key === "Escape") {
        path.value = this.src;
        path.blur();
        view.focus();
      }
    });
    path.addEventListener("blur", () => {
      const next = path.value.trim();
      if (next && next !== this.src) {
        const from = view.posAtDOM(wrap);
        const source = view.state.doc.sliceString(from, from + this.to - this.from);
        const offset = source.indexOf("](") + 2;
        view.dispatch({ changes: { from: from + offset, to: from + source.length - 1,
          insert: next.replace(/ /g, "%20").replace(/\(/g, "%28").replace(/\)/g, "%29") } });
      }
      path.hidden = true;
      view.requestMeasure();
    });

    return wrap;
  }
  get estimatedHeight() { return 160; }
  ignoreEvent() { return true; }
}

// Tables use block decorations so their measured height participates in layout.
function tableCells(line) {
  const pipes = [];
  for (let i = 0; i < line.text.length; i++) {
    if (line.text[i] !== "|") continue;
    let slashes = 0;
    for (let j = i - 1; j >= 0 && line.text[j] === "\\"; j--) slashes++;
    if (slashes % 2 === 0) pipes.push(i);
  }
  if (!pipes.length) return null;
  const bounds = [-1, ...pipes, line.text.length];
  const cells = bounds.slice(0, -1).map((p, i) => {
    const raw = line.text.slice(p + 1, bounds[i + 1]);
    const leading = raw.length - raw.trimStart().length;
    return { text: raw.trim(), from: line.from + p + 1 + leading,
      to: line.from + p + 1 + Math.max(leading, raw.trimEnd().length) };
  });
  if (!line.text.slice(0, pipes[0]).trim()) cells.shift();
  if (!line.text.slice(pipes.at(-1) + 1).trim()) cells.pop();
  return cells.length ? cells : null;
}

function readTable(state, firstLine) {
  if (firstLine.number >= state.doc.lines) return null;
  const header = tableCells(firstLine);
  const separator = tableCells(state.doc.line(firstLine.number + 1));
  if (!header || !separator || header.length !== separator.length ||
      !separator.every(c => /^:?-+:?$/.test(c.text))) return null;
  const rows = [{ line: firstLine, cells: header }];
  let lastLine = state.doc.line(firstLine.number + 1);
  for (let n = firstLine.number + 2; n <= state.doc.lines; n++) {
    const line = state.doc.line(n), cells = tableCells(line);
    if (!cells || cells.length > header.length) break;
    while (cells.length < header.length) cells.push({ text: "", from: line.to, to: line.to });
    rows.push({ line, cells });
    lastLine = line;
  }
  return { from: firstLine.from, to: lastLine.to, rows,
    separators: separator.map(c => c.text), source: state.doc.sliceString(firstLine.from, lastLine.to) };
}

const tableInlineMarkdown = window.markdownit({ html: false, breaks: false });
class TableWidget extends WidgetType {
  constructor(model) { super(); this.model = model; }
  eq(other) { return this.model.from === other.model.from && this.model.source === other.model.source; }
  updateDOM(dom) {
    dom = dom.firstElementChild;
    const old = dom._tableModel;
    if (old.rows.length !== this.model.rows.length || old.separators.length !== this.model.separators.length) return false;
    dom._tableModel = this.model;
    dom.dataset.tableFrom = this.model.from;
    dom.querySelectorAll("input").forEach(input => {
      const cell = this.model.rows[+input.dataset.row].cells[+input.dataset.col];
      if (!dom._typing) input.value = cell.text.replace(/\\\|/g, "|");
      input.previousElementSibling.innerHTML = tableInlineMarkdown.renderInline(cell.text) || "&nbsp;";
    });
    return true;
  }
  toDOM(view) {
    const wrap = document.createElement("div");
    wrap.className = "cm-live-table";
    wrap.dataset.tableFrom = this.model.from;
    wrap._tableModel = this.model;
    wrap._activeCell = [Math.min(1, this.model.rows.length - 1), 0];
    const toolbar = wrap.appendChild(document.createElement("div"));
    toolbar.className = "cm-table-toolbar";
    toolbar.setAttribute("role", "toolbar");
    toolbar.setAttribute("aria-label", ui("tableActions"));
    toolbar.title = ui("selectTable");
    toolbar.addEventListener("mousedown", e => {
      if (e.target.closest("button")) return;
      e.preventDefault();
      selectBlock(view, wrap._tableModel.from, wrap._tableModel.to);
      wrap.classList.add("cm-block-selected");
    });
    const actions = [
      ["addRow", ui("addRow"), ui("addRowTitle")],
      ["removeRow", ui("removeRow"), ui("removeRowTitle")],
      ["addColumn", ui("addColumn"), ui("addColumnTitle")],
      ["removeColumn", ui("removeColumn"), ui("removeColumnTitle")],
    ];
    for (const [action, label, title] of actions) {
      const button = toolbar.appendChild(document.createElement("button"));
      button.type = "button";
      button.textContent = label;
      button.title = title;
      button.setAttribute("aria-label", title.split(" · ")[0]);
      button.dataset.action = action;
      button.addEventListener("mousedown", e => e.preventDefault());
      button.addEventListener("click", () => changeTable(view, wrap, action));
    }
    const hint = toolbar.appendChild(document.createElement("span"));
    hint.className = "cm-table-hint";
    hint.textContent = ui("tableHint");
    const scroller = wrap.appendChild(document.createElement("div"));
    scroller.className = "cm-table-scroll";
    const table = scroller.appendChild(document.createElement("table"));
    table.style.minWidth = `${this.model.separators.length * 120}px`;
    this.model.rows.forEach((row, r) => {
      const tr = table.appendChild(document.createElement("tr"));
      row.cells.forEach((cell, c) => {
        const td = tr.appendChild(document.createElement(r === 0 ? "th" : "td"));
        const alignment = this.model.separators[c];
        td.style.textAlign = alignment.endsWith(":") ? (alignment.startsWith(":") ? "center" : "right") : "left";
        const preview = td.appendChild(document.createElement("span"));
        preview.className = "cm-table-cell-preview";
        preview.innerHTML = tableInlineMarkdown.renderInline(cell.text) || "&nbsp;";
        const input = td.appendChild(document.createElement("input"));
        input.type = "text";
        input.value = cell.text.replace(/\\\|/g, "|");
        input.dataset.row = r;
        input.dataset.col = c;
        input.setAttribute("aria-label", ui("rowColumn", r + 1, c + 1));
        td.addEventListener("mousedown", e => {
          if (e.target !== input) { e.preventDefault(); input.focus(); }
        });
        input.addEventListener("focus", () => {
          wrap._activeCell = [r, c];
          updateTableButtons(wrap);
          const pos = wrap._tableModel.rows[r].cells[c].from;
          if (view.state.selection.main.head !== pos) view.dispatch({ selection: { anchor: pos } });
        });
        input.addEventListener("input", () => {
          const model = wrap._tableModel;
          const target = model.rows[r].cells[c];
          const text = input.value.replace(/\|/g, "\\|").replace(/[\r\n]/g, " ");
          wrap._typing = true;
          try {
            // Pad incomplete Markdown rows before editing their absent cells.
            if (target.from === model.rows[r].line.to && tableCells(model.rows[r].line).length <= c) {
              changeTable(view, wrap, "setCell", text);
            } else {
              view.dispatch({ changes: { from: target.from, to: target.to, insert: text }, userEvent: "input.type" });
            }
          } finally { wrap._typing = false; }
        });
        input.addEventListener("keydown", e => {
          const mod = e.metaKey || e.ctrlKey;
          let action;
          if (mod && e.altKey) {
            if (e.key === "ArrowDown") action = "addRow";
            if (e.key === "ArrowRight") action = "addColumn";
            if (e.key === "Backspace") action = e.shiftKey ? "removeColumn" : "removeRow";
          }
          if (action) { e.preventDefault(); changeTable(view, wrap, action); }
          else if (mod && e.key.toLowerCase() === "z") {
            e.preventDefault();
            (e.shiftKey ? CM.commands.redo : CM.commands.undo)(view);
            focusTableCell(view, wrap._tableModel.from, r, c);
          } else if (e.key === "Tab" || e.key === "Enter") {
            e.preventDefault();
            const model = wrap._tableModel;
            const step = e.shiftKey ? -1 : 1;
            const index = r * model.separators.length + c + (e.key === "Enter" ? step * model.separators.length : step);
            if (index >= model.rows.length * model.separators.length) changeTable(view, wrap, "addRow");
            else if (index >= 0) focusTableCell(view, model.from, Math.floor(index / model.separators.length), index % model.separators.length);
            else { input.blur(); view.dispatch({ selection: { anchor: model.from } }); view.focus(); }
          } else if (e.key === "Escape") {
            e.preventDefault(); input.blur(); view.focus();
          }
          e.stopPropagation();
        });
      });
    });
    updateTableButtons(wrap);
    return measuredBlockWidget(wrap);
  }
  ignoreEvent() { return true; }
  get estimatedHeight() { return 50 + this.model.rows.length * 38; }
}

function updateTableButtons(wrap) {
  wrap.querySelector('[data-action="removeRow"]').disabled = wrap._activeCell[0] === 0;
  wrap.querySelector('[data-action="removeColumn"]').disabled = wrap._tableModel.separators.length <= 1;
}
function focusTableCell(view, from, row, col) {
  requestAnimationFrame(() => {
    const wrap = view.dom.querySelector(`[data-table-from="${from}"]`);
    if (!wrap) return;
    const r = Math.min(row, wrap._tableModel.rows.length - 1), c = Math.min(col, wrap._tableModel.separators.length - 1);
    wrap.querySelector(`input[data-row="${r}"][data-col="${c}"]`)?.focus();
  });
}
function changeTable(view, wrap, action, text) {
  const model = wrap._tableModel;
  let [r, c] = wrap._activeCell;
  const rows = model.rows.map(row => row.cells.map(cell => cell.text));
  const separators = [...model.separators];
  if (action === "addRow") { rows.splice(++r, 0, separators.map(() => "")); }
  else if (action === "removeRow") {
    if (r === 0) return;
    rows.splice(r, 1); r = Math.min(r, rows.length - 1);
  } else if (action === "addColumn") {
    c++; rows.forEach(row => row.splice(c, 0, "")); separators.splice(c, 0, "---");
  } else if (action === "removeColumn") {
    if (separators.length <= 1) return;
    rows.forEach(row => row.splice(c, 1)); separators.splice(c, 1); c = Math.min(c, separators.length - 1);
  } else if (action === "setCell") rows[r][c] = text;
  const format = row => "| " + row.join(" | ") + " |";
  const lines = [format(rows[0]), format(separators), ...rows.slice(1).map(format)];
  const insert = lines.join("\n");
  view.dispatch({ changes: { from: model.from, to: model.to, insert },
    selection: { anchor: model.from }, userEvent: "input.table" });
  focusTableCell(view, model.from, r, c);
}

// ── Typora Live Preview Plugin (即时渲染与无缝语法展开) ──
const previewBuilder = new (class {
  // 辅助方法：判断某行起始是否处于代码块内部
  isPosInCodeBlock(state, line) {
    try {
      if (typeof syntaxTree === "function") {
        const tree = syntaxTree(state);
        if (tree) {
          let node = tree.resolveInner(line.from, 1);
          while (node) {
            if (node.name === "FencedCode") {
              if (node.from === line.from) return false;
              return true;
            }
            node = node.parent;
          }
          return false;
        }
      }
    } catch (_) {}

    // 回退：向上回溯最近的 fence 行
    let lineNum = line.number - 1;
    while (lineNum >= 1) {
      const prevText = state.doc.line(lineNum).text;
      if (/^```/.test(prevText)) {
        return !/^```\s*$/.test(prevText);
      }
      lineNum--;
    }
    return false;
  }

  // 识别文档中所有块级数学公式 ($$...$$) 的范围
  findBlockMathRanges(state) {
    const blocks = [];
    let inCode = false;
    let inMath = null;

    for (let i = 1; i <= state.doc.lines; i++) {
      const line = state.doc.line(i);
      const text = line.text;

      if (!inMath && /^```/.test(text)) {
        if (!inCode) inCode = true;
        else if (/^```\s*$/.test(text)) inCode = false;
        continue;
      }
      if (inCode) continue;

      const trimmed = text.trim();

      if (!inMath) {
        // 单行独立块级公式: "$$ formula $$"
        if (trimmed.startsWith("$$") && trimmed.length > 2 && trimmed.endsWith("$$")) {
          const formula = trimmed.slice(2, -2).trim();
          if (formula.length > 0) {
            blocks.push({
              from: line.from,
              to: line.to,
              startLine: i,
              endLine: i,
              formula,
            });
          }
          continue;
        }

        // 多行块级公式起始: "$$"
        if (trimmed.startsWith("$$")) {
          const firstLineFormula = trimmed.slice(2).trim();
          inMath = {
            startLine: i,
            from: line.from,
            formulaLines: firstLineFormula ? [firstLineFormula] : [],
          };
          continue;
        }
      } else {
        // 多行块级公式结束: 以 "$$" 结尾
        if (trimmed.endsWith("$$")) {
          const beforeEnd = trimmed.slice(0, -2).trim();
          if (beforeEnd) {
            inMath.formulaLines.push(beforeEnd);
          }
          blocks.push({
            from: inMath.from,
            to: line.to,
            startLine: inMath.startLine,
            endLine: i,
            formula: inMath.formulaLines.join("\n").trim(),
          });
          inMath = null;
          continue;
        } else {
          inMath.formulaLines.push(text);
        }
      }
    }

    return blocks;
  }

  // 识别文档中所有 Mermaid 代码块 (```mermaid ... ```)
  findMermaidBlocks(state) {
    const blocks = [];
    let inOtherCode = false;
    let inMermaid = null;

    for (let i = 1; i <= state.doc.lines; i++) {
      const line = state.doc.line(i);
      const text = line.text;

      if (!inMermaid && !inOtherCode) {
        const match = text.match(/^```([a-zA-Z0-9_-]+)?\s*$/);
        if (match) {
          const lang = (match[1] || "").toLowerCase();
          if (lang === "mermaid") {
            inMermaid = {
              startLine: i,
              from: line.from,
              codeLines: [],
            };
            continue;
          } else {
            inOtherCode = true;
            continue;
          }
        }
      } else if (inOtherCode) {
        if (/^```\s*$/.test(text)) {
          inOtherCode = false;
        }
        continue;
      } else if (inMermaid) {
        if (/^```\s*$/.test(text)) {
          blocks.push({
            startLine: inMermaid.startLine,
            endLine: i,
            from: inMermaid.from,
            to: line.to,
            code: inMermaid.codeLines.join("\n").trim(),
          });
          inMermaid = null;
          continue;
        } else {
          inMermaid.codeLines.push(text);
        }
      }
    }

    return blocks;
  }

  buildDecorations(state) {
    if (editorState.backgrounded || editorState.isSourceMode) {
      return Decoration.none;
    }

    const activeLines = new Set();
    if (state.selection?.ranges) {
      for (const range of state.selection.ranges) {
        const fromLine = state.doc.lineAt(range.from).number;
        const toLine = state.doc.lineAt(range.to).number;
        for (let l = fromLine; l <= toLine; l++) {
          activeLines.add(l);
        }
      }
    }
    const editLinePos = state.field(editingLine, false);
    if (editLinePos != null && editLinePos >= 0 && editLinePos <= state.doc.length) {
      activeLines.add(state.doc.lineAt(editLinePos).number);
    }

    const mathBlocks = this.findBlockMathRanges(state);
    const mathByStartLine = new Map(mathBlocks.map(b => [b.startLine, b]));
    const mathLines = new Set();
    for (const b of mathBlocks) {
      for (let l = b.startLine; l <= b.endLine; l++) mathLines.add(l);
    }

    const mermaidBlocks = this.findMermaidBlocks(state);
    const mermaidByStartLine = new Map(mermaidBlocks.map(b => [b.startLine, b]));
    const mermaidLines = new Set();
    for (const b of mermaidBlocks) {
      for (let l = b.startLine; l <= b.endLine; l++) mermaidLines.add(l);
    }

    const builder = new RangeSetBuilder();

    try {
      for (const { from, to } of [{ from: 0, to: state.doc.length }]) {
        let pos = from;
        let inCodeBlock = this.isPosInCodeBlock(state, state.doc.lineAt(pos));

        while (pos <= to && pos < state.doc.length) {
          const line = state.doc.lineAt(pos);
          const isActive = activeLines.has(line.number);
          const text = line.text;

          // 1. 表格识别
          const table = !inCodeBlock && readTable(state, line);
          if (table) {
            builder.add(table.from, table.to, Decoration.replace({ widget: new TableWidget(table), block: true }));
            pos = table.to + 1;
            continue;
          }

          // 2. Mermaid 图表块识别
          const mermaidBlock = !inCodeBlock && mermaidByStartLine.get(line.number);
          if (mermaidBlock) {
            let hasActive = false;
            for (let l = mermaidBlock.startLine; l <= mermaidBlock.endLine; l++) {
              if (activeLines.has(l)) {
                hasActive = true;
                break;
              }
            }
            if (!hasActive) {
              builder.add(mermaidBlock.from, mermaidBlock.to, Decoration.replace({
                widget: new MermaidWidget(mermaidBlock.code, mermaidBlock.from, mermaidBlock.to),
                block: true,
              }));
              pos = mermaidBlock.to + 1;
              continue;
            }
          }

          // 3. 块级数学公式识别 ($$...$$)
          const mathBlock = !inCodeBlock && mathByStartLine.get(line.number);
          if (mathBlock) {
            let hasActive = false;
            for (let l = mathBlock.startLine; l <= mathBlock.endLine; l++) {
              if (activeLines.has(l)) {
                hasActive = true;
                break;
              }
            }
            if (!hasActive) {
              builder.add(mathBlock.from, mathBlock.to, Decoration.replace({
                widget: new MathWidget(mathBlock.formula, true, mathBlock.from, mathBlock.to),
                block: true,
              }));
              pos = mathBlock.to + 1;
              continue;
            }
          }

          // 如果当前行处于正在编辑的数学公式块内部，直接添加数学源码行样式并跳过常规 Markdown 语法解析
          if (mathLines.has(line.number)) {
            const lineDeco = Decoration.line({ class: "cm-math-source-line" });
            builder.add(line.from, line.from, lineDeco);
            pos = line.to + 1;
            continue;
          }

          // 统合本行所有的行内装饰项（Widgets、Marks、Replacements）
          const lineItems = [];
          let lineDeco = null;

          // 1. 代码块识别
          const fenceOpenMatch = !inCodeBlock ? text.match(/^```([a-zA-Z0-9_-]+)?\s*$/) : null;
          const fenceCloseMatch = inCodeBlock ? text.match(/^```\s*$/) : null;

          if (fenceOpenMatch) {
            inCodeBlock = true;
            lineDeco = Decoration.line({ class: "cm-code-block-header-line" });
            const lang = fenceOpenMatch[1] || "";
            let codeContent = "";
            let nextPos = line.to + 1;
            while (nextPos < state.doc.length) {
              const nextLine = state.doc.lineAt(nextPos);
              if (/^```\s*$/.test(nextLine.text)) break;
              codeContent += nextLine.text + "\n";
              nextPos = nextLine.to + 1;
            }

            // 当光标离开代码块首行时，直接将 ```lang 文本替换为代码块头部栏（语言徽章+复制按钮）
            // 保证 DOM 行 1:1 映射，杜绝 HeightMap 错乱和点击偏移
            if (true) {
              if (line.from < line.to) {
                lineItems.push({
                  from: line.from,
                  to: line.to,
                  deco: Decoration.replace({
                    widget: new CodeHeaderWidget(lang, codeContent, line.from, nextPos < state.doc.length ? state.doc.lineAt(nextPos).to : state.doc.length),
                  }),
                });
              } else {
                lineItems.push({
                  from: line.from,
                  to: line.from,
                  deco: Decoration.widget({
                    widget: new CodeHeaderWidget(lang, codeContent, line.from, nextPos < state.doc.length ? state.doc.lineAt(nextPos).to : state.doc.length),
                    side: 1,
                  }),
                });
              }
            }
          } else if (fenceCloseMatch) {
            inCodeBlock = false;
            builder.add(line.from, line.to, Decoration.replace({ widget: new HiddenFenceWidget(), block: true }));
            pos = line.to + 1;
            continue;
          } else if (inCodeBlock) {
            const nextIsFence = line.number < state.doc.lines && /^```\s*$/.test(state.doc.line(line.number + 1).text);
            lineDeco = Decoration.line({ class: "cm-code-block-line" + (nextIsFence ? " cm-code-block-last" : "") });
          }

          // 2. 标题行识别（仅非代码块时）
          if (!inCodeBlock && !fenceOpenMatch && !fenceCloseMatch) {
            const headingMatch = text.match(/^(#{1,6}\s+)/);
            if (headingMatch) {
              const level = headingMatch[1].trim().length;
              lineDeco = Decoration.line({ class: `cm-heading-${level}` });
              if (!isActive) {
                const markLen = headingMatch[1].length;
                lineItems.push({
                  from: line.from,
                  to: line.from + markLen,
                  deco: Decoration.mark({ class: "cm-md-syntax-hidden" }),
                });
              }
            }
          }

          // 2.1 分割线识别（仅非代码块时，如 ---, ***, ___）
          if (!inCodeBlock && !fenceOpenMatch && !fenceCloseMatch && !lineDeco) {
            if (/^ {0,3}(?:(?:-\s*){3,}|(?:\*\s*){3,}|(?:_\s*){3,})$/.test(text)) {
              lineDeco = Decoration.line({ class: isActive ? "cm-hr-source-line" : "cm-hr-line" });
              if (!isActive && line.from < line.to) {
                lineItems.push({
                  from: line.from,
                  to: line.to,
                  deco: Decoration.mark({ class: "cm-md-syntax-hidden" }),
                });
              }
            }
          }

          // 2.2 引用块识别（仅非代码块时，如 > 内容）
          if (!inCodeBlock && !fenceOpenMatch && !fenceCloseMatch && !lineDeco) {
            const bqMatch = text.match(/^(\s*>\s*)/);
            if (bqMatch) {
              lineDeco = Decoration.line({ class: "cm-blockquote-line" });
              if (!isActive) {
                lineItems.push({
                  from: line.from,
                  to: line.from + bqMatch[1].length,
                  deco: Decoration.mark({ class: "cm-md-syntax-hidden" }),
                });
              }
            }
          }

          const isTableSeparator = false;

          // 4. 任务清单 Checklist: - [ ] 或 - [x]（仅非代码块时）
          if (!inCodeBlock && !fenceOpenMatch && !fenceCloseMatch) {
            const taskMatch = text.match(/^(\s*[-*+]\s+)(\[(?: |x)\])(\s+)/i);
            if (taskMatch) {
              const prefixLen = taskMatch[1].length;
              const checkFrom = line.from + prefixLen;
              const checkTo = checkFrom + taskMatch[2].length;
              const isChecked = taskMatch[2].toLowerCase().includes("x");

              lineItems.push({
                from: checkFrom,
                to: checkTo,
                deco: Decoration.replace({
                  widget: new TaskWidget(isChecked, checkFrom, checkTo),
                }),
              });
            }
          }

          const imgRanges = [];
          if (!inCodeBlock && !fenceOpenMatch && !fenceCloseMatch) {
            const inlineCodeRanges = [...text.matchAll(/`+[^`]*`+/g)].map(m => [m.index, m.index + m[0].length]);
            // B. 图片即时渲染: ![alt](url)
            const imgRe = /!\[([^\]\n]*)\]\(([^)\n]+)\)/g;
            let imgM;
            while ((imgM = imgRe.exec(text)) !== null) {
              if (!inlineCodeRanges.some(([a, b]) => imgM.index >= a && imgM.index < b)) {
                imgRanges.push([imgM.index, imgM.index + imgM[0].length]);
                const imgStart = line.from + imgM.index;
                const imgEnd = imgStart + imgM[0].length;
                hideImageIndent(lineItems, line, imgStart, imgEnd);
                const altText = imgM[1];
                const imgSrc = imgM[2];
                lineItems.push({
                  from: imgStart,
                  to: imgEnd,
                  deco: Decoration.replace({
                    widget: new ImageWidget(altText, imgSrc, imgStart, imgEnd),
                  }),
                });
              }
            }

            // B2. HTML img 标签即时渲染: <img ... src="..." ... />
            const htmlImgRe = /<img\s+[^>]*?src=["']([^"']+)["'][^>]*?>/gi;
            let htmlImgM;
            while ((htmlImgM = htmlImgRe.exec(text)) !== null) {
              if (!inlineCodeRanges.some(([a, b]) => htmlImgM.index >= a && htmlImgM.index < b)) {
                imgRanges.push([htmlImgM.index, htmlImgM.index + htmlImgM[0].length]);
                const imgStart = line.from + htmlImgM.index;
                const imgEnd = imgStart + htmlImgM[0].length;
                hideImageIndent(lineItems, line, imgStart, imgEnd);
                const imgSrc = htmlImgM[1];
                const altMatch = htmlImgM[0].match(/alt=["']([^"']*)["']/i);
                const altText = altMatch ? altMatch[1] : "";
                lineItems.push({
                  from: imgStart,
                  to: imgEnd,
                  deco: Decoration.replace({
                    widget: new ImageWidget(altText, imgSrc, imgStart, imgEnd),
                  }),
                });
              }
            }

          }

          // 5. 非光标所在行：行内标记、数学公式与美化（排除代码块与表格分隔行）
          if (!isActive && !inCodeBlock && !fenceOpenMatch && !fenceCloseMatch && !isTableSeparator) {
            // A. 行内代码及范围记录（避免代码内部字符被误解析为其他标记）
            const codeRanges = [];
            const codeRe = /`([^`\n]+?)`/g;
            let cm;
            while ((cm = codeRe.exec(text)) !== null) {
              codeRanges.push([cm.index, cm.index + cm[0].length]);
              const s = line.from + cm.index;
              const e = s + cm[0].length - 1;
              lineItems.push({ from: s, to: s + 1, deco: Decoration.mark({ class: "cm-md-syntax-hidden" }) });
              lineItems.push({ from: e, to: e + 1, deco: Decoration.mark({ class: "cm-md-syntax-hidden" }) });
            }

            const isInCode = (idx) => codeRanges.some(([s, e]) => idx >= s && idx < e);

            const isExcluded = (idx) => isInCode(idx) || imgRanges.some(([s, e]) => idx >= s && idx < e);

            // A2. HTML 格式化标签零占位隐藏: <p...>, </p>, <br>, <center>, <strong>, <em> 等
            const htmlTagRe = /<\/?(?:p|br|div|center|h[1-6]|span|small|strong|em|b|i|u)(?:\s+[^>]*)?>/gi;
            let htm;
            while ((htm = htmlTagRe.exec(text)) !== null) {
              if (!isExcluded(htm.index)) {
                const s = line.from + htm.index;
                const e = s + htm[0].length;
                lineItems.push({
                  from: s,
                  to: e,
                  deco: Decoration.mark({ class: "cm-md-syntax-hidden" }),
                });
              }
            }

            // C. 块级数学公式: $$...$$
            const mathBlockRe = /\$\$([^\$\n]+?)\$\$/g;
            let mb;
            while ((mb = mathBlockRe.exec(text)) !== null) {
              if (!isExcluded(mb.index)) {
                const formula = mb[1];
                const s = line.from + mb.index;
                const e = s + mb[0].length;
                lineItems.push({
                  from: s,
                  to: e,
                  deco: Decoration.replace({
                    widget: new MathWidget(formula, true, s, e),
                  }),
                });
              }
            }

            // D. 行内数学公式: $...$
            const mathInlineRe = /(?<!\$)\$([^\$\n]+?)\$(?!\$)/g;
            let mi;
            while ((mi = mathInlineRe.exec(text)) !== null) {
              if (!isExcluded(mi.index)) {
                const formula = mi[1];
                const s = line.from + mi.index;
                const e = s + mi[0].length;
                lineItems.push({
                  from: s,
                  to: e,
                  deco: Decoration.replace({
                    widget: new MathWidget(formula, false, s, e),
                  }),
                });
              }
            }

            // E. 粗体+斜体: ***text***
            const boldItalicRe = /\*\*\*([^\*\n]+?)\*\*\*/g;
            let bim;
            while ((bim = boldItalicRe.exec(text)) !== null) {
              if (!isExcluded(bim.index)) {
                const s = line.from + bim.index;
                const e = s + bim[0].length - 3;
                lineItems.push({ from: s, to: s + 3, deco: Decoration.mark({ class: "cm-md-syntax-hidden" }) });
                lineItems.push({ from: e, to: e + 3, deco: Decoration.mark({ class: "cm-md-syntax-hidden" }) });
              }
            }

            // F. 粗体: **text** 或 __text__
            const boldRe = /(?<!\*)\*\*([^\*\n]+?)\*\*(?!\*)|(?<!_)__([^_\n]+?)__(?!_)/g;
            let bm;
            while ((bm = boldRe.exec(text)) !== null) {
              if (!isExcluded(bm.index)) {
                const s = line.from + bm.index;
                const e = s + bm[0].length - 2;
                lineItems.push({ from: s, to: s + 2, deco: Decoration.mark({ class: "cm-md-syntax-hidden" }) });
                lineItems.push({ from: e, to: e + 2, deco: Decoration.mark({ class: "cm-md-syntax-hidden" }) });
              }
            }

            // G. 斜体: *text* 或 _text_
            const italicRe = /(?<!\*|\w)\*([^\*\n]+?)\*(?!\*|\w)|(?<!_|\w)_([^_\n]+?)_(?!_|\w)/g;
            let im;
            while ((im = italicRe.exec(text)) !== null) {
              if (!isExcluded(im.index)) {
                const s = line.from + im.index;
                const e = s + im[0].length - 1;
                lineItems.push({ from: s, to: s + 1, deco: Decoration.mark({ class: "cm-md-syntax-hidden" }) });
                lineItems.push({ from: e, to: e + 1, deco: Decoration.mark({ class: "cm-md-syntax-hidden" }) });
              }
            }

            // H. 删除线: ~~text~~
            const strikeRe = /~~([^~\n]+?)~~/g;
            let sm;
            while ((sm = strikeRe.exec(text)) !== null) {
              if (!isExcluded(sm.index)) {
                const s = line.from + sm.index;
                const e = s + sm[0].length - 2;
                lineItems.push({ from: s, to: s + 2, deco: Decoration.mark({ class: "cm-md-syntax-hidden" }) });
                lineItems.push({ from: e, to: e + 2, deco: Decoration.mark({ class: "cm-md-syntax-hidden" }) });
              }
            }

            // I. 超链接: [显示文本](url) - 自动隐藏 (url) 与括号，显示链接文本与下划线
            const linkRe = /(?<!!)\[([^\]\n]+)\]\(([^)\n]+)\)/g;
            let lm;
            while ((lm = linkRe.exec(text)) !== null) {
              if (!isExcluded(lm.index)) {
                const linkStart = line.from + lm.index;
                const linkText = lm[1];
                const linkTextStart = linkStart + 1;
                const linkTextEnd = linkTextStart + linkText.length;
                const linkEnd = linkStart + lm[0].length;

                // 隐藏起始 '['
                lineItems.push({ from: linkStart, to: linkTextStart, deco: Decoration.mark({ class: "cm-md-syntax-hidden" }) });
                // 标记链接文本样式
                lineItems.push({ from: linkTextStart, to: linkTextEnd, deco: Decoration.mark({ class: "cm-link" }) });
                // 隐藏末尾 '](url)'
                lineItems.push({ from: linkTextEnd, to: linkEnd, deco: Decoration.mark({ class: "cm-md-syntax-hidden" }) });
              }
            }
          }

          // ── 严格按 CodeMirror 6 规则输出到 builder ──
          // 步骤 1: 行级修饰符 (Decoration.line) 必须首先添加到 line.from
          if (lineDeco) {
            builder.add(line.from, line.from, lineDeco);
          }

          // 步骤 2: 对行内所有修饰项严格排序
          // 规则: 起始位置 from 升序；若 from 相同则按 startSide 升序；再按结束位置 to 升序
          lineItems.sort((a, b) => {
            if (a.from !== b.from) return a.from - b.from;
            const aSide = a.deco.startSide ?? 0;
            const bSide = b.deco.startSide ?? 0;
            if (aSide !== bSide) return aSide - bSide;
            return a.to - b.to;
          });

          // 步骤 3: 顺序且无重叠、无空 Mark 地添加到 builder，确保位置绝对单调递增
          let currentPos = line.from;
          for (const item of lineItems) {
            if (item.from < currentPos || item.to > line.to || item.from > item.to) continue;
            // 过滤空范围 Mark（CodeMirror 禁止空的 MarkDecoration）
            if (item.from === item.to && !item.deco.spec?.widget) continue;

            if (item.from < item.to) {
              builder.add(item.from, item.to, item.deco);
              currentPos = item.to;
            } else if (item.from === item.to) {
              builder.add(item.from, item.to, item.deco);
              currentPos = item.from;
            }
          }

          if (line.to >= state.doc.length) break;
          pos = line.to + 1;
        }
      }
      return builder.finish();
    } catch (err) {
      console.error("Live preview decoration error:", err);
      return Decoration.none;
    }
  }
})();

// Supply layout-changing decorations before CodeMirror computes its height map.
const typoraLivePreviewPlugin = StateField.define({
  create: state => previewBuilder.buildDecorations(state),
  update: (value, tr) => tr.docChanged || tr.selection || tr.reconfigured || tr.effects.some(e => e.is(revealLine))
    ? previewBuilder.buildDecorations(tr.state) : value,
  provide: field => EditorView.decorations.from(field),
});

// Rendered multi-line blocks represent a source range, not a single text row.
class BlockLineNumber extends GutterMarker {
  constructor(first, last) { super(); this.first = first; this.last = last; }
  eq(other) { return this.first === other.first && this.last === other.last; }
  toDOM() {
    const el = document.createElement("span");
    el.textContent = this.first === this.last ? String(this.first) : `${this.first}–${this.last}`;
    return el;
  }
}
function editorLineNumbers() {
  return [lineNumbers(), highlightActiveLineGutter(), lineNumberWidgetMarker.of((view, widget, block) => {
    if (!(widget instanceof TableWidget || widget instanceof MathWidget || widget instanceof MermaidWidget)) return null;
    return new BlockLineNumber(view.state.doc.lineAt(block.from).number, view.state.doc.lineAt(block.to).number);
  })];
}

// ============================================================
// Create Editor
// ============================================================
function createEditorState(content, serialized = null) {
  const config = {
    doc: content,
    extensions: [
      // Core
      historyComp.of(history()),
      drawSelection(),
      dropCursor(),
      EditorState.allowMultipleSelections.of(true),
      highlightSpecialChars(),
      rectangularSelection(),
      crosshairCursor(),
      // NOTE: highlightActiveLine() is intentionally omitted in WYSIWYG mode.
      // With block widgets (code headers), CM6's active-line DOM highlight
      // lands on the wrong visual row causing the "cursor on next line" bug.
      // Source mode re-enables it via lineNumbersComp.

      // Auto-wrap lines at window edge (Prevents overflowing window width)
      EditorView.lineWrapping,

      EditorView.inputHandler.of((view, from, to, text) => {
        if (from !== to || text.length !== 1) return false;
        const previous = from > 0 ? view.state.doc.sliceString(from - 1, from) : "";
        if (editorState.preferences.smartDashes && text === "-" && previous === "-") {
          view.dispatch({ changes: { from: from - 1, to, insert: "—" }, selection: { anchor: from } });
          return true;
        }
        if (editorState.preferences.smartQuotes && (text === "\"" || text === "'")) {
          const opening = !previous || /[\s([{]/.test(previous);
          const replacement = text === "\"" ? (opening ? "“" : "”") : (opening ? "‘" : "’");
          view.dispatch({ changes: { from, to, insert: replacement }, selection: { anchor: from + 1 } });
          return true;
        }
        return false;
      }),

      // Typora-style Live Preview: auto hide/show markdown syntax marks
      editingLine,
      typoraLivePreviewPlugin,

      // Language & highlighting
      languageComp.of(window.editor?.plainText ? [] : markdownLanguageSupport()),
      syntaxHighlighting(markdownHighlight),
      syntaxHighlighting(defaultHighlightStyle, { fallback: true }),

      // Keymaps
      keymap.of([
        ...defaultKeymap,
        ...historyKeymap,
        ...searchKeymap,
        ...lintKeymap,
        // Smart pairs
        { key: "Enter", run: handleEnter },
        { key: "Tab", run: handleTab },
        { key: "Shift-Tab", run: handleShiftTab },
      ]),

      // Line numbers (togglable)
      lineNumbersComp.of([]),

      // Search
      search({ top: false }),

      // Theme
      wysiwygTheme,

      // Update listener
      EditorView.updateListener.of(onEditorUpdate),

      // Drag & drop images
      EditorView.domEventHandlers({
        mousedown(e, view) {
          const rule = e.target.closest?.(".cm-hr-line");
          if (!rule) return false;
          e.preventDefault();
          const line = view.state.doc.lineAt(view.posAtDOM(rule));
          view.dispatch({ selection: { anchor: line.from }, effects: revealLine.of(line.from) });
          view.focus();
          return true;
        },
        dragover(e) {
          if (Array.from(e.dataTransfer?.types || []).includes("Files")) {
            e.preventDefault();
            e.dataTransfer.dropEffect = "copy";
          }
          // Let CodeMirror's dropCursor track the pointer without moving selection.
          return false;
        },
        drop(e, view) {
          const files = Array.from(e.dataTransfer?.files || []);
          if (!files.some(file => file.type.startsWith("image/") || /\.(png|jpe?g|gif|webp|svg)$/i.test(file.name))) return false;
          e.preventDefault();
          const pos = view.posAtCoords({ x: e.clientX, y: e.clientY });
          if (pos == null) return true;
          view.dispatch({ selection: { anchor: pos } });
          handleFileDrop(e);
          return true;
        },
        paste(e) { handlePaste(e); },
        scroll(e) { handleScroll(e); },
      }),
    ],
  };
  return serialized
    ? EditorState.fromJSON(serialized, config, { history: CM.commands.historyField })
    : EditorState.create(config);
}
function createEditor(content) {
  const view = new EditorView({
    state: createEditorState(content),
    parent: document.getElementById("editor-root"),
  });

  return view;
}

// ============================================================
// Update Handler
// ============================================================
let updateTimer = null;
function onEditorUpdate(update) {
  if (update.selectionSet || update.docChanged || update.viewportChanged || update.transactions.some(transaction => transaction.reconfigured)) {
    const selected = update.state.selection.main;
    let codeBlock = syntaxTree(update.state).resolveInner(selected.from, 1);
    while (codeBlock && codeBlock.name !== "FencedCode") codeBlock = codeBlock.parent;
    const insideCode = !editorState.isSourceMode && !selected.empty && !!codeBlock && selected.to <= codeBlock.to;
    const wholeCode = insideCode && selected.from === codeBlock.from && selected.to === codeBlock.to;
    const insideMath = !editorState.isSourceMode && !selected.empty && !insideCode &&
      previewBuilder.findBlockMathRanges(update.state).some(block => selected.from >= block.from && selected.to <= block.to);
    update.view.dom.classList.toggle("cm-code-block-selection", wholeCode);
    update.view.dom.classList.toggle("cm-code-text-selection", insideCode && !wholeCode);
    update.view.dom.classList.toggle("cm-math-text-selection", insideMath);
    update.view.contentDOM.querySelectorAll(".cm-code-block-line").forEach(line => {
      const position = update.view.posAtDOM(line);
      line.classList.toggle("cm-code-selected", wholeCode && position >= codeBlock.from && position < codeBlock.to);
    });
    let wholeTable = false;
    update.view.dom.querySelectorAll("[data-block-from], [data-table-from], [data-image-from]").forEach(el => {
      const from = +(el.dataset.blockFrom ?? el.dataset.tableFrom ?? el.dataset.imageFrom);
      const to = +(el.dataset.blockTo ?? el._tableModel?.to ?? el.dataset.imageTo);
      const target = el.dataset.blockFrom ? el.parentElement : el;
      const isSelected = !selected.empty && selected.from <= from && selected.to >= to;
      target.classList.toggle("cm-block-selected", isSelected);
      if (el.dataset.tableFrom != null && selected.from === from && selected.to === to) wholeTable = true;
      if (el.dataset.imageFrom != null) {
        const path = el.querySelector(".cm-image-path");
        path.hidden = !isSelected;
      }
    });
    update.view.dom.classList.toggle("cm-table-block-selection", wholeTable);
    handleScroll();
  }
  if (update.docChanged) {
    if (!window.editor.loadingContent) swift.send("contentChanged", { content: update.state.doc.toString(), documentID: window.editor.documentID || "" });
    for (const [id, pos] of pendingImages) pendingImages.set(id, update.changes.mapPos(pos, 1));
    clearTimeout(updateTimer);
    if (editorState.backgrounded) return;
    updateTimer = setTimeout(() => {
      const content = update.state.doc.toString();
      editorState.content = content;

      // Send to Swift


      // Update word count
      updateWordCount(content);

      // Update outline
      updateOutline(content);

      // Re-render WYSIWYG panels if in WYSIWYG mode
      if (!editorState.isSourceMode) {
        renderWYSIWYGWidgets();
      }
    }, 150);
  }
}

// ============================================================
// Word Count
// ============================================================
function updateWordCount(text) {
  const stripped = text.replace(/[#*`_~\[\]()]/g, "").trim();
  const words = stripped ? stripped.split(/\s+/).length : 0;
  const chars = stripped.replace(/\s/g, "").length;
  swift.send("wordCount", { words, chars });
}

// ============================================================
// Outline (headings)
// ============================================================
function updateOutline(text) {
  const headingRe = /^(#{1,6})\s+(.+)$/gm;
  const items = [];
  let match;
  let lineNum = 0;

  const lines = text.split("\n");
  lines.forEach((line, idx) => {
    const m = line.match(/^(#{1,6})\s+(.+)$/);
    if (m) {
      items.push({
        id: `heading-${idx}`,
        level: m[1].length,
        text: m[2].trim(),
        line: idx,
      });
    }
  });

  swift.send("outlineChanged", items);
}

// ============================================================
// WYSIWYG Widget Rendering (CodeMirror decorations approach)
// We use a "hybrid" approach: CodeMirror shows source text,
// but we post-process the DOM to render rich elements in
// a floating overlay or use CM6 decorations.
// ============================================================
function renderWYSIWYGWidgets() {
  if (editorState.backgrounded) return;
  // Re-render mermaid diagrams in the document
  const mermaidEls = document.querySelectorAll(".md-mermaid[data-content]");
  mermaidEls.forEach(el => {
    const content = el.dataset.content;
    renderMermaid("svg-" + Date.now(), content).then(({ svg }) => {
      el.innerHTML = svg;
    }).catch(() => {});
  });

  // Re-render KaTeX math
  document.querySelectorAll(".md-math-inline[data-content]").forEach(el => {
    try {
      el.innerHTML = katex.renderToString(el.dataset.content, { throwOnError: false });
    } catch (_) {}
  });
}

// ============================================================
// Smart Key Handlers (Enter, Tab, Shift-Tab)
// ============================================================

function handleEnter(view) {
  const { state } = view;
  const { from } = state.selection.main;
  const line = state.doc.lineAt(from);
  const lineText = line.text;

  // 1. 任务列表智能回车与退出: - [ ] 或 - [x]
  const taskMatch = lineText.match(/^(\s*[-*+]\s+\[(?: |x)\])\s*(.*)$/i);
  if (taskMatch) {
    const prefix = taskMatch[1];
    const content = taskMatch[2];
    if (!content.trim()) {
      // 空任务项 → 回车退出列表
      view.dispatch({
        changes: { from: line.from, to: line.to, insert: "" },
        selection: { anchor: line.from },
      });
      return true;
    }
    // 延续插入新的未勾选任务项
    const indent = lineText.match(/^\s*/)[0];
    const marker = lineText.includes("*") ? "*" : lineText.includes("+") ? "+" : "-";
    const nextItem = `\n${indent}${marker} [ ] `;
    view.dispatch({
      changes: { from, insert: nextItem },
      selection: { anchor: from + nextItem.length },
    });
    return true;
  }

  // 2. 表格行回车: 自动在下方添加一行新表格并聚焦第一个单元格
  if (/^\s*\|.+?\|\s*$/.test(lineText)) {
    const colCount = lineText.split("|").length - 2;
    if (colCount > 0) {
      const newRow = "\n" + "|" + "     |".repeat(colCount);
      view.dispatch({
        changes: { from: line.to, insert: newRow },
        selection: { anchor: line.to + 3 },
      });
      return true;
    }
  }

  // 3. 无序列表与有序列表
  const listMatch = lineText.match(/^(\s*)([-*+]|\d+\.)\s+(.*)$/);
  if (listMatch) {
    const indent = listMatch[1];
    const marker = listMatch[2];
    const content = listMatch[3];

    if (!content.trim()) {
      // 空列表项 → 回车退出列表
      view.dispatch({
        changes: { from: line.from, to: line.to, insert: "" },
        selection: { anchor: line.from },
      });
      return true;
    }

    let nextMarker = marker;
    if (/^\d+$/.test(marker)) {
      nextMarker = (parseInt(marker, 10) + 1) + ".";
    }

    const nextItem = `\n${indent}${nextMarker} `;
    view.dispatch({
      changes: { from, insert: nextItem },
      selection: { anchor: from + nextItem.length },
    });
    return true;
  }

  // 4. 引用块延续
  if (lineText.startsWith("> ")) {
    if (lineText.trim() === ">") {
      // 空引用块 → 退出引用
      view.dispatch({
        changes: { from: line.from, to: line.to, insert: "" },
        selection: { anchor: line.from },
      });
      return true;
    }
    view.dispatch({
      changes: { from, insert: "\n> " },
      selection: { anchor: from + 3 },
    });
    return true;
  }

  return false;
}

function isInsideCodeBlock(state, pos) {
  let inCode = false;
  const targetLine = state.doc.lineAt(pos).number;
  for (let l = 1; l <= targetLine; l++) {
    const cur = state.doc.line(l);
    if (/^```/.test(cur.text.trim())) {
      inCode = !inCode;
    }
  }
  return inCode;
}

function handleTab(view) {
  const { state } = view;
  const { from } = state.selection.main;
  const line = state.doc.lineAt(from);
  const lineText = line.text;

  // 1. 表格内 Tab: 单元格智能导航
  if (/^\s*\|.+?\|\s*$/.test(lineText)) {
    const relPos = from - line.from;
    const nextPipe = lineText.indexOf("|", relPos + 1);
    if (nextPipe !== -1 && nextPipe < lineText.length - 1) {
      // 跳转到本行的下一个单元格
      view.dispatch({
        selection: { anchor: line.from + nextPipe + 2 },
      });
      return true;
    } else {
      // 检查下一行是否是表格
      const nextLineNum = line.number + 1;
      if (nextLineNum <= state.doc.lines) {
        const nextLine = state.doc.line(nextLineNum);
        if (/^\s*\|.+?\|\s*$/.test(nextLine.text)) {
          view.dispatch({
            selection: { anchor: nextLine.from + 2 },
          });
          return true;
        }
      }
      // 已在表格末尾最后一个单元格 → 自动新建一行并跳入
      const colCount = lineText.split("|").length - 2;
      if (colCount > 0) {
        const newRow = "\n" + "|" + "     |".repeat(colCount);
        view.dispatch({
          changes: { from: line.to, insert: newRow },
          selection: { anchor: line.to + 3 },
        });
        return true;
      }
    }
  }

  // 2. 代码块内 Tab: 缩进保护（插入 4 空格，不跳出焦点）
  if (isInsideCodeBlock(state, from)) {
    view.dispatch({
      changes: { from, insert: "    " },
      selection: { anchor: from + 4 },
    });
    return true;
  }

  // 3. 列表项缩进
  if (/^\s*([-*+]|\d+\.)\s/.test(line.text)) {
    view.dispatch({
      changes: { from: line.from, insert: "  " },
      selection: { anchor: from + 2 },
    });
    return true;
  }

  // 4. 普通 Tab → 4 空格
  view.dispatch({
    changes: { from, insert: "    " },
    selection: { anchor: from + 4 },
  });
  return true;
}

function handleShiftTab(view) {
  const { state } = view;
  const { from } = state.selection.main;
  const line = state.doc.lineAt(from);
  const lineText = line.text;

  // 1. 表格内 Shift-Tab: 反向跳到上一个单元格
  if (/^\s*\|.+?\|\s*$/.test(lineText)) {
    const relPos = from - line.from;
    const prevPipe = lineText.lastIndexOf("|", Math.max(0, relPos - 2));
    if (prevPipe > 0) {
      view.dispatch({
        selection: { anchor: line.from + prevPipe + 2 },
      });
      return true;
    }
  }

  // 2. 列表项反缩进
  if (/^  /.test(line.text)) {
    view.dispatch({
      changes: { from: line.from, to: line.from + 2, insert: "" },
      selection: { anchor: Math.max(line.from, from - 2) },
    });
    return true;
  }

  return false;
}

// ============================================================
// Paste Handler (images from clipboard → save to assets/)
// ============================================================
const pendingImages = new Map();
function reserveImagePosition() {
  const id = String(Date.now()) + "-" + Math.random().toString(36).slice(2);
  pendingImages.set(id, window.editor._view.state.selection.main.from);
  return id;
}

function handlePaste(e) {
  const items = e.clipboardData?.items;
  if (!items) return;

  for (const item of items) {
    if (item.type.startsWith("image/")) {
      e.preventDefault();
      const file = item.getAsFile();
      if (!file) continue;

      const ext = item.type.split("/")[1]?.replace("jpeg", "jpg") ?? "png";
      const ts = Date.now();
      const fileName = `image-${ts}.${ext}`;

      const requestID = reserveImagePosition();
      const reader = new FileReader();
      reader.onload = (ev) => {
        const dataURL = ev.target.result;
        // Send to Swift: Swift will save file and return the relative path
        swift.send("imageDropped", {
          requestID,
          dataURL,           // base64 data URL for Swift to decode & save
          name: fileName,    // suggested filename
          mode: "paste",     // distinguish paste vs drag
        });
      };
      reader.readAsDataURL(file);
      return; // Only handle first image
    }
  }
}

// ============================================================
// File Drop Handler
// ============================================================
function handleFileDrop(e) {
  const files = e.dataTransfer?.files;
  if (!files?.length) return;

  for (const file of files) {
    if (file.type.startsWith("image/") || /\.(png|jpe?g|gif|webp|svg)$/i.test(file.name)) {
      // In WebKit, file.path is often blank for drag-and-drop. Use FileReader as primary mechanism.
      const requestID = reserveImagePosition();
      const reader = new FileReader();
      reader.onload = (ev) => {
        const dataURL = ev.target.result;
        swift.send("imageDropped", {
          requestID,
          dataURL,
          name: file.name || `image-${Date.now()}.png`,
          path: file.path || "",
          mode: "drag",
        });
      };
      reader.readAsDataURL(file);
      break; // Handle first image
    }
  }
}

// ============================================================
// Scroll Handler (typewriter mode)
// ============================================================
let readingTimer;
function reportReadingPosition() {
  const view = window.editor?._view;
  if (!view || !window.editor.documentID) return;
  const block = view.lineBlockAtHeight(view.scrollDOM.scrollTop);
  swift.send("scrollInfo", { documentID: window.editor.documentID,
    anchor: view.state.selection.main.head, topPosition: block.from,
    scrollTop: view.scrollDOM.scrollTop,
    viewportWidth: view.scrollDOM.clientWidth,
    offset: view.scrollDOM.getBoundingClientRect().top - (view.coordsAtPos(block.from)?.top ?? view.documentTop + block.top) });
}
function handleScroll() {
  clearTimeout(readingTimer);
  if (editorState.backgrounded) return;
  readingTimer = setTimeout(reportReadingPosition, 120);
}
function markdownLanguageSupport() {
  const baseParser = markdownLanguage.parser.configure({ remove: ["SetextHeading"] });
  return markdown({ base: { parser: baseParser }, codeLanguages: CM.languages });
}

// ============================================================
// Public Editor API (called from Swift via evaluateJavaScript)
// ============================================================
window.editor = {
  _view: null,

  // ── Set content ──
  setContent(markdown) {
    if (!this._view) {
      editorState.content = markdown;
      return;
    }
    clearTimeout(updateTimer);
    pendingImages.clear();
    const current = this._view.state.doc.toString();
    if (current === markdown) return;
    this.loadingContent = true;
    try {
      this._view.dispatch({ changes: { from: 0, to: current.length, insert: markdown } });
    } finally { this.loadingContent = false; }
    updateOutline(markdown);
    updateWordCount(markdown);
  },

  openDocument(markdown, documentID, position = {}, plainText = false) {
    const switchingDocument = this.documentID !== documentID;
    if (this._view && this.documentID && this.documentID !== documentID) {
      const v = this._view;
      swift.send("scrollInfo", {
        documentID: this.documentID,
        anchor: v.state.selection.main.head,
        scrollTop: v.scrollDOM.scrollTop,
        viewportWidth: v.scrollDOM.clientWidth
      });
    }
    this.documentID = documentID;
    this.plainText = plainText;
    editorState.isSourceMode = plainText;
    document.body.classList.toggle("source-mode", plainText);

    if (!this._view) {
      editorState.content = markdown;
      return;
    }

    clearTimeout(updateTimer);
    pendingImages.clear();
    this.loadingContent = true;

    try {
      // Drop old-document undo records instead of retaining every previously opened file.
      if (switchingDocument) this._view.dispatch({ effects: historyComp.reconfigure([]) });
      const curLen = this._view.state.doc.length;
      const anchor = Math.min(position.anchor ?? 0, markdown.length);
      const effects = [
        languageComp.reconfigure(plainText ? [] : markdownLanguageSupport()),
        lineNumbersComp.reconfigure(
          editorState.preferences.showLineNumbers ? editorLineNumbers() : []
        ),
        revealLine.of(anchor)
      ];
      if (switchingDocument) effects.push(historyComp.reconfigure(history()));

      this._view.dispatch({
        changes: { from: 0, to: curLen, insert: markdown },
        selection: { anchor },
        annotations: CM.state.Transaction.addToHistory.of(false),
        effects: effects
      });
    } finally {
      this.loadingContent = false;
    }

    const view = this._view;
    requestAnimationFrame(() => {
      if (this.documentID !== documentID) return;
      if (position.scrollTop != null) {
        view.scrollDOM.scrollTop = position.scrollTop;
      } else if (position.anchor != null) {
        view.dispatch({ effects: EditorView.scrollIntoView(Math.min(position.anchor, view.state.doc.length), { y: "center" }) });
      }
      view.requestMeasure();
    });
  },

  // ── Get raw content ──
  getContent() {
    return this._view?.state.doc.toString() ?? editorState.content;
  },

  // ── Get rendered HTML ──
  getRenderedHTML() {
    const content = this.getContent();
    const body = md.render(content);
    return `<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
body { font-family: -apple-system, sans-serif; max-width: 740px; margin: 40px auto; padding: 0 24px; line-height: 1.75; color: #1C1C1E; }
h1 { font-size: 2em; } h2 { font-size: 1.5em; border-bottom: 1px solid #D1D1D6; padding-bottom: 0.3em; }
h3 { font-size: 1.25em; } code { font-family: "SF Mono", Menlo, monospace; background: #F2F2F7; padding: 0.15em 0.4em; border-radius: 4px; }
pre { background: #F2F2F7; padding: 14px; border-radius: 8px; overflow-x: auto; }
pre code { background: none; padding: 0; }
blockquote { border-left: 3px solid #FFD60A; background: rgba(255,214,10,0.06); padding: 0.6em 1em; margin: 1em 0; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #D1D1D6; padding: 8px 14px; }
th { background: #F2F2F7; }
img { max-width: 100%; border-radius: 8px; }
a { color: #007AFF; }
</style>
</head>
<body>${body}</body>
</html>`;
  },

  async getExportDocument() {
    const root = document.createElement("article");
    if (this.plainText) {
      const pre = root.appendChild(document.createElement("pre"));
      pre.className = "plain-text";
      pre.textContent = this.getContent();
    } else {
      root.innerHTML = md.render(this.getContent());
      const diagrams = md.parse(this.getContent(), {}).filter(t => t.type === "fence" && t.info.trim() === "mermaid");
      const targets = root.querySelectorAll(".md-mermaid");
      for (let i = 0; i < targets.length; i++) {
        try { targets[i].innerHTML = (await renderMermaid(`export-diagram-${Date.now()}-${i}`, diagrams[i].content)).svg; }
        catch (_) { targets[i].textContent = diagrams[i]?.content || ui("diagramError"); }
      }
    }
    root.querySelectorAll("script, iframe, object, embed, button").forEach(el => el.remove());
    root.querySelectorAll("*").forEach(el => {
      for (const attr of [...el.attributes]) if (/^on/i.test(attr.name)) el.removeAttribute(attr.name);
    });
    const images = [...root.querySelectorAll("img")].map((img, i) => {
      const src = img.getAttribute("src");
      const token = `mnotes-export-image-${i}-${Date.now()}`;
      img.setAttribute("src", token);
      return { token, src };
    });
    const html = `<!doctype html><html lang="${editorState.language}"><head><meta charset="utf-8"><title>M Notes</title><style>
      *{box-sizing:border-box}body{font:16px/1.7 -apple-system,sans-serif;color:#242424;background:white;margin:36px auto;padding:0 24px;max-width:800px}
      h1,h2,h3,h4,h5,h6{break-after:avoid}h1{font-size:2em}h2{border-bottom:1px solid #ddd;padding-bottom:.25em}
      pre{padding:14px;background:#f5f5f7;border-radius:6px;white-space:pre-wrap;overflow-wrap:anywhere;font:13px/1.6 Menlo,monospace}
      pre.plain-text{background:none;padding:0;font:inherit}code{font-family:Menlo,monospace}p code{background:#f5f5f7;padding:2px 4px}
      blockquote{border-left:3px solid #e4b800;margin-left:0;padding:0 16px;color:#555}a{color:#0969da}
      table{border-collapse:collapse;width:100%;margin:16px 0}th,td{border:1px solid #ddd;padding:7px 10px;overflow-wrap:anywhere}th{background:#f5f5f7}tr{break-inside:avoid}
      img,svg{max-width:100%;height:auto}img{max-height:650px;object-fit:contain}hr{border:0;border-top:1px solid #ccc;margin:20px 0}
      .md-mermaid,.md-math-block{text-align:center;margin:16px 0}.missing-image{display:block;padding:12px;border:1px solid #ddd;color:#777;border-radius:6px}
      @media print{body{margin:0;padding:0;max-width:none;font-size:11pt}pre{font-size:9pt}a{text-decoration:none}thead{display:table-header-group}img{break-inside:avoid}}
      </style></head><body>${root.innerHTML}</body></html>`;
    return { html, images, language: editorState.language };
  },

  // ── Toggle source mode ──
  setSourceMode(enabled) {
    enabled = enabled || !!this.plainText;
    editorState.isSourceMode = enabled;
    document.body.classList.toggle("source-mode", enabled);
    if (this._view) {
      this._view.dispatch({
        effects: lineNumbersComp.reconfigure(
          editorState.preferences.showLineNumbers ? editorLineNumbers() : []
        ),
      });
    }
  },

  // ── Toggle typewriter mode ──
  setTypewriterMode(enabled) {
    if (editorState.isTypewriterMode === enabled) return;
    editorState.isTypewriterMode = enabled;
    document.body.classList.toggle("typewriter-mode", enabled);
    document.getElementById("editor-root").classList.toggle("typewriter-mode", enabled);
  },

  setBackgrounded(backgrounded) {
    editorState.hostBackgrounded = backgrounded;
    backgrounded = backgrounded || document.hidden;
    if (editorState.backgrounded === backgrounded) return;
    if (backgrounded) reportReadingPosition();
    editorState.backgrounded = backgrounded;
    document.documentElement.classList.toggle("backgrounded", backgrounded);
    clearTimeout(updateTimer);
    clearTimeout(readingTimer);
    if (!backgrounded && this._view) {
      updateOutline(this.getContent());
      updateWordCount(this.getContent());
      this._view.dispatch({ effects: revealLine.of(this._view.state.selection.main.head) });
      this._view.requestMeasure();
    }
  },

  captureSession() {
    if (!this._view || this._view.composing || pendingImages.size) return null;
    return JSON.stringify({
      version: 1, documentID: this.documentID,
      state: this._view.state.toJSON({ history: CM.commands.historyField }),
      scrollTop: this._view.scrollDOM.scrollTop,
      sourceMode: editorState.isSourceMode,
    });
  },

  restoreSession(serialized) {
    const session = JSON.parse(serialized);
    // An external edit or a different document takes precedence over the old snapshot.
    if (session.version !== 1 || session.documentID !== this.documentID || session.state.doc !== this.getContent()) return false;
    this.loadingContent = true;
    try {
      editorState.isSourceMode = session.sourceMode || !!this.plainText;
      document.body.classList.toggle("source-mode", editorState.isSourceMode);
      this._view.setState(createEditorState(session.state.doc, session.state));
    } finally { this.loadingContent = false; }
    const view = this._view;
    requestAnimationFrame(() => { view.scrollDOM.scrollTop = session.scrollTop; view.requestMeasure(); });
    return true;
  },

  // ── Load custom CSS theme (instant 0ms switching) ──
  setTheme(themeName) {
    const customEl = document.getElementById("custom-theme");

    const appearance = ["notes-dark", "github-dark", "dracula", "liquid-glass-dark"].includes(themeName) ? "dark"
      : (["notes-light", "github-light", "solarized", "liquid-glass-light"].includes(themeName) ? "light" : "");
    document.documentElement.style.colorScheme = appearance;

    // Toggle highlight.js theme instantly
    const isDark = appearance === "dark" || (themeName === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches);
    const hljsLight = document.getElementById("hljs-light-theme");
    const hljsDark = document.getElementById("hljs-dark-theme");
    if (hljsLight) hljsLight.disabled = isDark;
    if (hljsDark) hljsDark.disabled = !isDark;

    if (!themeName || themeName === "system" || themeName === "notes-light" || themeName === "notes-dark") {
      // Use built-in Notes theme (editor.css handles dark mode)
      if (customEl) {
        customEl.disabled = true;
        customEl.href = "";
      }
      document.documentElement.removeAttribute("data-theme");
      document.body.removeAttribute("data-theme");
      return;
    }

    const builtInThemes = ["liquid-glass-light", "liquid-glass-dark", "dracula", "solarized", "github-light", "github-dark"];
    if (builtInThemes.includes(themeName)) {
      if (customEl) {
        customEl.disabled = true;
        customEl.href = "";
      }
      document.documentElement.setAttribute("data-theme", themeName);
      document.body.setAttribute("data-theme", themeName);
      return;
    }

    // Load from themes/ directory for user external custom themes
    if (customEl) {
      const themeURL = `themes/${themeName}.css`;
      customEl.href = themeURL;
      customEl.disabled = false;
    }
    document.documentElement.setAttribute("data-theme", themeName);
    document.body.setAttribute("data-theme", themeName);
  },

  setPreferences(preferences = {}) {
    editorState.preferences = { ...editorState.preferences, ...preferences };
    const root = document.documentElement;
    if (Number.isFinite(preferences.fontSize)) root.style.setProperty("--font-size", `${preferences.fontSize}px`);
    if (Number.isFinite(preferences.lineHeight)) root.style.setProperty("--line-height", String(preferences.lineHeight));
    if (Number.isFinite(preferences.maxWidth)) root.style.setProperty("--max-width", `${preferences.maxWidth}px`);
    if (Number.isFinite(preferences.bottomPadding)) root.style.setProperty("--bottom-padding", `${preferences.bottomPadding}vh`);
    if (typeof preferences.fontFamily === "string" && preferences.fontFamily.trim()) {
      root.style.setProperty("--font-body", preferences.fontFamily);
    }
    if (this._view) {
      this._view.contentDOM.spellcheck = preferences.spellCheck !== false;
      this._view.contentDOM.setAttribute("autocorrect", preferences.spellCheck === false ? "off" : "on");
      this._view.dispatch({
        effects: lineNumbersComp.reconfigure(
          editorState.preferences.showLineNumbers ? editorLineNumbers() : []
        )
      });
      this._view.requestMeasure();
    }
  },

  setLanguage(language) {
    const next = language === "en" ? "en" : "zh-Hans";
    if (editorState.language === next) return;
    editorState.language = next;
    document.documentElement.lang = next;
    if (this._view) {
      this._view.dispatch({ effects: revealLine.of(this._view.state.selection.main.head) });
    }
  },

  // ── Go to line number (from search result) ──
  gotoLine(lineNum) {
    if (!this._view) return;
    const view = this._view;
    const line = Math.max(1, Math.min(lineNum, view.state.doc.lines));
    const lineObj = view.state.doc.line(line);
    view.dispatch({
      selection: { anchor: lineObj.from },
      scrollIntoView: true,
    });
    view.focus();
  },


  execCommand(command) {
    if (!this._view) return;
    const view = this._view;
    const { state } = view;
    const { from, to } = state.selection.main;
    const selectedText = state.doc.sliceString(from, to);

    switch (command) {
      case "bold":
        toggleWrap(view, from, to, selectedText, "**");
        break;
      case "italic":
        toggleWrap(view, from, to, selectedText, "_");
        break;
      case "strikethrough":
        toggleWrap(view, from, to, selectedText, "~~");
        break;
      case "inlineCode":
        toggleWrap(view, from, to, selectedText, "`");
        break;
      case "h1": setHeading(view, 1); break;
      case "h2": setHeading(view, 2); break;
      case "h3": setHeading(view, 3); break;
      case "h4": setHeading(view, 4); break;
      case "h5": setHeading(view, 5); break;
      case "h6": setHeading(view, 6); break;
      case "p": setHeading(view, 0); break;
      case "ul": toggleList(view, "-"); break;
      case "ol": toggleList(view, "1."); break;
      case "task": toggleList(view, "- [ ]"); break;
      case "quote": toggleBlockquote(view); break;
      case "table": insertTable(view); break;
      case "codeBlock": insertCodeBlock(view, from, to, selectedText); break;
      case "math": insertMath(view, from, to); break;
      case "link": insertLink(view, from, to, selectedText); break;
      case "image": insertImage(view); break;
      case "hr": insertHR(view, from); break;
      case "findNext":
        if (CM.search?.findNext) CM.search.findNext(view);
        break;
      case "findPrev":
        if (CM.search?.findPrevious) CM.search.findPrevious(view);
        break;
      case "replace":
      case "replaceNext":
        if (CM.search?.replaceNext) CM.search.replaceNext(view);
        break;
      case "replaceAll":
        if (CM.search?.replaceAll) CM.search.replaceAll(view);
        break;
      default:
        if (command.startsWith("findWithOptions:")) {
          try {
            const opts = JSON.parse(command.slice("findWithOptions:".length));
            setSearchQuery(view, opts.query, opts.caseSensitive, opts.regexp, opts.replace);
          } catch (_) {}
        } else if (command.startsWith("find:")) {
          const query = command.slice(5);
          highlightFind(view, query);
        } else if (command.startsWith("replace:")) {
          const rest = command.slice(8);
          const sep = rest.indexOf(":");
          if (sep !== -1) {
            const q = rest.slice(0, sep);
            const r = rest.slice(sep + 1);
            setSearchQuery(view, q, false, false, r);
            if (CM.search?.replaceNext) CM.search.replaceNext(view);
          }
        } else if (command.startsWith("replaceAll:")) {
          const rest = command.slice(11);
          const sep = rest.indexOf(":");
          if (sep !== -1) {
            const q = rest.slice(0, sep);
            const r = rest.slice(sep + 1);
            setSearchQuery(view, q, false, false, r);
            if (CM.search?.replaceAll) CM.search.replaceAll(view);
          }
        } else if (command.startsWith("scrollToHeading:")) {
          const id = command.slice("scrollToHeading:".length);
          scrollToHeading(view, id);
        } else if (command.startsWith("gotoLine:")) {
          const lineNum = parseInt(command.slice("gotoLine:".length), 10);
          this.gotoLine(lineNum);
        }
    }
  },

  // ── Insert text at cursor ──
  insertAtCursor(text, requestID) {
    if (!this._view) return;
    if (requestID && !pendingImages.has(requestID)) return;
    const from = pendingImages.get(requestID) ?? this._view.state.selection.main.from;
    pendingImages.delete(requestID);
    this._view.dispatch({
      changes: { from, insert: text + "\n" },
      selection: { anchor: from + text.length + 1 },
    });
  },
};

// ============================================================
// Format Command Helpers
// ============================================================
function toggleWrap(view, from, to, selected, marker) {
  const before = view.state.doc.sliceString(Math.max(0, from - marker.length), from);
  const after = view.state.doc.sliceString(to, to + marker.length);

  if (before === marker && after === marker) {
    // Remove wrapping
    view.dispatch({
      changes: [
        { from: from - marker.length, to: from, insert: "" },
        { from: to, to: to + marker.length, insert: "" },
      ],
      selection: { anchor: from - marker.length, head: to - marker.length },
    });
  } else if (selected) {
    // Wrap selection
    view.dispatch({
      changes: { from, to, insert: `${marker}${selected}${marker}` },
      selection: { anchor: from + marker.length, head: to + marker.length },
    });
  } else {
    // Insert markers and place cursor between them
    view.dispatch({
      changes: { from, insert: `${marker}${marker}` },
      selection: { anchor: from + marker.length },
    });
  }
  view.focus();
}

function setHeading(view, level) {
  const { state } = view;
  const { from } = state.selection.main;
  const line = state.doc.lineAt(from);
  const text = line.text;
  const existingMatch = text.match(/^(#{1,6})\s+/);

  if (level === 0) {
    // Remove heading
    if (existingMatch) {
      view.dispatch({
        changes: { from: line.from, to: line.from + existingMatch[0].length, insert: "" },
        selection: { anchor: line.from },
      });
    }
  } else {
    const prefix = "#".repeat(level) + " ";
    if (existingMatch) {
      view.dispatch({
        changes: { from: line.from, to: line.from + existingMatch[0].length, insert: prefix },
        selection: { anchor: line.from + prefix.length },
      });
    } else {
      view.dispatch({
        changes: { from: line.from, insert: prefix },
        selection: { anchor: line.from + prefix.length },
      });
    }
  }
  view.focus();
}

function toggleList(view, marker) {
  const { state } = view;
  const { from } = state.selection.main;
  const line = state.doc.lineAt(from);
  const text = line.text;
  const listRe = /^(\s*)([-*+]|\d+\.)\s+/;
  const match = text.match(listRe);

  if (match) {
    // Remove list
    view.dispatch({
      changes: { from: line.from, to: line.from + match[0].length, insert: "" },
      selection: { anchor: line.from },
    });
  } else {
    const insert = `${marker} `;
    view.dispatch({
      changes: { from: line.from, insert },
      selection: { anchor: line.from + insert.length },
    });
  }
  view.focus();
}

function toggleBlockquote(view) {
  const { state } = view;
  const { from } = state.selection.main;
  const line = state.doc.lineAt(from);
  const text = line.text;

  if (text.startsWith("> ")) {
    view.dispatch({
      changes: { from: line.from, to: line.from + 2, insert: "" },
      selection: { anchor: Math.max(line.from, from - 2) },
    });
  } else {
    view.dispatch({
      changes: { from: line.from, insert: "> " },
      selection: { anchor: from + 2 },
    });
  }
  view.focus();
}

function insertTable(view) {
  const tableTemplate = `\n| 列1 | 列2 | 列3 |\n| --- | --- | --- |\n| 内容 | 内容 | 内容 |\n`;
  const { from } = view.state.selection.main;
  view.dispatch({
    changes: { from, insert: tableTemplate },
    selection: { anchor: from + 3 },
  });
  view.focus();
}

function insertCodeBlock(view, from, to, selected) {
  if (selected) {
    view.dispatch({
      changes: { from, to, insert: `\`\`\`\n${selected}\n\`\`\`` },
      selection: { anchor: from + 4 },
    });
  } else {
    const block = "```\n\n```";
    view.dispatch({
      changes: { from, insert: block },
      selection: { anchor: from + 4 },
    });
  }
  view.focus();
}

function insertMath(view, from, to) {
  const template = "\n$$\n\n$$\n";
  view.dispatch({
    changes: { from, insert: template },
    selection: { anchor: from + 4 },
  });
  view.focus();
}

function insertLink(view, from, to, selected) {
  const text = selected || "链接文字";
  const insert = `[${text}](url)`;
  view.dispatch({
    changes: { from, to, insert },
    selection: { anchor: from + insert.length - 4, head: from + insert.length - 1 },
  });
  view.focus();
}

function insertImage(view) {
  const insert = "![图片描述](图片路径)";
  const { from } = view.state.selection.main;
  view.dispatch({
    changes: { from, insert },
    selection: { anchor: from + 2, head: from + 6 },
  });
  view.focus();
}

function insertHR(view, from) {
  view.dispatch({
    changes: { from, insert: "\n---\n" },
    selection: { anchor: from + 5 },
  });
  view.focus();
}

// ============================================================
// Find / Highlight
// ============================================================
function setSearchQuery(view, search, caseSensitive = false, regexp = false, replace = "") {
  if (!CM.search?.SearchQuery || !CM.search?.setSearchQuery) return;
  try {
    const q = new CM.search.SearchQuery({
      search: search || "",
      caseSensitive: !!caseSensitive,
      regexp: !!regexp,
      replace: replace || ""
    });
    view.dispatch({ effects: CM.search.setSearchQuery.of(q) });
    if (search) {
      CM.search.findNext(view);
    }
  } catch (err) {
    console.error("setSearchQuery error:", err);
  }
}

function highlightFind(view, query) {
  setSearchQuery(view, query, false, false);
}

function scrollToHeading(view, headingId) {
  const match = headingId.match(/heading-(\d+)/);
  if (!match) return;
  const lineNum = parseInt(match[1]);
  const line = view.state.doc.line(lineNum + 1);
  view.dispatch({
    selection: { anchor: line.from },
    effects: EditorView.scrollIntoView(line.from, { y: "center" }),
  });
  view.focus();
}

// ============================================================
// Dark Mode Observer
// ============================================================
window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", (e) => {
  // Reinit mermaid with correct theme
  configureMermaid();

  // Switch highlight.js theme
  document.getElementById("hljs-light-theme").disabled = e.matches;
  document.getElementById("hljs-dark-theme").disabled = !e.matches;
});

document.addEventListener("visibilitychange", () => {
  window.editor?.setBackgrounded(editorState.hostBackgrounded);
});

// ============================================================
// Initialization
// ============================================================
document.addEventListener("DOMContentLoaded", () => {
  // Detect CodeMirror 6 bundle
  if (typeof CM === "undefined") {
    // Fallback: create a simple textarea editor if CM bundle is missing
    createFallbackEditor();
    return;
  }

  const view = createEditor(editorState.content);
  window.editor._view = view;
  editorState.isReady = true;

  // Notify Swift that editor is ready
  swift.send("editorReady", true);

  // Focus editor
  setTimeout(() => { if (!editorState.backgrounded && !document.hidden) view.focus(); }, 100);
});

// ============================================================
// Fallback Editor (when JS bundle not yet downloaded)
// ============================================================
function createFallbackEditor() {
  const root = document.getElementById("editor-root");
  root.innerHTML = `
    <textarea id="fallback-editor" style="
      width: 100%; height: 100vh;
      border: none; outline: none;
      font-family: var(--font-body);
      font-size: var(--font-size);
      line-height: var(--line-height);
      background: var(--bg);
      color: var(--text);
      padding: 48px 60px;
      resize: none;
      caret-color: var(--accent);
    " placeholder="开始书写..."></textarea>
  `;

  const ta = document.getElementById("fallback-editor");
  ta.value = editorState.content;

  ta.addEventListener("input", () => {
    editorState.content = ta.value;
    swift.send("contentChanged", ta.value);
    updateWordCount(ta.value);
    updateOutline(ta.value);
  });

  // Override editor API for fallback
  window.editor = {
    setContent(c) { ta.value = c; editorState.content = c; },
    getContent() { return ta.value; },
    getRenderedHTML() {
      const body = typeof md !== "undefined" ? md.render(ta.value) : ta.value;
      return `<html><body>${body}</body></html>`;
    },
    setSourceMode() {},
    setTypewriterMode() {},
    setBackgrounded() {},
    captureSession() { return null; },
    execCommand() {},
    insertAtCursor(text) {
      const pos = ta.selectionStart;
      ta.value = ta.value.slice(0, pos) + text + ta.value.slice(pos);
    },
    _view: null,
  };

  swift.send("editorReady", true);
}
