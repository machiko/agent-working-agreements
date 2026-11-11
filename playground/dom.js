// dom.js — 小型 DOM 建構工具。一律用 textContent／append 放入文字，不用 innerHTML，避免 XSS。

/**
 * @param {string} tag
 * @param {Record<string, unknown>} [attrs]
 * @param {...(Node | string | number | null | false | Array<Node | string>)} children
 * @returns {HTMLElement}
 */
export function h(tag, attrs = {}, ...children) {
  const el = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (value === null || value === undefined || value === false) continue;
    if (key === "class") el.className = String(value);
    else if (key === "dataset") Object.assign(el.dataset, value);
    else if (key.startsWith("on")) el.addEventListener(key.slice(2), value);
    else if (key === "value") el.value = String(value);
    else el.setAttribute(key, value === true ? "" : String(value));
  }
  for (const child of children.flat()) {
    if (child === null || child === undefined || child === false) continue;
    el.append(child instanceof Node ? child : String(child));
  }
  return el;
}

/** 把 text 依 [start, end) 切成前段、標記段、後段 */
export function highlight(text, range, className) {
  if (!range) return [text];
  const [start, end] = range;
  // 空字串命中（例如 {E} 只吃到行尾）也要看得到位置
  const marked = text.slice(start, end) || "␣";
  return [text.slice(0, start), h("mark", { class: className }, marked), text.slice(end)];
}

export function nonEmptyLines(text) {
  return text
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}
