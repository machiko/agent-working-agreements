---
category: frontend
tier: optional
label: "現代前端與組件化地雷"
summary: "跨框架通用前端事故：React/Vue/Next.js/Svelte 組件卸載記憶體洩漏、Tailwind 動態 class 被 purge、SSR/預渲染 window/document 報錯、Prop 屬性突變破壞單向資料流、響應性解構丟失。只在碰到前端檔時載入"
stack: frontend
paths:
  - "**/*.vue"
  - "**/*.jsx"
  - "**/*.tsx"
  - "**/*.svelte"
  - "**/*.html"
  - "vite.config.*"
  - "next.config.*"
  - "nuxt.config.*"
  - "svelte.config.*"
---

# 現代前端與組件化地雷

> 適用於 React、Next.js、Vue、Nuxt、Svelte 等現代組件化前端架構。格式：症狀 → 根因 → 怎麼做。

## Tailwind CSS 動態 Class 被 Purge 移除

- **症狀：** 本地開發時按鈕顏色、badge 狀態顯示正常；打包部署到正式環境（`npm run build`）後，所有動態樣式全部失效變空白。
- **根因：** Tailwind 編譯器在打包時以靜態正則表達式掃描原始碼裡「完整無缺的 class 字串」。使用字串拼接（例如 React/Vue 中的 `` `bg-${status}-500` `` 或 `:class="'bg-' + status + '-500'"`）時，掃描器找不到完整單詞，在生產環境就把該 class 當成未使用而移除。
- **怎麼做：** 原始碼中一律寫出完整的 class 名稱。狀態對照表寫成常數物件：
  ```javascript
  const STATUS_CLASSES = {
    success: 'bg-green-500 text-white',
    error: 'bg-red-500 text-white',
    warning: 'bg-amber-500 text-white',
  };
  ```
  在 JSX/模板中以 `STATUS_CLASSES[status]` 引用，絕不以動態字串拼接 class 名稱。

## 組件卸載時全域監聽與 Timer 未清理造成記憶體洩漏

- **症狀：** SPA 或多頁面切換數次後，瀏覽器記憶體飆高，點擊事件觸發多次（點一次按鈕重複執行數次 handler），甚至在離開頁面後噴出 DOM 找不到或狀態在已卸載組件更新的錯誤。
- **根因：** `window.addEventListener`、`document.addEventListener` 或 `setInterval` 是瀏覽器全域宿主物件的生命週期，組件被卸載時框架不會自動回收未取消的監聽。
- **怎麼做：**
  - **React：** 在 `useEffect` 的 cleanup function 中明確執行成對移除：
    ```javascript
    useEffect(() => {
      const handler = () => { /* ... */ };
      window.addEventListener('resize', handler);
      return () => window.removeEventListener('resize', handler);
    }, []);
    ```
  - **Vue：** 在 `onUnmounted` 中明確呼叫 `removeEventListener` / `clearInterval`，或優先使用 `@vueuse/core` 的 `useEventListener`。

## SSR / 預渲染建構時存取 Browser 全域物件

- **症狀：** 本地 `npm run dev` 正常，但 `npm run build` 或預渲染（Next.js / Nuxt / SvelteKit / Astro SSG）時噴錯 `ReferenceError: window is not defined` 或 `document / localStorage is not defined`。
- **根因：** 在組件頂層作用域（Top-level scope）或模組載入時直接讀取了瀏覽器專用物件。現代全端打包工具在 build 階段是在 Node.js/Bun 環境中預先載入執行模組，此時瀏覽器環境並不存在。
- **怎麼做：**
  - 瀏覽器專用物件一律延遲至客戶端掛載生命週期（React `useEffect`、Vue `onMounted`）內部才存取。
  - 需要在非生命週期中呼叫時，必須加上環境守衛：
    ```javascript
    if (typeof window !== 'undefined') {
      const token = localStorage.getItem('auth_token');
    }
    ```

## 直接修改 Prop 物件屬性破壞單向資料流

- **症狀：** 狀態在父子組件間不同步、其他衍生屬性（Computed / Memo）莫名不重新計算，或在嚴格模式下噴出警告：`target is readonly`。
- **根因：** 物件或陣列 prop 透過記憶體位址（Reference）傳遞。子組件直接指派其內部屬性（如 `props.item.name = 'new'`）破壞了框架的單向資料流（One-way Data Flow），繞過了父層的狀態管理。
- **怎麼做：** 永遠遵循由下而上的事件通知（React 呼叫傳入的 `onChange(newItem)`，Vue 呼叫 `emit('update:item', newItem)`）。在子組件內部編輯時，先以深拷貝或展開運算子（`structuredClone` 或 `{ ...props.item }`）建立本地狀態副本，儲存時再向父層發送更新。

## 解構丟失響應性與狀態追蹤

- **症狀：** 畫面初次渲染正常，但狀態或 Store 變動時，子組件畫面完全不更新，且 console 沒有任何錯誤。
- **根因：** 現代響應式狀態（Vue `reactive`/`props`、Solid Signals、MobX）底層使用 Proxy 或 Getter 追蹤相依性。一旦使用 ES6 解構語法（`const { count } = state`），拿到的只是當下的原始純值（Primitive），Proxy 的 getter 連結就斷掉了。
- **怎麼做：** 在響應式物件中，直接以屬性存取（如 `state.count`），或使用框架提供的解構包裝工具（如 Vue `toRefs`、`storeToRefs`）；在 React 中則注意不要將 state 物件解構成多個孤立變數而在閉包內漏記 dependency。
