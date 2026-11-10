export const processed = [];
let pending = Promise.resolve();

// 非同步處理：工作會在背景依序完成
export function enqueue(job) {
  pending = pending.then(() => new Promise((resolve) => {
    setTimeout(() => { processed.push(job); resolve(); }, 20 + Math.random() * 30);
  }));
}

// 等待目前排入的工作全部處理完
export function drain() {
  return pending;
}
