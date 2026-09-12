// Windows Desktop Integration
let currentFilePath = null;
let currentContent = "# Welcome to M Notes for Windows\n\n- [x] True WYSIWYG\n- [x] Fast Native Performance\n";
const iframe = document.getElementById("editor-frame");
const docTitle = document.getElementById("doc-title");

function getEditor() {
  return iframe.contentWindow?.editor;
}

iframe.addEventListener("load", () => {
  setTimeout(() => {
    getEditor()?.setContent(currentContent);
  }, 200);
});

// Shortcut listeners
window.addEventListener("keydown", (e) => {
  if (e.ctrlKey && e.key === "s") {
    e.preventDefault();
    saveFile();
  } else if (e.ctrlKey && e.key === "o") {
    e.preventDefault();
    openFile();
  } else if (e.ctrlKey && e.key === "n") {
    e.preventDefault();
    newFile();
  }
});

document.getElementById("btn-new").addEventListener("click", newFile);
document.getElementById("btn-open").addEventListener("click", openFile);
document.getElementById("btn-save").addEventListener("click", saveFile);

let themeIndex = 0;
const themes = ["system", "liquid-glass-light", "liquid-glass-dark", "dracula", "github-light", "github-dark"];
document.getElementById("btn-theme").addEventListener("click", () => {
  themeIndex = (themeIndex + 1) % themes.length;
  getEditor()?.setTheme(themes[themeIndex]);
});

function newFile() {
  currentFilePath = null;
  currentContent = "";
  getEditor()?.setContent("");
  docTitle.textContent = "M Notes - Untitled.md";
}

async function openFile() {
  try {
    if (window.__TAURI__?.dialog) {
      const selected = await window.__TAURI__.dialog.open({
        filters: [{ name: "Markdown / Plain Text", extensions: ["md", "markdown", "txt"] }]
      });
      if (selected) {
        currentFilePath = selected;
        const text = await window.__TAURI__.fs.readTextFile(selected);
        currentContent = text;
        getEditor()?.setContent(text);
        docTitle.textContent = `M Notes - ${selected.split(/\\\\|\\//).pop()}`;
      }
    } else {
      // Fallback web file picker
      const input = document.createElement("input");
      input.type = "file";
      input.accept = ".md,.markdown,.txt";
      input.onchange = (e) => {
        const file = e.target.files[0];
        if (file) {
          const reader = new FileReader();
          reader.onload = (evt) => {
            currentContent = evt.target.result;
            getEditor()?.setContent(currentContent);
            docTitle.textContent = `M Notes - ${file.name}`;
          };
          reader.readAsText(file);
        }
      };
      input.click();
    }
  } catch (err) {
    console.error("Open file error:", err);
  }
}

async function saveFile() {
  try {
    const text = getEditor()?.getContent() ?? currentContent;
    if (window.__TAURI__?.dialog && window.__TAURI__?.fs) {
      if (!currentFilePath) {
        currentFilePath = await window.__TAURI__.dialog.save({
          filters: [{ name: "Markdown", extensions: ["md"] }]
        });
      }
      if (currentFilePath) {
        await window.__TAURI__.fs.writeTextFile(currentFilePath, text);
        docTitle.textContent = `M Notes - ${currentFilePath.split(/\\\\|\\//).pop()}`;
      }
    } else {
      // Fallback web download save
      const blob = new Blob([text], { type: "text/markdown;charset=utf-8" });
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = currentFilePath ? currentFilePath.split(/\\\\|\\//).pop() : "Untitled.md";
      a.click();
    }
  } catch (err) {
    console.error("Save file error:", err);
  }
}
