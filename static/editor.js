import { basicSetup } from "https://esm.sh/@codemirror/basic-setup";
import { EditorView } from "https://esm.sh/@codemirror/view";
import { oneDark } from "https://esm.sh/@codemirror/theme-one-dark";
import { javascript } from "https://esm.sh/@codemirror/lang-javascript";

let tabs = [];
let active = 0;
let view;

const tabsEl = document.getElementById("tabs");
const status = document.getElementById("status");

function newTab(name = "untitled.txt", content = "") {
    tabs.push({ name, content, dirty: false });
    switchTab(tabs.length - 1);
}

function switchTab(i) {
    active = i;
    renderTabs();
    createEditor(tabs[i].content);
}

function renderTabs() {
    tabsEl.innerHTML = "";
    tabs.forEach((t, i) => {
        const el = document.createElement("div");
        el.className = "tab" + (i === active ? " active" : "");
        el.textContent = t.name + (t.dirty ? "*" : "");
        el.onclick = () => switchTab(i);
        tabsEl.appendChild(el);
    });
}

function createEditor(content) {
    if (view) view.destroy();

    view = new EditorView({
        doc: content,
        extensions: [
            basicSetup,
            javascript(),
            oneDark,
            EditorView.updateListener.of(update => {
                if (update.docChanged) {
                    tabs[active].dirty = true;
                    tabs[active].content = view.state.doc.toString();
                    renderTabs();
                }
                updateStatus();
            })
        ],
        parent: document.getElementById("editor")
    });
}

function updateStatus() {
    const pos = view.state.selection.main.head;
    const line = view.state.doc.lineAt(pos);
    status.textContent = `Ln ${line.number}, Col ${pos - line.from + 1} | UTF-8`;
}

async function save() {
    const t = tabs[active];
    await fetch("/save", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: t.name, content: t.content })
    });
    t.dirty = false;
    renderTabs();
}

document.addEventListener("keydown", e => {
    if (!(e.ctrlKey || e.metaKey)) return;

    switch (e.key.toLowerCase()) {
        case "s":
            e.preventDefault();
            save();
            break;
        case "n":
            e.preventDefault();
            newTab();
            break;
        case "o":
            e.preventDefault();
            fetch("/list").then(r => r.json()).then(files => {
                const f = prompt("Open file:", files.join("\n"));
                if (f) openFile(f);
            });
            break;
    }
});

async function openFile(name) {
    const res = await fetch("/open", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name })
    });
    const data = await res.json();
    newTab(name, data.content);
}

/* Start */
newTab();
