// Browser test of the "Explain" user interface (Node + Playwright, chromium).
//   VIEWER_URL=http://127.0.0.1:8791 SHOTS=/tmp node tests/ui_explain.js
// Expects sheet 051 to carry the explain fixture (tests/fixtures/explain_051.json) and sheets 052/053 the engine output.
// Prints one JSON line "RESULT {...}" at the end and exits 1 when a check fails; screenshots go to $SHOTS/ui_explain_*.png.
const path = require("path");
const { chromium } = require("playwright");

const URL = process.env.VIEWER_URL || "http://127.0.0.1:8791";
const SHOTS = process.env.SHOTS || "/tmp";
const shot = (page, name) => page.screenshot({ path: path.join(SHOTS, `ui_explain_${name}.png`) });
const checks = {};
const failures = [];
function check(name, ok, info) { checks[name] = { ok: !!ok, info }; if (!ok) failures.push(name + (info ? ": " + JSON.stringify(info) : "")); }

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1600, height: 950 } });
  const errors = [];
  page.on("pageerror", (e) => errors.push("pageerror: " + e.message));
  page.on("console", (m) => { if (m.type() === "error") errors.push("console: " + m.text()); });
  const ready = (sid) => page.waitForFunction((s) => window.viewer && window.viewer.state.sheet && window.viewer.state.sheetId === s && !window.viewer.state.loading, sid, { timeout: 30000 });
  const centre = (text) => page.evaluate((txt) => {
    const t = window.viewer.state.sheet.texts.find((x) => x.text === txt && !x.frame);
    const r = document.querySelector(`rect.hit-text[data-id="${t.id}"]`).getBoundingClientRect();
    return { id: t.id, x: r.x + r.width / 2, y: r.y + r.height / 2 };
  }, text);
  const tipVisible = () => page.evaluate(() => !document.querySelector("#tip").classList.contains("hidden"));
  const tipText = () => page.evaluate(() => document.querySelector("#tipText").textContent);

  await page.goto(URL + "/#051");
  await ready("051");
  await page.waitForTimeout(400);

  // 1) click a field device tag: compact note next to the cursor + "What this is" block in the panel
  await page.evaluate(() => { const v = window.viewer; v.fitSheet(); });
  const c1 = await centre("03FZT03002");
  await page.mouse.click(c1.x, c1.y);
  await page.waitForFunction(() => !document.querySelector("#tip").classList.contains("hidden"), null, { timeout: 10000 }).catch(() => {});
  await page.waitForTimeout(500);
  let tip1 = await tipText();
  const tipWasVisible = await tipVisible();
  if (!tipWasVisible) tip1 = await page.evaluate(() => { const l = document.querySelector("#popup .what-line"); return l ? l.textContent : ""; });
  check("tip_shown_for_tag", /03FZT03002/.test(tip1) && /Nitric Acid/.test(tip1), (tipWasVisible ? "note: " : "popup header: ") + tip1);
  const what1 = await page.evaluate(() => (document.querySelector("#what") || {}).textContent || "");
  check("what_block_from_sheet_note", /Nitric Acid/.test(what1) && /LOOP TYPE AI1/.test(what1) && /3\/C650/.test(what1), what1.slice(0, 200));
  check("what_block_has_dossier_rows", /Written on/.test(what1) && (await page.$$eval("#what .row", (r) => r.length)) >= 1, what1.slice(-200));
  await shot(page, "1_tip");
  // "More" opens the Selection tab with the block
  if (tipWasVisible) await page.click("#tipMore"); else await page.evaluate(() => { const c = document.querySelector("#popClose"); if (c) c.click(); });
  check("more_opens_panel", await page.evaluate(() => document.querySelector("#tab-selection").classList.contains("active") && document.querySelector("#tip").classList.contains("hidden")));

  // 2) a wire: tip with the wire's words and the conductor explanation above the labels list
  const wirePos = await page.evaluate(() => { const r = document.querySelector("#canvas").getBoundingClientRect(); return { clientX: r.left + 500, clientY: r.top + 300 }; });
  await page.evaluate((pos) => window.viewer.onNetClick(36, pos), wirePos);
  await page.waitForTimeout(300);
  const tip2 = await tipText();
  check("tip_shown_for_wire", (await tipVisible()) && /03HZA03350/.test(tip2) && /(timer|T1 OFF)/i.test(tip2), tip2);
  const net2 = await page.evaluate(() => document.querySelector("#tab-selection").innerHTML);
  check("wire_explanation_in_panel", net2.indexOf("what-title") >= 0 && net2.indexOf("what-title") < net2.indexOf("Labels on this wire") && /T1 OFF 2 mins/.test(net2), null);
  await shot(page, "2_wire");

  // Esc closes the note
  await page.keyboard.press("Escape");
  check("esc_closes_tip", !(await tipVisible()));

  // 3) Explain sheet: summary, facts, logic rows
  await page.click("#btnExplain");
  await page.waitForTimeout(300);
  const ex = await page.evaluate(() => ({ active: document.querySelector("#tab-explain").classList.contains("active"), html: document.querySelector("#tab-explain").innerText, rows: [...document.querySelectorAll("#tab-explain .logic-row")].map((r) => r.innerText.replace(/\s+/g, " ").trim()) }));
  check("explain_tab_open", ex.active && /Functional logic diagram 051/.test(ex.html) && /Facts read from the drawing/i.test(ex.html), ex.html.slice(0, 120));
  check("explain_rows_listed", ex.rows.length >= 6 && ex.rows.some((r) => /^3B → 052 AND\(/.test(r)) && ex.rows.some((r) => /^3A ← 052/.test(r)) && ex.rows.some((r) => /^03ZRT03581 1-5V → 4-20mA/.test(r)), ex.rows);
  await shot(page, "3_explain");

  // 4) click the 3B row: wiring highlighted, outline rendered
  await page.evaluate(() => { const row = [...document.querySelectorAll("#tab-explain .logic-row")].find((r) => r.innerText.startsWith("3B")); row.click(); });
  await page.waitForTimeout(500);
  const hl = await page.evaluate(() => ({ nets: document.querySelectorAll("#hl .hl-net").length, boxes: document.querySelectorAll("#hl .hl-box").length, vb: window.viewer.state.vb,
    lines: [...document.querySelectorAll("#tab-explain .tline")].map((n) => n.innerText.replace(/\s+/g, " ").trim()), active: (document.querySelector("#tab-explain .logic-row.active") || {}).innerText, follow: !!document.querySelector("[data-follow]") }));
  check("row_click_highlights", hl.nets >= 25 && hl.boxes >= 40, { nets: hl.nets, boxes: hl.boxes });
  check("row_click_zooms_to_logic", hl.vb.w > 150 && hl.vb.w < 420, hl.vb);
  check("outline_rendered", hl.lines.length >= 25 && hl.lines[0].startsWith("AND gate") && hl.lines.some((l) => /HIGH 03TZA03052A from 03TZT03052/.test(l)) && hl.lines.some((l) => /3A arrives from sheet 052/.test(l)) && hl.lines.some((l) => /timer T1 OFF 2 mins = 03HZA03350/.test(l)) && hl.lines.some((l) => /no signal name written/.test(l)), hl.lines.slice(0, 12));
  check("follow_button_present", hl.follow && /3B/.test(hl.active || ""), hl.active);
  await shot(page, "4_3B");

  // 4b) click a leaf of the outline: that input is highlighted in the second colour and named in the status line
  await page.evaluate(() => { const n = [...document.querySelectorAll("#tab-explain .tline")].find((x) => /^03FZA03012/.test(x.innerText)); n.click(); });
  await page.waitForTimeout(300);
  const leaf = await page.evaluate(() => ({ leaf: document.querySelectorAll("#hl .hl-leaf").length, status: document.querySelector("#statusMsg").textContent, active: (document.querySelector("#tab-explain .tline.active") || {}).innerText }));
  check("leaf_click_highlights_input", leaf.leaf >= 2 && /03FZA03012 from 03FZT03012/.test(leaf.status), leaf);
  await shot(page, "4b_leaf");

  // 5) Follow to sheet 052: arrives, selects the incoming 3B entry there, trail gets the hop
  await page.click("#tab-explain [data-follow]");
  await ready("052");
  await page.waitForTimeout(700);
  const arr = await page.evaluate(() => { const v = window.viewer; const sel = v.state.explainSel; const e = sel && v.explainLogic()[sel.index];
    return { sheet: v.state.sheetId, tab: document.querySelector("#tab-explain").classList.contains("active"), entry: e && { kind: e.kind, output: e.output, from: e.from_sheet },
      detail: (document.querySelector("#tab-explain .logic-detail") || {}).innerText, trail: v.state.trail.slice(-1)[0], hl: document.querySelectorAll("#hl .hl-net").length, status: document.querySelector("#statusMsg").textContent }; });
  check("follow_arrives_on_052", arr.sheet === "052" && arr.tab, { sheet: arr.sheet, tab: arr.tab });
  check("follow_selects_incoming_entry", arr.entry && arr.entry.kind === "incoming" && arr.entry.output === "3B" && arr.entry.from === "051" && /Arrives from sheet 051/.test(arr.detail || ""), arr.entry);
  check("follow_adds_trail_hop", arr.trail && arr.trail.sheet === "052" && arr.trail.status === "path" && /3B arrives from 051/.test(arr.trail.label), arr.trail);
  check("incoming_highlighted", arr.hl >= 1, arr.hl);
  await shot(page, "5_follow");

  // 5b) from the incoming entry, go back to the sheet where the signal is made: the continuation entry opens there
  await page.click("#tab-explain [data-follow]");
  await ready("051");
  await page.waitForTimeout(600);
  const back = await page.evaluate(() => { const v = window.viewer; const sel = v.state.explainSel; const e = sel && v.explainLogic()[sel.index]; return { sheet: v.state.sheetId, entry: e && { kind: e.kind, output: e.output }, trail: v.state.trail.slice(-1)[0].label }; });
  check("go_back_selects_continuation", back.sheet === "051" && back.entry && back.entry.kind === "continuation" && back.entry.output === "3B" && /3B is made here/.test(back.trail), back);

  // 6) Sheets tab: the Explain button of a row opens the explanation of that sheet (engine data on 053)
  await page.click('#tabs button[data-tab="sheets"]');
  await page.click('#tab-sheets .row[data-id="053"] [data-explain]');
  await ready("053");
  await page.waitForTimeout(500);
  const s053 = await page.evaluate(() => ({ tab: document.querySelector("#tab-explain").classList.contains("active"), rows: document.querySelectorAll("#tab-explain .logic-row").length, text: document.querySelector("#tab-explain").innerText.slice(0, 160) }));
  check("sheets_tab_explain_button", s053.tab && s053.rows >= 1 && /Sheet 053/.test(s053.text), s053);
  await shot(page, "6_sheet053");

  // 7) glossary fallback: a caption with no sheet note and no identifier
  await page.evaluate(() => window.viewer.navigate({ sheet: "051" }));
  await ready("051");
  await page.waitForTimeout(300);
  await page.evaluate(() => { const v = window.viewer; const t = v.state.sheet.texts.find((x) => x.text === "CONTROL ROOM" && !x.frame); v.selectText(t); });
  await page.waitForTimeout(600);
  const gl = await page.evaluate(() => (document.querySelector("#what") || {}).textContent || "");
  check("glossary_fallback", /CONTROL ROOM/.test(gl) && /Glossary term/.test(gl) && /Source:/.test(gl), gl.slice(0, 200));
  // and a text nothing is written about: the block says so instead of inventing
  const silent = await page.evaluate(async () => {
    // find a drawing text about which nothing is written (no note, no dossier entry, no glossary term)
    const v = window.viewer;
    for (const name of ["1.", "2.", "NOTES", "2 mins", "CONTROL ROOM"]) {
      const t = v.state.sheet.texts.find((x) => x.text === name && !x.frame);
      if (!t) continue;
      const w = await v.whatThisIs(t);
      if (!w) { v.selectText(t); return name; }
    }
    return null;
  });
  await page.waitForTimeout(500);
  const none = silent ? await page.evaluate(() => (document.querySelector("#what") || {}).textContent || "") : "";
  check("nothing_written_is_said", !silent || new RegExp('Nothing more is written about "' + silent.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + '"').test(none), silent ? none.slice(0, 200) : "every candidate text has a note (nothing to check)");

  check("no_page_errors", errors.length === 0, errors);
  await browser.close();
  console.log("RESULT " + JSON.stringify({ ok: failures.length === 0, failures, checks }));
  process.exit(failures.length ? 1 : 0);
})().catch((e) => { console.log("RESULT " + JSON.stringify({ ok: false, failures: ["exception: " + e.message], checks })); process.exit(1); });
