/* Schematic cross-reference viewer - plain JavaScript, no dependencies. */
(() => {
"use strict";
const $ = (s) => document.querySelector(s);
const SVGNS = "http://www.w3.org/2000/svg";
const AUTO_GO = new Set(["verified", "matched", "backref", "typical", "sheet", "confirmed", "manual"]);
const STATUS_TEXT = { path: "signal path", dossier: "written on" };   // badge wording for statuses the viewer itself creates

const state = {
  project: null, sheets: [], sheetMeta: {}, sheetId: null, sheet: null,
  vb: { x: 0, y: 0, w: 100, h: 100 }, history: [], future: [],
  userLinks: [], linkMode: null, selected: null, issues: null, loading: false,
  trail: [],
  // explanations: drawing-set dossier and glossary (loaded on first use), the logic entry open in the Explain tab,
  // and a pending "signal path" hop (open the matching logic entry after the next navigation)
  dossier: null, glossary: null, explainSel: null, explainSheet: null, explainDirty: true, pathPending: null, whatSeq: 0,
};
const view = $("#view"), gContent = $("#content"), gHits = $("#hits"), gHl = $("#hl"), gBack = $("#backdrop"), gPaper = $("#paper");

// ------------------------------------------------------------------ helpers
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const fmt = (v) => Math.round(v * 100) / 100;
function el(tag, attrs, ns) {
  const e = ns ? document.createElementNS(SVGNS, tag) : document.createElement(tag);
  for (const k in attrs || {}) { if (k === "text") e.textContent = attrs[k]; else if (k === "html") e.innerHTML = attrs[k]; else e.setAttribute(k, attrs[k]); }
  return e;
}
function setStatus(msg, warn) { const m = $("#statusMsg"); m.textContent = msg || ""; m.style.color = warn ? "#ffcc80" : ""; }
function hlColor() { return $("#hlColor").value; }
function bboxToSvg(b) { return { x: b[0], y: -b[3], w: b[2] - b[0], h: b[3] - b[1] }; }
function textById(id) { return state.sheet && state.sheet._texts[id]; }
function sheetTitle(id) { const m = state.sheetMeta[id]; return m ? `${id} – ${m.title || ""}` : id; }
function showTab(name) {
  document.querySelectorAll("#tabs button").forEach((b) => b.classList.toggle("active", b.dataset.tab === name));
  document.querySelectorAll(".tab").forEach((t) => t.classList.toggle("active", t.id === "tab-" + name));
  if (name === "explain" && state.explainDirty) renderExplainTab();
}
const DATA = "data/";          // all URLs are relative so the page also works under a sub-path (GitHub Pages)
async function api(path, opts) {
  const r = await fetch(path.replace(/^\//, ""), opts);
  if (!r.ok) throw new Error(`${path}: ${r.status}`);
  return r.json();
}
async function fetchMaybeGz(url) {
  // Data files are stored gzip-compressed. The Python server sends them with
  // Content-Encoding (browser decodes); a plain static host sends raw gzip bytes.
  const r = await fetch(url);
  if (!r.ok) throw new Error(`${url}: ${r.status}`);
  const buf = new Uint8Array(await r.arrayBuffer());
  if (buf.length > 2 && buf[0] === 0x1f && buf[1] === 0x8b) {
    if (typeof DecompressionStream === "undefined") throw new Error("this browser cannot read the compressed drawing data; use a current Edge, Chrome, Firefox or Safari");
    const stream = new Blob([buf]).stream().pipeThrough(new DecompressionStream("gzip"));
    return new Response(stream).text();
  }
  return new TextDecoder("utf-8").decode(buf);
}
async function loadJSON(url) { return JSON.parse(await fetchMaybeGz(url)); }
async function detectMode() {
  // the local Python server marks the page; a static host (GitHub Pages) serves it unmarked
  state.serverMode = !!window.VIEWER_SERVER_MODE;
}
// ---- manual links: server file in server mode, browser storage (plus data/user_links.json) otherwise
const LS_KEY = () => `schematic_user_links:${(state.project && state.project.name) || "project"}`;
function linksForSheet(sid) {
  return (state.allUserLinks || []).filter((u) => (u.link_id || "").startsWith(sid + ":") || (u.from && u.from.sheet === sid) || (u.to && u.to.sheet === sid));
}
async function loadAllUserLinks() {
  if (state.serverMode) { try { return await api("api/user_links"); } catch (e) { return []; } }
  let fileLinks = [];
  try { fileLinks = await loadJSON(DATA + "user_links.json"); } catch (e) { fileLinks = []; }
  let local = [];
  try { local = JSON.parse(localStorage.getItem(LS_KEY()) || "[]"); } catch (e) { local = []; }
  const byKey = new Map();
  for (const u of [...fileLinks, ...local]) byKey.set(u.link_id ? "L:" + u.link_id : "I:" + u.id, u);
  return [...byKey.values()];
}
function applyLocally(list, body) {
  const action = body.action;
  if (action === "delete") return list.filter((L) => L.id !== body.id);
  if (action === "replace_all") return (body.links || []).slice();
  const entry = { ...body };
  entry.id = entry.id || "u" + Date.now();
  entry.created = new Date().toISOString().slice(0, 19).replace("T", " ");
  let out = entry.link_id ? list.filter((L) => L.link_id !== entry.link_id) : list.slice();
  out.push(entry);
  return out;
}
async function saveUserLink(body) {
  if (state.serverMode) {
    const res = await api("api/user_links", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
    state.allUserLinks = res.user_links;
  } else {
    state.allUserLinks = applyLocally(state.allUserLinks || [], body);
    try { localStorage.setItem(LS_KEY(), JSON.stringify(state.allUserLinks)); } catch (e) { setStatus("could not store the link in this browser: " + e.message, true); }
  }
  state.userLinks = linksForSheet(state.sheetId);
}
function exportUserLinks() {
  const blob = new Blob([JSON.stringify(state.allUserLinks || [], null, 1)], { type: "application/json" });
  const a = document.createElement("a"); a.href = URL.createObjectURL(blob); a.download = "user_links.json"; a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 2000);
}
async function importUserLinks(file) {
  try {
    const links = JSON.parse(await file.text());
    if (!Array.isArray(links)) throw new Error("not a list");
    await saveUserLink({ action: "replace_all", links });
    setStatus(`${links.length} manual link decisions loaded`);
    if (state.selected && state.selected.sheet === state.sheetId) selectText(textById(state.selected.text));
  } catch (e) { setStatus("could not read the file: " + e.message, true); }
}
// ---- search and appearances work on the client from two small index files
let searchRows = null, identIndex = null;
const normKey = (s) => String(s).replace(/\s+/g, "").toUpperCase();
async function searchTexts(q) {
  if (!searchRows) searchRows = await loadJSON(DATA + "search.json.gz");
  const qn = normKey(q);
  if (!qn) return [];
  const exact = [], prefix = [], partial = [];
  for (const [sheet, text, label, keys] of searchRows) {
    const tn = normKey(label);
    if (tn === qn || keys.includes(qn)) exact.push({ sheet, text, label, match: "exact" });
    else if (tn.startsWith(qn) || keys.some((k) => k.startsWith(qn))) prefix.push({ sheet, text, label, match: "prefix" });
    else if (tn.includes(qn)) partial.push({ sheet, text, label, match: "contains" });
  }
  return [...exact, ...prefix, ...partial].slice(0, 200);
}
async function appearances(sid, tid) {
  const t = textById(tid);
  if (!t) return { groups: [] };
  if (!identIndex) identIndex = await loadJSON(DATA + "index.json.gz");
  const groups = [], seenKeys = new Set(), seenOcc = new Set();
  for (const ident of t.idents || []) {
    const keys = [`${ident.kind}:${ident.key}`];
    if (ident.kind === "tag" && ident.extra && ident.extra.base) keys.push(`tagbase:${ident.extra.base}`);
    for (const k of keys) {
      if (seenKeys.has(k)) continue;
      seenKeys.add(k);
      const occ = (identIndex[k] || []).filter((o) => !(o.sheet === sid && o.text === tid) && !seenOcc.has(o.sheet + "|" + o.text));
      occ.forEach((o) => seenOcc.add(o.sheet + "|" + o.text));
      if (occ.length) groups.push({ key: k, kind: k.split(":")[0], label: ident.key, occurrences: occ });
    }
  }
  return { text: t, groups };
}

// ------------------------------------------------------------------ explanations ("what this is")
// The sheet JSON may carry `explain` = {kind, summary, facts[], logic[], nets{netId:{title,lines,kind}}, texts{textId:{title,lines}}},
// data/dossier.json.gz = {"kind:key": {title, lines[], entries:[{sheet,text,label,role,context[]}]}} and
// data/glossary.json = [{pattern, term, meaning, source}]. Every part is optional: the page shows what exists.
const arr = (x) => (Array.isArray(x) ? x : []);
const str = (x) => (x == null ? "" : String(x));
function explainOf(sheet) { const e = sheet && sheet.explain; return e && typeof e === "object" && !Array.isArray(e) ? e : null; }
function explainNets(sheet) { const e = explainOf(sheet); return e && e.nets && typeof e.nets === "object" ? e.nets : {}; }
function explainTexts(sheet) { const e = explainOf(sheet); return e && e.texts && typeof e.texts === "object" ? e.texts : {}; }
function explainLogic(sheet) { const e = explainOf(sheet); return e ? arr(e.logic).filter((x) => x && typeof x === "object") : []; }
let dossierP = null, glossaryP = null;
function loadDossier() {
  if (!dossierP) dossierP = loadJSON(DATA + "dossier.json.gz").then((d) => (state.dossier = d && typeof d === "object" && !Array.isArray(d) ? d : {})).catch(() => (state.dossier = {}));
  return dossierP;
}
const pyToJsRegex = (p) => str(p).replace(/\(\?P</g, "(?<").replace(/\\Z/g, "$");   // the glossary patterns are written for Python
function loadGlossary() {
  if (!glossaryP) glossaryP = loadJSON(DATA + "glossary.json").then((g) => {
    const out = [];
    for (const e of arr(g)) {
      if (!e || !e.pattern) continue;
      try { out.push({ rx: new RegExp(pyToJsRegex(e.pattern), e.ignore_case ? "i" : ""), entry: e }); } catch (err) { /* pattern not usable in this browser: skip it */ }
    }
    return (state.glossary = out);
  }).catch(() => (state.glossary = []));
  return glossaryP;
}
const fillTemplate = (tpl, m) => str(tpl).replace(/\{(\d+)\}/g, (_, i) => m[+i] || "").replace(/\s+/g, " ").trim();
const LETTER_KINDS = new Set(["tag_plant", "tag_letter", "tag_suffix", "tag_qualifier"]);   // letter-by-letter tag decoding: listed last
function glossaryMatches(text) {
  const t = str(text).replace(/\s+/g, " ").trim(); if (!t || !state.glossary) return [];
  const out = [];
  for (const { rx, entry } of state.glossary) {
    const m = rx.exec(t); if (!m) continue;
    out.push({ term: fillTemplate(entry.term, m) || t, meaning: fillTemplate(entry.meaning, m), source: str(entry.source), kind: str(entry.kind), letter: LETTER_KINDS.has(entry.kind) });
  }
  return out.sort((a, b) => (a.letter ? 1 : 0) - (b.letter ? 1 : 0));
}
function identKeys(t) {
  const keys = [];
  for (const i of arr(t && t.idents)) { if (!i || !i.kind) continue; keys.push(`${i.kind}:${i.key}`); if (i.kind === "tag" && i.extra && i.extra.base) keys.push(`tagbase:${i.extra.base}`); }
  return keys;
}
function dossierFor(t) {
  if (!state.dossier) return null;
  for (const k of identKeys(t)) { const d = state.dossier[k]; if (d && typeof d === "object") return { key: k, ...d }; }
  return null;
}
const firstSentence = (s) => { s = str(s); const i = s.indexOf(". "); return i > 0 ? s.slice(0, i + 1) : s; };
async function whatThisIs(t) {
  // -> {title, lines[], source, entries[], key} from the note on this sheet, the drawing-set dossier or the glossary, in that order; null when nothing is written
  if (!t) return null;
  const note = explainTexts(state.sheet)[t.id];
  const hasIdent = identKeys(t).length > 0;
  if (hasIdent && !state.dossier) await loadDossier();
  const dos = hasIdent ? dossierFor(t) : null;
  let res = null;
  if (note && (note.title || arr(note.lines).length)) res = { title: str(note.title) || t.text, lines: arr(note.lines).map(str), source: "sheet" };
  if (dos) {
    const lines = arr(dos.lines).map(str), general = lines.filter((l) => !/^Sheet \S+ \(/.test(l) && !/^Appears on /.test(l));
    if (!res) res = { title: str(dos.title) || t.text, lines: lines.filter((l) => !/^Appears on /.test(l)), source: "dossier" };
    else res.lines = res.lines.concat(general.filter((l) => !res.lines.includes(l)));
    res.entries = arr(dos.entries).filter((e) => e && e.sheet); res.key = dos.key;
  }
  if (!res) {
    if (!state.glossary) await loadGlossary();
    const g = glossaryMatches(t.text);
    if (g.length) {
      const same = normKey(g[0].term) === normKey(t.text);      // the term only repeats the text: the meaning is the news
      res = { title: same ? t.text : `${t.text}: ${g[0].term}`, source: "glossary",
              lines: g.slice(0, 4).map((x) => (normKey(x.term) === normKey(t.text) ? x.meaning : `${x.term}: ${x.meaning}`)).concat(g[0].source ? [`Source: ${g[0].source}`] : []) };
    }
  }
  return res;
}
function tipTitle(w) {   // one line for the compact note: the title, plus the first line that adds something when the title alone says little
  const t = str(w && w.title), tn = normKey(t);
  const extra = arr(w && w.lines).map(str).find((l) => { const body = normKey(l.replace(/^[^:]{1,24}:\s*/, "")).replace(/\.$/, ""); return body && !tn.includes(body); });
  const s = t.length < 24 && extra ? `${t}. ${firstSentence(extra)}` : t;
  return s.length > 170 ? s.slice(0, 167) + "..." : s;
}
function netTipTitle(w) {
  const t = str(w && w.title), l = arr(w && w.lines).map(str).find((x) => !/^Labels on this wire/.test(x) && !/^Part of the logic/.test(x)) || "";
  const s = l ? `${t}: ${firstSentence(l)}` : t;
  return s.length > 170 ? s.slice(0, 167) + "..." : s;
}
// ---- compact note next to the cursor: one line and a "More" button; it closes on the next click on the drawing, on Esc or with its x
function hideTip() { $("#tip").classList.add("hidden"); }
function showTip(pos, title, onMore) {
  const p = $("#tip"); if (!title) return;
  if (!$("#popup").classList.contains("hidden")) return;      // a choice list is open: it has priority
  $("#tipText").textContent = title;
  p.classList.remove("hidden");
  const r = $("#canvas").getBoundingClientRect();
  let x = pos && pos.clientX != null ? pos.clientX - r.left + 14 : 20, y = pos && pos.clientY != null ? pos.clientY - r.top + 16 : 20;
  x = Math.max(4, Math.min(x, r.width - p.offsetWidth - 8)); y = Math.max(4, Math.min(y, r.height - p.offsetHeight - 30));
  p.style.left = x + "px"; p.style.top = y + "px";
  $("#tipMore").onclick = () => { hideTip(); if (onMore) onMore(); };
  $("#tipClose").onclick = hideTip;
}
function posOfBox(bbox) {   // screen position just below the right end of a drawing box
  const r = view.getBoundingClientRect(), b = bboxToSvg(bbox);
  return { clientX: r.left + (b.x + b.w - state.vb.x) / state.vb.w * r.width, clientY: r.top + (b.y + b.h - state.vb.y) / state.vb.h * r.height };
}
function openSelection(anchor) {
  $("#side").classList.remove("hidden"); showTab("selection"); applyVB();
  const a = anchor && document.querySelector(anchor); if (a && a.scrollIntoView) a.scrollIntoView({ block: "start" });
}
async function tipForText(t, pos) {
  const seq = ++state.whatSeq;
  const w = await whatThisIs(t).catch(() => null);
  if (seq !== state.whatSeq || !w || !state.selected || state.selected.text !== t.id || state.selected.sheet !== state.sheetId) return;
  showTip(pos || posOfBox(t.bbox), tipTitle(w), () => openSelection("#what"));
}
async function renderWhat(t) {
  // the "What this is" block at the top of the Selection panel
  const box = $("#what"); if (!box) return;
  const w = await whatThisIs(t).catch(() => null);
  if ($("#what") !== box || !state.selected || state.selected.text !== t.id || state.selected.sheet !== state.sheetId) return;
  box.classList.remove("pending");
  if (!w) { box.innerHTML = `<div class="what-title">What this is</div><div class="what-line muted">Nothing more is written about "${esc(t.text)}": no note on this sheet, no dossier entry and no glossary term matches it.</div>`; return; }
  const SRC = { sheet: "Read from the texts and wiring of this sheet.", dossier: "Read from every sheet on which this identifier is written.", glossary: "Glossary term; the sheet it was read from is quoted as the source." };
  let h = `<div class="what-title">${esc(w.title)}</div>` + w.lines.map((l) => `<div class="what-line">${esc(l)}</div>`).join("");
  const nw = t.net != null ? explainNets(state.sheet)[String(t.net)] : null;
  if (nw && nw.title) h += `<div class="what-line muted">On wire: <span class="chip" data-net="${esc(t.net)}" title="highlight this wire and read what it carries">${esc(nw.title)}</span></div>`;
  h += `<div class="what-src">${SRC[w.source] || ""}</div>`;
  const entries = arr(w.entries);
  if (entries.length) {
    h += `<h4>Written on</h4>` + entries.map((e, i) => { const here = e.sheet === state.sheetId && e.text === t.id; return `<div class="row ${here ? "current" : ""}" data-dos="${i}" title="${esc(arr(e.context).join("; "))}"><span class="lbl">sheet <b>${esc(e.sheet)}</b> ${esc(e.role || "")}${here ? " <small>(this text)</small>" : ""}<br><small>${esc(arr(e.context).slice(0, 3).join("; "))}</small></span><span class="badge same">${esc(normKey(e.label || "") === normKey(t.text) ? "same label" : e.label || "")}</span></div>`; }).join("");
    h += `<div class="legend">Same identifier written elsewhere: not by itself a verified connection.</div>`;
  }
  box.innerHTML = h;
  box.querySelectorAll("[data-dos]").forEach((r) => (r.onclick = () => { const e = entries[+r.dataset.dos]; if (e.sheet === state.sheetId && e.text === t.id) return; navigate({ sheet: e.sheet, text: e.text, label: e.label || t.text, status: "dossier", note: e.role || "" }); }));
  const nc = box.querySelector(".chip[data-net]"); if (nc) nc.onclick = () => onNetClick(+nc.dataset.net, null, true);
}

// ------------------------------------------------------------------ view box / pan / zoom
function applyVB() {
  const { x, y, w, h } = state.vb;
  view.setAttribute("viewBox", `${x} ${y} ${w} ${h}`);
  // keep hit strokes and highlight strokes readable at any zoom
  const pxPerMm = view.clientWidth / w;
  const hitW = Math.max(0.6, 8 / pxPerMm);
  gHits.style.setProperty("--hitw", hitW);
  gHits.querySelectorAll(".hit-net").forEach((p) => p.setAttribute("stroke-width", hitW));
  gHl.querySelectorAll(".hl-net").forEach((p) => p.setAttribute("stroke-width", Math.max(0.9, 4 / pxPerMm)));
  gHl.querySelectorAll(".hl-box").forEach((p) => p.setAttribute("stroke-width", Math.max(0.5, 3 / pxPerMm)));
}
function setVB(x, y, w, h) { state.vb = { x, y, w, h }; applyVB(); }
function fitSheet() {
  const e = state.sheet ? state.sheet.extents : [0, 0, 420, 297];
  const m = 4, W = e[2] - e[0] + 2 * m, H = e[3] - e[1] + 2 * m;
  const ar = view.clientWidth / Math.max(1, view.clientHeight);
  let w = W, h = H;
  if (W / H > ar) h = W / ar; else w = H * ar;
  setVB(e[0] - m - (w - W) / 2, -(e[3] + m) - (h - H) / 2, w, h);
}
function clientToMm(cx, cy) {
  const r = view.getBoundingClientRect();
  return { x: state.vb.x + (cx - r.left) / r.width * state.vb.w, y: state.vb.y + (cy - r.top) / r.height * state.vb.h };
}
function zoomAt(cx, cy, factor) {
  const p = clientToMm(cx, cy);
  const w = Math.min(Math.max(state.vb.w / factor, 5), 20000), h = state.vb.h * (w / state.vb.w);
  const r = view.getBoundingClientRect();
  const fx = (cx - r.left) / r.width, fy = (cy - r.top) / r.height;
  setVB(p.x - fx * w, p.y - fy * h, w, h);
}
function zoomToBox(b, minW) {   // b in svg coords {x,y,w,h}
  const ar = view.clientWidth / Math.max(1, view.clientHeight);
  let w = Math.max(minW || 110, b.w * 7, (b.h * 7) * ar), h = w / ar;
  if (b.h * 1.5 > h) { h = b.h * 1.5; w = h * ar; }
  setVB(b.x + b.w / 2 - w / 2, b.y + b.h / 2 - h / 2, w, h);
}
function zoomToFit(b) {   // b in svg coords: show the whole box with a margin (used for the wiring of one logic output)
  const ar = view.clientWidth / Math.max(1, view.clientHeight);
  let w = Math.max(b.w * 1.15 + 10, 60), h = Math.max(b.h * 1.15 + 10, 40);
  if (w / h > ar) h = w / ar; else w = h * ar;
  setVB(b.x + b.w / 2 - w / 2, b.y + b.h / 2 - h / 2, w, h);
}
(function installPanZoom() {
  let drag = null;
  view.addEventListener("wheel", (e) => { e.preventDefault(); zoomAt(e.clientX, e.clientY, e.deltaY < 0 ? 1.25 : 0.8); }, { passive: false });
  // no pointer capture: it would retarget the click event away from the hit rectangles
  view.addEventListener("pointerdown", (e) => { if (e.button !== 0) return; drag = { x: e.clientX, y: e.clientY, vb: { ...state.vb }, moved: false }; });
  window.addEventListener("pointermove", (e) => {
    if (e.target === view || (e.target.ownerSVGElement === view)) updatePos(clientToMm(e.clientX, e.clientY));
    if (!drag) return;
    const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
    if (Math.abs(dx) + Math.abs(dy) > 3) drag.moved = true;
    if (drag.moved) { const r = view.getBoundingClientRect(); setVB(drag.vb.x - dx / r.width * drag.vb.w, drag.vb.y - dy / r.height * drag.vb.h, drag.vb.w, drag.vb.h); }
  });
  window.addEventListener("pointerup", () => { if (drag && drag.moved) view._suppressClick = true; drag = null; });
  view.addEventListener("dblclick", (e) => { zoomAt(e.clientX, e.clientY, 2); });
  view.addEventListener("click", (e) => {
    if (view._suppressClick) { view._suppressClick = false; return; }
    const t = e.target;
    if (t.classList && t.classList.contains("hit-text")) return onTextClick(t.dataset.id, e);
    if (t.classList && t.classList.contains("hit-net")) return onNetClick(+t.dataset.id, e);
    hidePopup();
  });
  window.addEventListener("resize", applyVB);
})();
function updatePos(p) {
  if (!state.sheet) return;
  const xmm = p.x, ymm = -p.y;
  const r = state.sheet.ruler; let grid = "";
  if (r) grid = `  grid ≈ ${Math.round((xmm - r[1]) / r[0])}`;
  $("#statusPos").textContent = `x ${fmt(xmm)} mm  y ${fmt(ymm)} mm${grid}`;
}

// ------------------------------------------------------------------ highlights
let pulseTimer = null;
function clearHighlights(keepSource) { gHl.querySelectorAll(keepSource ? ":not(.src-box)" : "*").forEach((n) => n.remove()); }
function pulseIt(node) {
  if ($("#hlPulse").checked) { node.classList.add("pulse"); clearTimeout(pulseTimer); pulseTimer = setTimeout(() => node.classList.remove("pulse"), 3300); }
}
function highlightBox(bbox, opts) {
  opts = opts || {};
  const b = bboxToSvg(bbox), pad = opts.pad != null ? opts.pad : Math.max(0.8, b.h * 0.35), c = opts.color || hlColor();
  const r = el("rect", { x: b.x - pad, y: b.y - pad, width: b.w + 2 * pad, height: b.h + 2 * pad, rx: 0.8, class: "hl-box" + (opts.cls ? " " + opts.cls : ""), fill: c, stroke: c }, true);
  gHl.appendChild(r); if (!opts.noPulse) pulseIt(r); applyVB(); return r;
}
function highlightPoint(x, y) {
  const c = hlColor(); const g = el("g", { class: "hl-point-group" }, true);
  g.appendChild(el("circle", { cx: x, cy: -y, r: 6, class: "hl-point", stroke: c }, true));
  g.appendChild(el("line", { x1: x, y1: -y - 9, x2: x, y2: -y + 9, class: "hl-point", stroke: c }, true));
  g.appendChild(el("line", { x1: x - 9, y1: -y, x2: x + 9, y2: -y, class: "hl-point", stroke: c }, true));
  gHl.appendChild(g); pulseIt(g); return g;
}
function highlightNet(net, color) {
  const d = net.segs.map((s) => `M${s[0]} ${-s[1]}L${s[2]} ${-s[3]}`).join("");
  const p = el("path", { d, class: "hl-net", stroke: color || hlColor() }, true);
  gHl.appendChild(p); pulseIt(p); applyVB(); return p;
}
function markSource(text) {
  gHl.querySelectorAll(".src-box").forEach((n) => n.remove());
  if (!text) return;
  const b = bboxToSvg(text.bbox), pad = 0.6;
  gHl.appendChild(el("rect", { x: b.x - pad, y: b.y - pad, width: b.w + 2 * pad, height: b.h + 2 * pad, class: "src-box" }, true));
}

// ------------------------------------------------------------------ sheet loading
async function loadSheet(id) {
  if (state.sheetId === id && state.sheet) return state.sheet;
  state.loading = true; setStatus(`loading sheet ${id} ...`);
  const [sheet, svgText] = await Promise.all([
    loadJSON(`${DATA}sheets/${id}.json.gz`),
    state.sheetMeta[id] && state.sheetMeta[id].svg ? fetchMaybeGz(`${DATA}sheets/${id}.svg.gz`).catch(() => "") : Promise.resolve(""),
  ]);
  sheet._texts = {}; sheet.texts.forEach((t) => (sheet._texts[t.id] = t));
  sheet._nets = {}; sheet.nets.forEach((n) => (sheet._nets[n.id] = n));
  sheet._shapes = {}; (sheet.shapes || []).forEach((s) => (sheet._shapes[s.id] = s));
  sheet._linksOut = {}; sheet.links.forEach((L) => ((sheet._linksOut[L.src_text] = sheet._linksOut[L.src_text] || []).push(L)));
  sheet._linksIn = {}; (sheet.links_in || []).forEach((L) => ((sheet._linksIn[L.to_text] = sheet._linksIn[L.to_text] || []).push(L)));
  state.sheet = sheet; state.sheetId = id; state.userLinks = linksForSheet(id);
  state.explainDirty = true; state.explainSel = null; hideTip();
  gContent.innerHTML = ""; gHits.innerHTML = ""; gHl.innerHTML = ""; gBack.innerHTML = ""; gPaper.innerHTML = "";
  const ex = sheet.extents, pm = 3;
  gPaper.appendChild(el("rect", { x: ex[0] - pm, y: -ex[3] - pm, width: ex[2] - ex[0] + 2 * pm, height: ex[3] - ex[1] + 2 * pm, fill: "#fff" }, true));
  if (svgText) {
    const doc = new DOMParser().parseFromString(svgText, "image/svg+xml");
    const root = doc.documentElement;
    while (root.firstChild) gContent.appendChild(document.adoptNode(root.firstChild));
  }
  buildBackdrop(id); buildHits(sheet); applyViewMode();
  $("#sheetSelect").value = id;
  $("#statusSheet").textContent = `${id}  ${sheet.title || ""}  ${sheet.rev ? "rev " + sheet.rev : ""}`;
  document.title = `${id} – ${sheet.title || ""} – Schematic Viewer`;
  try { history.replaceState(null, "", "#" + id); } catch (e) { /* ignore */ }
  document.querySelectorAll(".sheetlist .row").forEach((r) => r.classList.toggle("current", r.dataset.id === id));
  state.loading = false; setStatus(sheet.nets_skipped ? "wire tracing is off on this large layout sheet" : "");
  if ($("#tab-explain").classList.contains("active")) renderExplainTab();
  return sheet;
}
function buildBackdrop(id) {
  const m = state.sheetMeta[id];
  if (!m || !m.backdrop) { $("#viewMode").disabled = true; return; }
  $("#viewMode").disabled = !m.svg;   // PDF-only sheets can only show the page image
  const b = m.backdrop;
  const src = `${DATA}backdrops/${b.file}`;
  const img = el("image", { href: src, x: b.x, y: b.y, width: b.w, height: b.h, preserveAspectRatio: "none" }, true);
  img.setAttributeNS("http://www.w3.org/1999/xlink", "href", src);
  gBack.appendChild(img);
}
function applyViewMode() {
  const meta = state.sheetMeta[state.sheetId] || {};
  const mode = !meta.svg ? "pdf" : ($("#viewMode").disabled ? "vector" : $("#viewMode").value);
  gBack.style.display = mode === "vector" ? "none" : "";
  gContent.style.display = mode === "pdf" ? "none" : "";
  gContent.classList.toggle("overlay", mode === "overlay");
  const m = state.sheetMeta[state.sheetId];
  if (mode !== "vector" && m && m.backdrop && m.backdrop.quality !== "aligned") setStatus(`PDF page alignment is ${m.backdrop.quality} on this sheet`, true);
}
function buildHits(sheet) {
  const frag = document.createDocumentFragment();
  sheet.nets.forEach((n) => {
    if (!n.segs.length) return;
    const d = n.segs.map((s) => `M${s[0]} ${-s[1]}L${s[2]} ${-s[3]}`).join("");
    frag.appendChild(el("path", { d, class: "hit-net", "data-id": n.id }, true));
  });
  sheet.texts.forEach((t) => {
    if (t.frame) return;
    const b = bboxToSvg(t.bbox), pad = 0.35;
    const linked = (sheet._linksOut[t.id] || []).length > 0 || (sheet._linksIn[t.id] || []).length > 0 || (t.pointer && (sheet._linksOut[t.pointer] || []).length > 0);
    const cls = "hit-text" + (linked ? " linked" : (t.idents && t.idents.length ? " ident" : ""));
    const r = el("rect", { x: b.x - pad, y: b.y - pad, width: b.w + 2 * pad, height: b.h + 2 * pad, class: cls, "data-id": t.id }, true);
    r.appendChild(el("title", { text: t.text + (linked ? "  (cross-reference)" : "") }, true));
    frag.appendChild(r);
  });
  gHits.appendChild(frag);
}

// ------------------------------------------------------------------ navigation & history
function snapshot() { return { sheet: state.sheetId, vb: { ...state.vb }, label: state.selected ? state.selected.label : "" }; }
async function navigate(target, opts) {
  // target: {sheet, text?, bbox?, point?, label?, status?, color?}
  opts = opts || {};
  hideTip();
  if (!opts.noHistory && state.sheetId) { state.history.push(snapshot()); state.future = []; updateNavButtons(); }
  await loadSheet(target.sheet);
  clearHighlights(false);
  let bbox = target.bbox;
  if (!bbox && target.text && state.sheet._texts[target.text]) bbox = state.sheet._texts[target.text].bbox;
  if (bbox) { zoomToBox(bboxToSvg(bbox), opts.minW); highlightBox(bbox, { color: target.color }); }
  else if (target.point) { zoomToBox({ x: target.point[0] - 5, y: -target.point[1] - 5, w: 10, h: 10 }, 120); highlightPoint(target.point[0], target.point[1]); }
  else fitSheet();
  if (target.net != null && state.sheet._nets[target.net]) highlightNet(state.sheet._nets[target.net]);
  addTrail(target);
  const dest = target.text && state.sheet._texts[target.text];
  if (dest && !opts.keepSelection) { selectText(dest, { silent: true }); tipForText(dest, null); }
  if (target.status) setStatus(`${target.label || ""}  →  ${target.sheet}   [${STATUS_TEXT[target.status] || target.status}]${target.note ? "  " + target.note : ""}`, /ambiguous|unresolved|same/.test(target.status));
  updateNavButtons();
  const pp = state.pathPending; state.pathPending = null;    // a "signal path" hop: open the matching logic entry on the new sheet
  if (pp && pp.sheet === state.sheetId) arriveOnPath(pp);
}
async function goBack() {
  const s = state.history.pop(); if (!s) return;
  hideTip(); state.future.push(snapshot());
  await loadSheet(s.sheet); clearHighlights(false); setVB(s.vb.x, s.vb.y, s.vb.w, s.vb.h); updateNavButtons(); setStatus("back");
}
async function goForward() {
  const s = state.future.pop(); if (!s) return;
  hideTip(); state.history.push(snapshot());
  await loadSheet(s.sheet); clearHighlights(false); setVB(s.vb.x, s.vb.y, s.vb.w, s.vb.h); updateNavButtons();
}
function updateNavButtons() { $("#btnBack").disabled = !state.history.length; $("#btnFwd").disabled = !state.future.length; }
function addTrail(t) {
  state.trail.push({ sheet: t.sheet, label: t.label || (t.text && state.sheet._texts[t.text] ? state.sheet._texts[t.text].text : ""), status: t.status || "", text: t.text, bbox: t.bbox, point: t.point });
  if (state.trail.length > 200) state.trail.shift();
  renderTrail();
}
function renderTrail() {
  const box = $("#tab-trail"); box.innerHTML = "<h3>Navigation trail</h3><p class='muted'>Newest at the bottom. Click an entry to return there.</p>";
  state.trail.forEach((e, i) => {
    const row = el("div", { class: "row" });
    row.innerHTML = `<span class="lbl">${i + 1}. <b>${esc(e.sheet)}</b> ${esc(e.label)}</span>${e.status ? `<span class="badge ${esc(e.status)}">${esc(STATUS_TEXT[e.status] || e.status)}</span>` : ""}`;
    row.onclick = () => navigate({ sheet: e.sheet, text: e.text, bbox: e.bbox, point: e.point, label: e.label });
    box.appendChild(row);
  });
  box.scrollTop = box.scrollHeight;
}

// ------------------------------------------------------------------ link evaluation
function userDecision(linkId) { return state.userLinks.find((u) => u.link_id === linkId && (u.action === "confirm" || u.action === "reject")); }
function destinationsFor(text) {
  const out = [];
  const own = state.sheet._linksOut[text.id] || [];
  // a signal label such as '3A' carries the destinations of the pointer written beside it ('052.225')
  const viaPointer = (!own.length && text.pointer && state.sheet._linksOut[text.pointer]) || [];
  for (const L of own.concat(viaPointer)) {
    const d = userDecision(L.id);
    const status = d ? (d.action === "confirm" ? "confirmed" : "rejected") : L.status;
    out.push({ ...L, status, auto: true, decision: d });
  }
  for (const u of state.userLinks) {
    if (u.action === "create" && u.from && u.from.sheet === state.sheetId && u.from.text === text.id) {
      out.push({ id: u.id, kind: "manual", status: "manual", dst_sheet: u.to.sheet, dst_text: u.to.text, dst_point: u.to.point, label: u.to.label, note: u.note || "", user: u });
    }
  }
  const incoming = (state.sheet._linksIn[text.id] || []).slice();
  for (const u of state.userLinks) {
    if (u.action === "create" && u.to && u.to.sheet === state.sheetId && u.to.text === text.id) incoming.push({ id: u.id, from_sheet: u.from.sheet, from_text: u.from.text, status: "manual", label: u.from.label });
  }
  return { out, incoming };
}
const Q_STATUS = { 0: "verified", 1: "backref", 2: "matched", 3: "matched", 4: "backref" };
function topCandidates(L) {
  // only the candidates of the same quality as the best one are real alternatives
  const c = L.candidates || [];
  if (!c.length) return [];
  const q = c[0].q;
  const top = c.filter((x) => x.q === q);
  return top.length >= 2 ? top : c.slice(0, 3);
}
function candStatus(c, L) { return c.q != null ? Q_STATUS[c.q] || L.status : L.status; }
function linkTarget(L, labelOverride) {
  return { sheet: L.dst_sheet, text: L.dst_text, point: L.dst_point, label: labelOverride || L.label || "", status: L.status, note: L.note };
}

// ------------------------------------------------------------------ clicks
async function onTextClick(id, ev) {
  const t = textById(id); if (!t) return;
  hidePopup();
  if (state.linkMode) return completeManualLink(t);
  selectText(t);
  tipForText(t, ev);           // the compact "what this is" note next to the cursor
  const { out } = destinationsFor(t);
  const live = out.filter((L) => L.status !== "rejected");
  const direct = live.filter((L) => AUTO_GO.has(L.status) && L.dst_sheet && (L.dst_text || L.dst_point || L.kind === "sheet" || L.kind === "typical"));
  if (live.length === 1 && direct.length === 1) return navigate(linkTarget(direct[0], t.text), { keepSelection: false });
  if (live.length >= 1) return showChoices(t, live, ev);
  // no explicit pointer: offer the other appearances of the same identifier
  const app = await appearances(state.sheetId, id);
  renderAppearances(t, app);
  const occ = app.groups.flatMap((g) => g.occurrences.map((o) => ({ ...o, kind: g.kind, key: g.label })));
  if (occ.length === 1) return navigate({ sheet: occ[0].sheet, text: occ[0].text, label: t.text, status: "same label", note: "repeated label – not a verified connection" });
  if (occ.length > 1) return showAppearancePopup(t, app, ev);
  if (t.net != null) {
    // nothing to jump to: show which conductor on this page the label belongs to
    onNetClick(t.net, ev, true, t);
    return setStatus(`"${t.text}" has no cross-reference and appears on no other sheet – showing the conductor it is written on`, true);
  }
  setStatus(`"${t.text}" has no cross-reference and appears on no other sheet`, true);
}
function onNetClick(netId, ev, fromText, fromLabel) {
  hidePopup();
  const net = state.sheet._nets[netId]; if (!net) return;
  clearHighlights(true); highlightNet(net);
  const exits = netExits(net);
  renderNetPanel(net, exits, fromLabel);
  const words = explainNets(state.sheet)[String(netId)];
  const wordsHtml = words && words.title ? `<div class="what-line">${esc(netTipTitle(words))}</div>` : "";
  const direct = exits.filter((x) => AUTO_GO.has(x.link.status));
  if (!fromText && direct.length === 1 && exits.length === 1) {
    setStatus(`wire → ${direct[0].text.text} → sheet ${direct[0].link.dst_sheet}`);
    setTimeout(() => navigate(linkTarget(direct[0].link, direct[0].text.text)), 350);
  } else if (exits.length > 1) {
    showPopup(ev, wordsHtml + `<h4>Where does this wire go?</h4>` + exits.map((x, i) => rowHtml(x.link, x.text.text, `data-exit="${i}"`)).join(""), (p) => {
      p.querySelectorAll("[data-exit]").forEach((r) => (r.onclick = () => { const x = exits[+r.dataset.exit]; hidePopup(); navigate(linkTarget(x.link, x.text.text)); }));
    });
  } else if (!exits.length) setStatus(`wire highlighted (${net.segs.length} segment${net.segs.length > 1 ? "s" : ""}) – no cross-reference attached`);
  if (words && words.title && ev && ev.clientX != null) showTip(ev, netTipTitle(words), () => openSelection("#what"));
}
function netExits(net) {
  const ids = new Set(net.texts || []);
  (net.shapes || []).forEach((sid) => { const sh = state.sheet._shapes[sid]; if (sh) sh.texts.forEach((t) => ids.add(t)); });
  // texts right next to a shape (the pointer text usually sits outside the box)
  const exits = [];
  for (const tid of ids) {
    const t = textById(tid); if (!t) continue;
    const { out } = destinationsFor(t);
    out.filter((L) => L.status !== "rejected").forEach((L) => exits.push({ text: t, link: L }));
    // companion pointer next to a box label (e.g. '3A' box with '052.225' beside it)
    for (const other of state.sheet.texts) {
      if (other.frame || ids.has(other.id)) continue;
      const L2 = state.sheet._linksOut[other.id]; if (!L2) continue;
      if (Math.abs((other.bbox[1] + other.bbox[3]) / 2 - (t.bbox[1] + t.bbox[3]) / 2) < 1.5 && Math.abs(other.bbox[0] - t.bbox[2]) < 6) {
        L2.forEach((L) => { if (!exits.some((x) => x.link.id === L.id)) exits.push({ text: other, link: { ...L, status: (userDecision(L.id) || {}).action === "reject" ? "rejected" : L.status } }); });
      }
    }
  }
  return exits.filter((x) => x.link.status !== "rejected");
}

// ------------------------------------------------------------------ panels
function rowHtml(L, label, extraAttr) {
  const dest = L.dst_sheet ? `→ <b>${esc(L.dst_sheet)}</b> ${esc(sheetTitle(L.dst_sheet).slice(6, 40))}` : "";
  const n = L.candidates && L.candidates.length > 1 && !AUTO_GO.has(L.status) ? topCandidates(L).length : 0;
  const cand = n > 1 ? ` <small>(${n} candidates)</small>` : "";
  return `<div class="row ${L.status === "rejected" ? "rejected" : ""}" ${extraAttr || ""}><span class="lbl"><b>${esc(label || L.label || "")}</b> ${dest}${cand}${L.note ? `<br><small>${esc(L.note)}</small>` : ""}</span><span class="badge ${esc(L.status)}">${esc(L.status)}</span></div>`;
}
function selectText(t, opts) {
  state.selected = { sheet: state.sheetId, text: t.id, label: t.text };
  markSource(t);
  const { out, incoming } = destinationsFor(t);
  const box = $("#tab-selection");
  let h = `<div class="sel-title">${esc(t.text)}</div><div class="muted">sheet ${esc(state.sheetId)} · ${esc(t.kind)} · x ${fmt((t.bbox[0] + t.bbox[2]) / 2)} mm, y ${fmt((t.bbox[1] + t.bbox[3]) / 2)} mm</div>`;
  if (t.idents && t.idents.length) h += `<div>${t.idents.map((i) => `<span class="chip">${esc(i.kind)}: ${esc(i.key)}</span>`).join("")}</div>`;
  h += `<div class="what pending" id="what">looking up what this is ...</div>`;
  h += `<div style="margin:6px 0"><button class="small" id="selLink">+ Link from here</button> <button class="small" id="selWire" ${t.net == null ? "disabled" : ""}>Highlight wire</button> <button class="small" id="selApp">Other appearances</button></div>`;
  if (out.length) {
    h += `<h4>Destinations</h4>` + out.map((L, i) => rowHtml(L, L.label || t.text, `data-out="${i}"`) +
      (L.auto ? `<div style="margin:-2px 0 6px 6px"><button class="small" data-confirm="${i}">Confirm</button> <button class="small" data-reject="${i}">Reject</button>${L.decision ? ` <small class="muted">(${esc(L.decision.action)}ed ${esc(L.decision.created || "")})</small>` : ""}</div>` :
        `<div style="margin:-2px 0 6px 6px"><button class="small" data-delete="${i}">Delete manual link</button></div>`)).join("");
    const amb = out.filter((L) => L.candidates && L.candidates.length > 1 && !AUTO_GO.has(L.status));
    for (const L of amb) {
      h += `<div class="note">${esc(L.status === "multiple" ? "Several verified destinations – choose one:" : "Automatic detection is uncertain – candidates:")}</div>`;
      h += topCandidates(L).map((c) => { const j = L.candidates.indexOf(c); return `<div class="row" data-cand="${esc(L.id)}|${j}"><span class="lbl"><b>${esc(c.label)}</b> → ${esc(c.sheet)} <small>${esc(c.why || "")}, grid Δ ${esc(c.grid_dist ?? "")} mm</small></span><span class="badge ${esc(candStatus(c, L))}">${esc(candStatus(c, L))}</span><button class="small">Go</button></div>`; }).join("");
    }
  }
  if (incoming.length) {
    h += `<h4>Referenced from</h4>` + incoming.map((L, i) => `<div class="row" data-in="${i}"><span class="lbl">sheet <b>${esc(L.from_sheet)}</b> ${esc(L.label || "")}</span><span class="badge ${esc(L.status)}">${esc(L.status)}</span></div>`).join("");
  }
  if (t.shape != null && state.sheet._shapes[t.shape]) {
    const sh = state.sheet._shapes[t.shape];
    const others = sh.texts.filter((x) => x !== t.id).map((x) => textById(x)).filter(Boolean);
    if (others.length) h += `<h4>In the same symbol</h4><div>${others.map((o) => `<span class="chip">${esc(o.text)}</span>`).join("")}</div>`;
    if (sh.nets && sh.nets.length) h += `<div style="margin:4px 0"><button class="small" data-shapenets="1">Highlight wires at this symbol (${sh.nets.length})</button></div>`;
  }
  if (!out.length && !incoming.length) h += `<p class="muted" id="appHint">No explicit cross-reference on this text. Other appearances of the same identifier are listed when you click it.</p>`;
  h += `<div id="appearances"></div>`;
  box.innerHTML = h;
  box.querySelectorAll("[data-out]").forEach((r) => (r.onclick = () => { const L = out[+r.dataset.out]; if (L.dst_sheet) navigate(linkTarget(L, t.text)); }));
  box.querySelectorAll("[data-in]").forEach((r) => (r.onclick = () => { const L = incoming[+r.dataset.in]; navigate({ sheet: L.from_sheet, text: L.from_text, label: L.label || "", status: L.status }); }));
  box.querySelectorAll("[data-cand]").forEach((r) => (r.onclick = () => { const [lid, j] = r.dataset.cand.split("|"); const L = out.find((x) => x.id === lid); const c = L.candidates[+j]; navigate({ sheet: c.sheet, text: c.text, label: t.text, status: candStatus(c, L), note: c.why }); }));
  box.querySelectorAll("[data-confirm]").forEach((b) => (b.onclick = () => decide(out[+b.dataset.confirm], "confirm", t)));
  box.querySelectorAll("[data-reject]").forEach((b) => (b.onclick = () => decide(out[+b.dataset.reject], "reject", t)));
  box.querySelectorAll("[data-delete]").forEach((b) => (b.onclick = () => deleteUserLink(out[+b.dataset.delete].user.id, t)));
  const sn = box.querySelector("[data-shapenets]"); if (sn) sn.onclick = () => { clearHighlights(true); state.sheet._shapes[t.shape].nets.forEach((n) => highlightNet(state.sheet._nets[n])); };
  $("#selLink").onclick = () => startLinkMode(t);
  $("#selWire").onclick = () => onNetClick(t.net, null, true);
  $("#selApp").onclick = async () => { renderAppearances(t, await appearances(state.sheetId, t.id)); };
  renderWhat(t);
  if (!(opts && opts.silent)) showTab("selection");
}
function renderAppearances(t, app) {
  const box = $("#appearances"); if (!box) return;
  if (!app.groups.length) { box.innerHTML = `<h4>Other appearances</h4><p class="muted">The identifier "${esc(t.text)}" was not found on any other sheet.</p>`; return; }
  let h = `<h4>Other appearances</h4><div class="note">Same label elsewhere. This is <b>not</b> a verified electrical connection – check the drawing before relying on it.</div>`;
  app.groups.forEach((g, gi) => {
    h += `<div class="muted" style="margin-top:6px">${esc(g.kind)} <b>${esc(g.label)}</b> – ${g.occurrences.length} place${g.occurrences.length > 1 ? "s" : ""}</div>`;
    h += g.occurrences.map((o, oi) => `<div class="row" data-app="${gi}|${oi}"><span class="lbl">sheet <b>${esc(o.sheet)}</b> ${esc(o.label)} <small>${esc(sheetTitle(o.sheet).slice(6, 44))}</small></span><span class="badge same">same label</span></div>`).join("");
  });
  box.innerHTML = h;
  box.querySelectorAll("[data-app]").forEach((r) => (r.onclick = () => { const [gi, oi] = r.dataset.app.split("|").map(Number); const o = app.groups[gi].occurrences[oi]; navigate({ sheet: o.sheet, text: o.text, label: t.text, status: "same label", note: "repeated label – not a verified connection" }); }));
  showTab("selection");
}
function showAppearancePopup(t, app, ev) {
  const occ = app.groups.flatMap((g) => g.occurrences.map((o) => ({ ...o, kind: g.kind })));
  showPopup(ev, `<h4>"${esc(t.text)}" also appears on</h4><div class="note">same label – not verified as a connection</div>` +
    occ.map((o, i) => `<div class="row" data-i="${i}"><span class="lbl">sheet <b>${esc(o.sheet)}</b> ${esc(o.label)} <small>${esc((state.sheetMeta[o.sheet] || {}).title || "")}</small></span><span class="badge same">${esc(o.kind)}</span></div>`).join(""),
    (p) => p.querySelectorAll("[data-i]").forEach((r) => (r.onclick = () => { const o = occ[+r.dataset.i]; hidePopup(); navigate({ sheet: o.sheet, text: o.text, label: t.text, status: "same label", note: "repeated label – not a verified connection" }); })));
}
function showChoices(t, links, ev) {
  // one uncertain link with candidates, or several links
  let items = [];
  for (const L of links) {
    if (L.candidates && L.candidates.length > 1 && !AUTO_GO.has(L.status)) topCandidates(L).forEach((c) => items.push({ label: c.label, sheet: c.sheet, text: c.text, status: candStatus(c, L), why: c.why, grid: c.grid_dist }));
    else if (L.dst_sheet) items.push({ label: L.label || t.text, sheet: L.dst_sheet, text: L.dst_text, point: L.dst_point, status: L.status, why: L.note || L.kind });
  }
  if (items.length === 1 && AUTO_GO.has(items[0].status)) return navigate({ sheet: items[0].sheet, text: items[0].text, point: items[0].point, label: t.text, status: items[0].status });
  if (!items.length) return setStatus(`"${t.text}": ${links[0].note || links[0].status}`, true);
  showPopup(ev, `<h4>${esc(t.text)} – ${items.length} possible destination${items.length > 1 ? "s" : ""}</h4>` +
    items.map((it, i) => `<div class="row" data-i="${i}"><span class="lbl"><b>${esc(it.label)}</b> → sheet ${esc(it.sheet)} <small>${esc(it.why || "")}${it.grid != null ? ", grid Δ " + it.grid + " mm" : ""}</small></span><span class="badge ${esc(it.status)}">${esc(it.status)}</span></div>`).join(""),
    (p) => p.querySelectorAll("[data-i]").forEach((r) => (r.onclick = () => { const it = items[+r.dataset.i]; hidePopup(); navigate({ sheet: it.sheet, text: it.text, point: it.point, label: t.text, status: it.status, note: it.why }); })));
}
function showPopup(ev, html, wire) {
  const p = $("#popup"); p.innerHTML = html + `<div style="text-align:right;margin-top:4px"><button class="small" id="popClose">close</button></div>`;
  p.classList.remove("hidden"); hideTip();
  const r = $("#canvas").getBoundingClientRect();
  let x = ev ? ev.clientX - r.left + 12 : 20, y = ev ? ev.clientY - r.top + 12 : 20;
  x = Math.min(x, r.width - 380); y = Math.min(y, r.height - 60 - Math.min(p.offsetHeight, r.height / 2));
  p.style.left = Math.max(4, x) + "px"; p.style.top = Math.max(4, y) + "px";
  $("#popClose").onclick = hidePopup; if (wire) wire(p);
}
function hidePopup() { $("#popup").classList.add("hidden"); hideTip(); }
function renderNetPanel(net, exits, fromLabel) {
  const box = $("#tab-selection");
  const labels = (net.texts || []).map((id) => textById(id)).filter(Boolean);
  const shapes = (net.shapes || []).map((id) => state.sheet._shapes[id]).filter(Boolean);
  const words = explainNets(state.sheet)[String(net.id)];
  let h = `<div class="sel-title">${fromLabel ? "Conductor of “" + esc(fromLabel.text) + "”" : "Conductor"} on sheet ${esc(state.sheetId)}</div>`;
  if (fromLabel) h += `<div class="note">“${esc(fromLabel.text)}” has no cross-reference and is not written on any other sheet, so there is nowhere to jump. The green highlight shows the piece of wiring this label belongs to on this page, as drawn.</div>`;
  if (fromLabel) h += `<div class="what pending" id="what">looking up what this is ...</div>`;
  if (words && (words.title || arr(words.lines).length)) {
    h += `<div class="what"${fromLabel ? "" : ' id="what"'}><div class="what-title">${esc(words.title || "What this wire carries")}</div>${arr(words.lines).map((l) => `<div class="what-line">${esc(l)}</div>`).join("")}<div class="what-src">Read from the labels on this wire and the symbols it reaches.</div></div>`;
  }
  h += `<div class="muted">${net.segs.length} drawn segment${net.segs.length > 1 ? "s" : ""}. Wires are joined at corners and junction dots and stop at device symbols; crossing lines are not joined.</div>`;
  if (labels.length) h += `<h4>Labels on this wire</h4><div>${labels.map((t) => `<span class="chip" data-t="${esc(t.id)}">${esc(t.text)}</span>`).join("")}</div>`;
  if (shapes.length) h += `<h4>Symbols it touches</h4><div>${shapes.map((s) => `<span class="chip">${esc(s.texts.map((x) => (textById(x) || {}).text).filter(Boolean).join(" ") || "symbol")}</span>`).join("")}</div>`;
  h += `<h4>Where it goes</h4>`;
  h += exits.length ? exits.map((x, i) => rowHtml(x.link, x.text.text, `data-exit="${i}"`)).join("") : `<p class="muted">No cross-reference text is attached to this wire.</p>`;
  box.innerHTML = h;
  box.querySelectorAll("[data-exit]").forEach((r) => (r.onclick = () => { const x = exits[+r.dataset.exit]; navigate(linkTarget(x.link, x.text.text)); }));
  box.querySelectorAll(".chip[data-t]").forEach((c) => (c.onclick = () => { const t = textById(c.dataset.t); selectText(t); highlightBox(t.bbox, { noPulse: true }); }));
  if (fromLabel) renderWhat(fromLabel);
  showTab("selection");
}

// ------------------------------------------------------------------ manual links & decisions
function startLinkMode(t) {
  state.linkMode = { from: { sheet: state.sheetId, text: t.id, label: t.text } };
  setStatus(`LINK MODE: now click the destination text for "${t.text}" (any sheet). Esc cancels.`, true);
  $("#btnLink").classList.add("primary");
}
async function completeManualLink(t) {
  const lm = state.linkMode; state.linkMode = null; $("#btnLink").classList.remove("primary");
  const note = prompt(`Create link\n  from: sheet ${lm.from.sheet}  "${lm.from.label}"\n  to:   sheet ${state.sheetId}  "${t.text}"\n\nOptional note:`, "");
  if (note === null) return setStatus("link cancelled");
  await saveUserLink({ action: "create", from: lm.from, to: { sheet: state.sheetId, text: t.id, label: t.text }, note });
  setStatus(`manual link saved: ${lm.from.label} → sheet ${state.sheetId} ${t.text}` + (state.serverMode ? "" : " (stored in this browser; use Help → Export to keep a file)"));
  selectText(t);
}
async function decide(L, action, t) {
  await saveUserLink({ action, link_id: L.id, from: { sheet: state.sheetId, text: t.id, label: t.text }, to: { sheet: L.dst_sheet, text: L.dst_text } });
  setStatus(`${action}ed: ${t.text} → ${L.dst_sheet}`); selectText(t);
}
async function deleteUserLink(id, t) {
  await saveUserLink({ action: "delete", id }); selectText(t);
}

// ------------------------------------------------------------------ search / issues / sheets
async function doSearch() {
  const q = $("#searchBox").value.trim(); if (!q) return;
  showTab("search");
  const box = $("#tab-search"); box.innerHTML = `<p class="muted">searching "${esc(q)}" ...</p>`;
  const r = await searchTexts(q);
  if (!r.length) { box.innerHTML = `<h3>"${esc(q)}"</h3><p class="muted">No text matches. Try a shorter part of the identifier.</p>`; return; }
  const bySheet = {}; r.forEach((x) => (bySheet[x.sheet] = bySheet[x.sheet] || []).push(x));
  let h = `<h3>"${esc(q)}" – ${r.length} match${r.length > 1 ? "es" : ""} on ${Object.keys(bySheet).length} sheet${Object.keys(bySheet).length > 1 ? "s" : ""}</h3>`;
  for (const sid of Object.keys(bySheet)) {
    h += `<div class="muted" style="margin-top:6px"><b>${esc(sid)}</b> ${esc((state.sheetMeta[sid] || {}).title || "")}</div>`;
    h += bySheet[sid].map((x) => `<div class="row" data-s="${esc(x.sheet)}" data-t="${esc(x.text)}"><span class="lbl">${esc(x.label)}</span><span class="badge ${x.match === "exact" ? "verified" : ""}">${esc(x.match)}</span></div>`).join("");
  }
  box.innerHTML = h;
  box.querySelectorAll(".row[data-s]").forEach((row) => (row.onclick = () => navigate({ sheet: row.dataset.s, text: row.dataset.t, label: q, status: "search" })));
  if (r.length === 1) navigate({ sheet: r[0].sheet, text: r[0].text, label: q, status: "search" });
}
async function loadIssues() {
  const issues = await loadJSON(DATA + "issues.json"); state.issues = issues;
  const box = $("#tab-issues");
  const statuses = [...new Set(issues.map((i) => i.status))];
  let h = `<h3>${issues.length} references to review</h3><p class="muted">Automatic detection was not certain for these. Click to open the source; use Confirm / Reject or create a manual link.</p><div class="filters">${statuses.map((s) => `<label><input type="checkbox" checked data-f="${esc(s)}"> <span class="badge ${esc(s)}">${esc(s)}</span></label>`).join("")}</div><div id="issueRows"></div>`;
  box.innerHTML = h;
  const render = () => {
    const on = new Set([...box.querySelectorAll("[data-f]")].filter((c) => c.checked).map((c) => c.dataset.f));
    $("#issueRows").innerHTML = issues.filter((i) => on.has(i.status)).map((i, k) => `<div class="row" data-k="${issues.indexOf(i)}"><span class="lbl"><b>${esc(i.sheet)}</b> ${esc(i.text)} ${i.label ? "<small>(" + esc(i.label) + ")</small>" : ""} → ${esc(i.dst_sheet || "?")}<br><small>${esc(i.note || (i.candidates && i.candidates.length ? "candidates: " + i.candidates.join(", ") : ""))}</small></span><span class="badge ${esc(i.status)}">${esc(i.status)}</span></div>`).join("");
    $("#issueRows").querySelectorAll(".row").forEach((r) => (r.onclick = () => { const i = issues[+r.dataset.k]; const tid = i.link.split(":")[1]; navigate({ sheet: i.sheet, text: tid, label: i.text, status: i.status }); }));
  };
  box.querySelectorAll("[data-f]").forEach((c) => (c.onchange = render)); render();
}
function renderSheetList() {
  const box = $("#tab-sheets"); box.innerHTML = `<h3>${state.sheets.length} sheets</h3><div class="sheetlist"></div>`;
  const list = box.querySelector(".sheetlist");
  state.sheets.forEach((s) => {
    const row = el("div", { class: "row", "data-id": s.id });
    row.innerHTML = `<span class="lbl"><b>${esc(s.id)}</b> ${esc(s.title || "")}<br><small>${s.links} links · ${s.nets} wires${s.pdf_page ? " · PDF page " + s.pdf_page : ""}${s.warnings && s.warnings.length ? " · ⚠ " + esc(s.warnings[0]) : ""}</small></span><button class="small" data-explain="${esc(s.id)}" title="What this sheet does">Explain</button>`;
    row.onclick = () => navigate({ sheet: s.id, label: s.title });
    row.querySelector("[data-explain]").onclick = async (ev) => { ev.stopPropagation(); if (state.sheetId !== s.id) await navigate({ sheet: s.id, label: s.title }); openExplain(); };
    list.appendChild(row);
  });
}

// ------------------------------------------------------------------ Explain sheet: summary, facts, logic outline, signal path
const KIND_ORDER = ["continuation", "incoming", "other", "converter", "dv", "annunciator"];
const KIND_TITLE = { continuation: "Signals leaving this sheet", incoming: "Signals arriving from other sheets", other: "Process device outputs", converter: "Analogue outputs through converters", dv: "DeltaV Modbus points", annunciator: "Annunciator windows" };
const SHEET_KIND = { fld: "functional logic diagram", power: "power distribution", card: "distribution card", loop_input: "loop drawing, inputs", loop_output: "loop drawing, outputs", typical: "typical loops", elco: "ELCO schedule", annunciator: "annunciator wiring", layout: "layout drawing", schedule: "schedule" };
function entryArrow(e) {   // short form for the list rows: '3B → 052'
  if (e.kind === "continuation") return `→ ${e.dest_sheet || "?"}`;
  if (e.kind === "incoming") return `← ${e.from_sheet || "?"}`;
  if (e.kind === "converter") return [e.signal_in, e.signal_out].filter(Boolean).join(" → ") || "converter";
  if (e.kind === "dv") return "tap";
  if (e.kind === "annunciator") return "window";
  if (e.kind === "other") return arr(e.via).length ? "via " + e.via.join(", ") : "device output";
  return str(e.kind);
}
function entryWords(e) {   // sentence form for the status line
  if (e.kind === "continuation") return `leaves to sheet ${e.dest_sheet || "?"}`;
  if (e.kind === "incoming") return `arrives from sheet ${e.from_sheet || "?"}`;
  if (e.kind === "converter") return `converter ${e.signal_in || ""} to ${e.signal_out || ""}`.replace(/\s+/g, " ");
  if (e.kind === "dv") return "DeltaV point";
  if (e.kind === "annunciator") return "annunciator window";
  return "output";
}
function entryBadge(e) { return e.link_status ? `<span class="badge ${esc(e.link_status)}">${esc(e.link_status)}</span>` : `<span class="badge kind">${esc(e.kind || "")}</span>`; }
function shortExpr(e, n) { const x = str(e.expr); n = n || 70; return x.length > n ? x.slice(0, n - 3) + "..." : x; }
function openExplain() { $("#side").classList.remove("hidden"); applyVB(); renderExplainTab(); showTab("explain"); }
function renderExplainTab() {
  const box = $("#tab-explain"); state.explainDirty = false; state.explainSheet = state.sheetId;
  if (!state.sheet) { box.innerHTML = `<p class="muted">No sheet loaded.</p>`; return; }
  const ex = explainOf(state.sheet), sid = state.sheetId;
  let h = `<h3>Sheet ${esc(sid)} <span class="muted" style="font-weight:400">${esc(state.sheet.title || "")}</span></h3>`;
  if (!ex) { box.innerHTML = h + `<div class="note">No explanation data for this sheet. The importer produces it; run the import again with the current version of the program.</div>`; return; }
  if (ex.kind) h += `<div><span class="badge kind">${esc(SHEET_KIND[ex.kind] || ex.kind)}</span></div>`;
  if (ex.summary) h += `<p class="summary">${esc(ex.summary)}</p>`;
  arr(ex.warnings).forEach((w) => (h += `<div class="note warn">${esc(w)}</div>`));
  const facts = arr(ex.facts).map(str).filter(Boolean), SHOW = 10;
  if (facts.length) {
    h += `<h4>Facts read from the drawing</h4><ul class="facts">${facts.map((f, i) => `<li${i >= SHOW ? ' class="hidden more-fact"' : ""}>${esc(f)}</li>`).join("")}</ul>`;
    if (facts.length > SHOW) h += `<button class="small" id="moreFacts">show all ${facts.length} facts</button>`;
  }
  const logic = explainLogic(state.sheet);
  if (logic.length) {
    h += `<h4>Logic, one row per output</h4><p class="legend">Click a row to highlight everything that takes part in it and to read the logic as an outline. Click a line of the outline to highlight that input on the drawing.</p>`;
    const kinds = KIND_ORDER.concat(logic.map((e) => e.kind || "other").filter((k) => !KIND_ORDER.includes(k)));
    for (const k of [...new Set(kinds)]) {
      const rows = logic.filter((e) => (e.kind || "other") === k); if (!rows.length) continue;
      h += `<div class="muted" style="margin-top:8px"><b>${esc(KIND_TITLE[k] || k)}</b> (${rows.length})</div>`;
      h += rows.map((e) => `<div class="row logic-row" data-e="${logic.indexOf(e)}" title="${esc(str(e.expr))}"><span class="lbl"><b>${esc(e.output || "?")}</b> ${esc(entryArrow(e))}${e.expr ? ` <small>${esc(shortExpr(e))}</small>` : ""}</span>${entryBadge(e)}</div>`).join("");
    }
  } else if (ex.kind === "fld") h += `<p class="muted">No logic could be traced on this sheet.</p>`;
  if (!ex.summary && !facts.length && !logic.length) h += `<p class="muted">The explanation data for this sheet is empty.</p>`;
  box.innerHTML = h;
  const mf = $("#moreFacts"); if (mf) mf.onclick = () => { box.querySelectorAll(".more-fact").forEach((li) => li.classList.remove("hidden")); mf.remove(); };
  box.querySelectorAll(".logic-row").forEach((r) => (r.onclick = () => selectLogic(logic[+r.dataset.e])));
  if (state.explainSel && state.explainSel.sheet === sid && logic[state.explainSel.index]) renderLogicDetail(logic[state.explainSel.index], state.explainSel.index);
}
function selectLogic(e, opts) {
  if (!e) return;
  opts = opts || {};
  if (state.explainSheet !== state.sheetId || !$("#tab-explain").querySelector(".logic-row")) renderExplainTab();
  const logic = explainLogic(state.sheet), idx = logic.indexOf(e);
  state.explainSel = { sheet: state.sheetId, index: idx };
  hidePopup();
  highlightEntry(e, opts);
  renderLogicDetail(e, idx);
  $("#side").classList.remove("hidden"); showTab("explain");
  setStatus(`${e.output || ""} ${entryWords(e)}${e.expr ? ": " + shortExpr(e, 160) : ""}`);
}
function entryIds(e) {   // everything drawn that takes part in an entry: the explicit lists plus whatever the tree names
  const nets = new Set(), shapes = new Set(), texts = new Set();
  const add = (n) => {
    if (!n || typeof n !== "object") return;
    if (n.net != null) nets.add(n.net); if (n.field_net != null) nets.add(n.field_net);
    [n.shape, n.module_shape, n.field_shape].forEach((s) => { if (s != null) shapes.add(s); });
    arr(n.text_ids).forEach((t) => texts.add(t)); arr(n.taps).forEach((t) => { if (t && t.text) texts.add(t.text); });
    arr(n.inputs).forEach(add);
  };
  arr(e.net_ids).forEach((n) => nets.add(n)); arr(e.shape_ids).forEach((s) => shapes.add(s)); arr(e.text_ids).forEach((t) => texts.add(t));
  add(e); add(e.tree); add(e.device); arr(e.feeds).forEach((f) => { if (f && f.shape != null) shapes.add(f.shape); });
  if (e.text) texts.add(e.text);
  return { nets: [...nets], shapes: [...shapes], texts: [...texts] };
}
function unionBox(boxes) { let b = null; for (const x of boxes) { if (!x || x.length < 4) continue; b = b ? [Math.min(b[0], x[0]), Math.min(b[1], x[1]), Math.max(b[2], x[2]), Math.max(b[3], x[3])] : x.slice(0, 4); } return b; }
function highlightEntry(e, opts) {
  clearHighlights(false);
  const ids = entryIds(e), c = hlColor(), boxes = [];
  for (const nid of ids.nets) { const n = state.sheet._nets[nid]; if (!n) continue; const p = highlightNet(n, c); if (nid !== e.net) p.classList.remove("pulse"); boxes.push(n.bbox); }
  for (const sid of ids.shapes) { const sh = state.sheet._shapes[sid]; if (!sh || !sh.bbox) continue; highlightBox(sh.bbox, { color: c, noPulse: true, pad: 0.6 }); boxes.push(sh.bbox); }
  for (const tid of ids.texts) { const t = textById(tid); if (!t) continue; highlightBox(t.bbox, { color: c, noPulse: true, pad: 0.4, cls: "hl-text" }); boxes.push(t.bbox); }
  const ub = unionBox(boxes);
  if (ub && !(opts && opts.noZoom)) zoomToFit(bboxToSvg(ub));
  applyVB();
  return ub;
}
function renderLogicDetail(e, idx) {
  const box = $("#tab-explain");
  box.querySelectorAll(".logic-detail").forEach((d) => d.remove());
  box.querySelectorAll(".logic-row").forEach((r) => r.classList.toggle("active", +r.dataset.e === idx));
  const row = box.querySelector(`.logic-row[data-e="${idx}"]`); if (!row) return;
  const L = entryLink(e), dv = e.device && typeof e.device === "object" ? e.device : {};
  let h = "";
  if (e.kind === "continuation") {
    h += `<div>Leaves this sheet to <b>sheet ${esc(e.dest_sheet || "?")}</b>${e.pointer ? ` (pointer ${esc(e.pointer)})` : ""}${e.link_status ? `, link ${esc(e.link_status)}` : ""}.</div>`;
    h += `<div class="actions"><button class="small primary" data-follow="1" ${L ? "" : "disabled"}>Follow to sheet ${esc(e.dest_sheet || "?")}</button>${L ? "" : `<small class="muted">no link found for this pointer</small>`}</div>`;
  } else if (e.kind === "incoming") {
    h += `<div>Arrives from <b>sheet ${esc(e.from_sheet || "?")}</b>${e.pointer ? ` (pointer ${esc(e.pointer)})` : ""}${e.feeds_text ? ` and feeds ${esc(e.feeds_text)}` : ""}.</div>`;
    if (arr(e.used_in).length) h += `<div>Used in: ${e.used_in.map((u) => `<span class="chip" data-use="${esc(u)}" title="open this output">${esc(u)}</span>`).join("")}</div>`;
    h += `<div class="actions"><button class="small primary" data-follow="1" ${L ? "" : "disabled"}>Go to sheet ${esc(e.from_sheet || "?")}, where it is made</button></div>`;
  } else if (e.kind === "converter") {
    h += `<div>Converter ${esc((e.tree && e.tree.op) || "")}: takes ${esc(e.signal_in || "its input")} and gives ${esc(e.signal_out || "its output")}${dv.tag ? ` to process device tag <b>${esc(dv.tag)}</b>` : ""}${dv.cable ? `, cable ${esc(dv.cable)}${dv.terminals ? " terminals " + esc(dv.terminals) : ""}` : ""}.</div>`;
  } else if (e.kind === "dv") h += `<div>DeltaV Modbus point tapped on a logic wire. What is on that wire:</div>`;
  else if (e.kind === "annunciator") h += `<div>Annunciator window <b>${esc(e.output || "")}</b> is driven by:</div>`;
  else if (e.kind === "other") h += `<div>Process device output${dv.tag ? ` <b>${esc(dv.tag)}</b>` : ""}${dv.desc ? " " + esc(dv.desc) : ""}${dv.cable ? `, cable ${esc(dv.cable)}${dv.terminals ? " terminals " + esc(dv.terminals) : ""}` : ""}${arr(e.via).length ? `, through ${esc(e.via.join(" and "))}` : ""}.</div>`;
  if (arr(e.taps).length) h += `<div>DeltaV taps on the output wire: ${e.taps.map((t) => `<span class="chip tap"${t && t.text ? ` data-t="${esc(t.text)}"` : ""}>${esc((t && t.label) || "")}</span>`).join("")}</div>`;
  if (e.expr) h += `<div class="expr">${esc(e.expr)}</div>`;
  const leaves = [];
  if (e.tree && typeof e.tree === "object") h += `<h4>Logic outline</h4><div class="tree">${treeHtml(e.tree, 0, leaves)}</div>`;
  else if (e.kind !== "incoming") h += `<p class="muted">No logic tree was traced for this output${e.expr ? "; the one-line form above is all that is known" : ""}.</p>`;
  const d = el("div", { class: "logic-detail" }); d.innerHTML = h;
  row.after(d);
  d.querySelectorAll("[data-follow]").forEach((b) => (b.onclick = (ev) => { ev.stopPropagation(); followEntry(e); }));
  d.querySelectorAll(".chip[data-t]").forEach((c) => (c.onclick = () => { const t = textById(c.dataset.t); if (t) { selectText(t); highlightBox(t.bbox); } }));
  d.querySelectorAll(".chip[data-use]").forEach((c) => (c.onclick = () => { const u = explainLogic(state.sheet).find((x) => x.output === c.dataset.use); if (u) selectLogic(u); }));
  d.querySelectorAll("[data-leaf]").forEach((n) => (n.onclick = (ev) => { ev.stopPropagation(); d.querySelectorAll(".tline").forEach((x) => x.classList.toggle("active", x === n)); highlightLeaf(leaves[+n.dataset.leaf]); }));
  d.querySelectorAll("[data-go]").forEach((b) => (b.onclick = (ev) => { ev.stopPropagation(); followLeaf(leaves[+b.dataset.go]); }));
  d.querySelectorAll("[data-dossier]").forEach((b) => (b.onclick = (ev) => { ev.stopPropagation(); showLeafDossier(leaves[+b.dataset.dossier]); }));
  if (d.scrollIntoView) d.scrollIntoView({ block: "nearest" });
}
function tapsHtml(n) { return arr(n.taps).map((t) => `<span class="chip tap">${esc((t && t.label) || "")}</span>`).join(""); }
function treeHtml(n, depth, leaves) {
  // indented outline of a logic tree; every line is clickable (data-leaf = index into `leaves`)
  if (!n || typeof n !== "object" || depth > 40) return "";
  const i = leaves.push(n) - 1;
  const line = (inner, cls) => `<div class="tnode" style="--d:${depth}"><span class="tline ${cls || ""}" data-leaf="${i}" title="click to highlight on the drawing">${inner}</span></div>`;
  if (n.op != null || Array.isArray(n.inputs)) {
    const kind = str(n.kind), op = str(n.op);
    let head = kind === "gate" ? `<span class="op">${esc(op)}</span> gate` : kind === "timer" ? `timer <span class="op">${esc(op)}</span>` : kind === "converter" ? `converter <span class="op">${esc(op)}</span>` : kind === "module" ? `module <span class="op">${esc(op)}</span>` : `<span class="op">${esc(op || kind || "block")}</span>`;
    if (n.signal) head += ` = <span class="signal">${esc(n.signal)}</span>`;
    if (n.label && n.label !== n.signal) head += ` <small>${esc(n.label)}</small>`;
    head += tapsHtml(n);
    const ins = arr(n.inputs);
    return line(head) + (ins.length ? ins.map((c) => treeHtml(c, depth + 1, leaves)).join("") : `<div class="tnode" style="--d:${depth + 1}"><span class="open">no input wire found</span></div>`);
  }
  return line(leafHtml(n, i), n.cycle ? "cycle" : "");
}
function leafHtml(n, i) {
  if (n.cycle) return `<span class="cycle">feedback: loops back to logic already shown above${n.shape != null ? " (symbol " + esc(n.shape) + ")" : ""}; not followed further</span>` + tapsHtml(n);
  if (n.unlabelled || (!n.signal && !n.tag && !n.label && !n.device)) return `<span class="open">unlabelled wire</span>${n.net != null ? ` <small class="muted">(wire ${esc(n.net)})</small>` : ""}` + tapsHtml(n);
  let h = "";
  if (n.incoming || n.from_sheet) {
    h += `<span class="signal">${esc(n.signal || n.label || "")}</span> arrives from sheet <b>${esc(n.from_sheet || "?")}</b>${n.link_status ? ` <span class="badge ${esc(n.link_status)}">${esc(n.link_status)}</span>` : ""}`;
    return h + ` <button class="small" data-go="${i}" title="go to the sheet where this signal is made">Go</button>` + tapsHtml(n);
  }
  if (n.signal) h += `${n.limit ? esc(n.limit) + " " : ""}<span class="signal">${esc(n.signal)}</span>`;
  if (n.tag) {
    h += (h ? " from " : (n.limit ? esc(n.limit) + " " : "")) + `<b>${esc(n.tag)}</b>${n.desc ? " " + esc(n.desc) : ""}${n.device ? " (" + esc(n.device) + ")" : ""}${n.location ? ", " + esc(n.location) : ""}`;
    if (!n.signal && n.label && !str(n.device).includes(n.label)) h += ` (${esc(n.label)})`;
  } else if (n.label && !n.signal) h += `<span class="signal">${esc(n.label)}</span>${n.device ? " " + esc(n.device) : ""}`;
  else if (n.device && !n.signal) h += esc(n.device);
  if (n.module) h += ` <small class="muted">via ${esc(n.module)}</small>`;
  if (n.tag && !n.signal && n.module) h += ` <span class="open">no signal name written</span>`;
  if (n.tag) h += ` <button class="small" data-dossier="${i}" title="What is this device? Opens its note and dossier">?</button>`;
  return h + tapsHtml(n);
}
function leafWords(n) {
  if (!n) return "";
  if (n.cycle) return "feedback wire: loops back to logic already shown";
  if (n.op != null) return `${n.kind === "gate" ? n.op + " gate" : n.op}${n.signal ? " = " + n.signal : ""}`;
  if (n.incoming || n.from_sheet) return `${n.signal || n.label || ""} arrives from sheet ${n.from_sheet || "?"}`;
  const parts = [];
  if (n.limit) parts.push(n.limit);
  if (n.signal) parts.push(n.signal);
  if (n.tag) parts.push((n.signal ? "from " : "") + n.tag + (n.desc ? " " + n.desc : ""));
  if (n.device) parts.push("(" + n.device + ")");
  if (!n.signal && !n.tag && n.label) parts.push(n.label);
  if (n.module) parts.push("via " + n.module);
  return parts.join(" ") || "unlabelled wire";
}
function highlightLeaf(n) {
  if (!n) return;
  gHl.querySelectorAll(".hl-leaf").forEach((x) => x.remove());
  const c = "#ff6d00", boxes = [];
  [n.net, n.field_net].forEach((nid) => { const net = nid != null && state.sheet._nets[nid]; if (net) { highlightNet(net, c).classList.add("hl-leaf"); boxes.push(net.bbox); } });
  [n.shape, n.module_shape, n.field_shape].forEach((sid) => { const sh = sid != null && state.sheet._shapes[sid]; if (sh && sh.bbox) { highlightBox(sh.bbox, { color: c, pad: 0.6, cls: "hl-leaf" }); boxes.push(sh.bbox); } });
  arr(n.text_ids).forEach((tid) => { const t = textById(tid); if (t) { highlightBox(t.bbox, { color: c, pad: 0.4, cls: "hl-leaf" }); boxes.push(t.bbox); } });
  const ub = unionBox(boxes);
  if (!ub) return setStatus(`${leafWords(n)}: nothing drawn to highlight`, true);
  const b = bboxToSvg(ub), vb = state.vb;   // bring it into view, keeping the zoom when it fits
  if (b.x < vb.x || b.y < vb.y || b.x + b.w > vb.x + vb.w || b.y + b.h > vb.y + vb.h) {
    if (b.w > vb.w * 0.9 || b.h > vb.h * 0.9) zoomToFit(b); else setVB(b.x + b.w / 2 - vb.w / 2, b.y + b.h / 2 - vb.h / 2, vb.w, vb.h);
  }
  setStatus(leafWords(n));
}
function linkById(id) { return id ? arr(state.sheet.links).find((L) => L.id === id) || null : null; }
function entryLink(e) {   // the explicit link of a continuation / incoming entry, or the output label's own destination
  if (!e) return null;
  let L = linkById(e.link);
  if (!L && e.pointer_text) L = (state.sheet._linksOut[e.pointer_text] || [])[0] || null;
  if (!L) { const t = arr(e.text_ids).map(textById).find((x) => x && x.text === e.output); if (t) L = destinationsFor(t).out.find((x) => x.status !== "rejected" && x.dst_sheet) || null; }
  if (!L || !L.dst_sheet) return null;
  const d = userDecision(L.id); if (d && d.action === "reject") return null;
  return L;
}
async function followEntry(e) {
  // Signal path: follow a continuation to the sheet it goes to (or an incoming signal back to where it is made)
  // and open the matching logic entry there, so the signal can be walked sheet by sheet with its logic shown at each hop
  const L = entryLink(e); if (!L) return setStatus(`no link found for ${e.output || "this signal"}`, true);
  const want = e.kind === "incoming" ? "continuation" : "incoming";
  state.pathPending = { label: e.output, want, from: state.sheetId, sheet: L.dst_sheet };
  const d = userDecision(L.id), status = d ? (d.action === "confirm" ? "confirmed" : "rejected") : L.status;
  if (L.candidates && L.candidates.length > 1 && !AUTO_GO.has(status)) {   // several boxes: the engineer chooses, the path continues after the choice
    const t = textById(L.src_text) || { text: e.output || "" };
    return showChoices(t, [{ ...L, status }], null);
  }
  await navigate({ sheet: L.dst_sheet, text: L.dst_text, point: L.dst_point, label: e.output, status: "path",
                   note: want === "incoming" ? `signal ${e.output} continues from sheet ${state.sheetId}` : `signal ${e.output} is made on sheet ${L.dst_sheet}` });
}
function followLeaf(n) {   // 'Go' on an incoming leaf of the outline
  const label = n.signal || n.label || "";
  const e = explainLogic(state.sheet).find((x) => x.kind === "incoming" && x.output === label);
  if (e) return followEntry(e);
  const L = linkById(n.link); if (!L || !L.dst_sheet) return setStatus(`no link found for ${label || "this signal"}`, true);
  state.pathPending = { label, want: "continuation", from: state.sheetId, sheet: L.dst_sheet };
  navigate({ sheet: L.dst_sheet, text: L.dst_text, point: L.dst_point, label, status: "path" });
}
function showLeafDossier(n) {   // '?' on a device leaf: select its tag text so the "What this is" block and the dossier open
  const t = arr(n.text_ids).map(textById).find((x) => x && x.text === n.tag) || state.sheet.texts.find((x) => !x.frame && x.text === n.tag);
  if (!t) return setStatus(`${n.tag}: tag text not found on this sheet`, true);
  selectText(t); highlightBox(t.bbox, { pad: 0.6 });
  tipForText(t, null);
}
function arriveOnPath(pp) {
  // after a signal-path navigation: open the logic entry with the same label on the new sheet and name the hop in the trail
  const logic = explainLogic(state.sheet), key = normKey(pp.label || "");
  const e = logic.find((x) => x.kind === pp.want && normKey(x.output || "") === key) || logic.find((x) => x.kind === pp.want && normKey(x.signal || "") === key) || logic.find((x) => normKey(x.output || "") === key);
  const last = state.trail[state.trail.length - 1];
  if (!e) { if (last) { last.label = `${pp.label} from sheet ${pp.from}`; renderTrail(); } return setStatus(`sheet ${state.sheetId}: ${pp.label} is highlighted, but the explanation data has no logic entry for it`, true); }
  if (last) {
    last.label = e.kind === "incoming" ? `${pp.label} arrives from ${pp.from}${e.feeds_text ? ", feeds " + e.feeds_text : ""}${arr(e.used_in).length ? ", used in " + e.used_in.slice(0, 4).join(", ") : ""}` : `${pp.label} is made here${e.expr ? ": " + shortExpr(e, 60) : ""}`;
    renderTrail();
  }
  selectLogic(e);
}

// ------------------------------------------------------------------ init
async function init() {
  await detectMode();
  const pj = await loadJSON(DATA + "project.json");
  state.project = pj; state.sheets = pj.sheets; pj.sheets.forEach((s) => (state.sheetMeta[s.id] = s));
  state.allUserLinks = await loadAllUserLinks();
  $("#modeNote").textContent = state.serverMode
    ? "Running with the local Python server: manual links are saved to project/user_links.json."
    : "Running as a web page: manual links are kept in this browser only. Use Export to save them as a file (and Import to load them on another computer).";
  $("#btnExport").onclick = exportUserLinks;
  $("#btnImport").onclick = () => $("#importFile").click();
  $("#importFile").onchange = (e) => { if (e.target.files[0]) importUserLinks(e.target.files[0]); e.target.value = ""; };
  const sel = $("#sheetSelect");
  pj.sheets.forEach((s) => sel.appendChild(el("option", { value: s.id, text: `${s.id}  ${s.title || ""}` })));
  sel.onchange = () => navigate({ sheet: sel.value, label: sheetTitle(sel.value) });
  $("#btnPrev").onclick = () => { const i = state.sheets.findIndex((s) => s.id === state.sheetId); if (i > 0) navigate({ sheet: state.sheets[i - 1].id }); };
  $("#btnNext").onclick = () => { const i = state.sheets.findIndex((s) => s.id === state.sheetId); if (i < state.sheets.length - 1) navigate({ sheet: state.sheets[i + 1].id }); };
  $("#btnBack").onclick = goBack; $("#btnFwd").onclick = goForward;
  $("#btnFit").onclick = fitSheet;
  $("#btnExplain").onclick = openExplain;
  $("#btnSearch").onclick = doSearch; $("#searchBox").addEventListener("keydown", (e) => { if (e.key === "Enter") doSearch(); });
  $("#viewMode").onchange = applyViewMode;
  $("#btnSide").onclick = () => { $("#side").classList.toggle("hidden"); applyVB(); };
  $("#btnLink").onclick = () => { if (state.linkMode) { state.linkMode = null; $("#btnLink").classList.remove("primary"); setStatus("link mode cancelled"); } else if (state.selected && state.selected.sheet === state.sheetId) startLinkMode(textById(state.selected.text)); else setStatus("select the source text first, then press + Link", true); };
  document.querySelectorAll("#tabs button").forEach((b) => (b.onclick = () => showTab(b.dataset.tab)));
  document.addEventListener("keydown", (e) => {
    if (e.target.tagName === "INPUT" || e.target.tagName === "SELECT" || e.target.tagName === "TEXTAREA") return;
    if (e.key === "Backspace" || (e.altKey && e.key === "ArrowLeft")) { e.preventDefault(); goBack(); }
    else if (e.altKey && e.key === "ArrowRight") { e.preventDefault(); goForward(); }
    else if (e.key === "f" || e.key === "F") fitSheet();
    else if (e.key === "e" || e.key === "E") openExplain();
    else if (e.key === "+" || e.key === "=") zoomAt(view.clientWidth / 2 + view.getBoundingClientRect().left, view.clientHeight / 2 + view.getBoundingClientRect().top, 1.4);
    else if (e.key === "-") zoomAt(view.clientWidth / 2 + view.getBoundingClientRect().left, view.clientHeight / 2 + view.getBoundingClientRect().top, 0.7);
    else if (e.key === "Escape") { hidePopup(); state.linkMode = null; $("#btnLink").classList.remove("primary"); clearHighlights(true); }
    else if (e.key.startsWith("Arrow")) { const d = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] }[e.key]; setVB(state.vb.x + d[0] * state.vb.w * 0.1, state.vb.y + d[1] * state.vb.h * 0.1, state.vb.w, state.vb.h); }
  });
  renderSheetList(); loadIssues();
  // a shared address such as .../#075 opens that sheet; changing the hash later navigates too
  window.addEventListener("hashchange", () => { const id = decodeURIComponent(location.hash.slice(1)); if (id && id !== state.sheetId && state.sheetMeta[id]) navigate({ sheet: id, label: sheetTitle(id) }); });
  const first = (location.hash || "").replace("#", "") || (pj.sheets[0] && pj.sheets[0].id);
  if (first) { await loadSheet(first); fitSheet(); addTrail({ sheet: first, label: sheetTitle(first) }); }
  document.title = `${pj.name} – Schematic Viewer`;
  updateNavButtons();
}
window.viewer = { navigate, state, loadSheet, fitSheet, goBack, destinationsFor, onTextClick, onNetClick,
                  selectText, whatThisIs, openExplain, renderExplainTab, selectLogic, followEntry, showTip, hideTip, explainLogic: () => explainLogic(state.sheet) };
init().catch((e) => { setStatus("failed to load project: " + e.message, true); console.error(e); });
})();
