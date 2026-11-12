// 極簡的指標登錄表：每組不同的標籤組合都是一條獨立的時間序列
const registry = new Map();

export function counter(name) {
  return {
    inc(labels = {}, value = 1) {
      const key = JSON.stringify([name, labels]);
      const prev = registry.get(key);
      registry.set(key, { name, labels, value: (prev ? prev.value : 0) + value });
    },
  };
}

export function allSeries() {
  return [...registry.values()];
}
