---
category: vue
tier: optional
label: "Vue 與前端地雷"
summary: "7 條 Vue 3、Pinia 與 Vite 的正式環境事故，例如解構丟失響應性、動態 class 被 purge、未清理的監聽器。只在碰到前端檔時載入"
stack: vue
paths:
  - "**/*.vue"
  - "**/*.ts"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.tsx"
  - "vite.config.*"
---

# Vue 與前端地雷

> 每一條都是實際發生過的事故，大多「local 開發正常、CI 通過，但在 build 或正式環境引發事故」。格式：症狀 → 根因 → 怎麼做。

## 解構 `props` 或 store 丟失響應性

- **症狀：** 畫面第一次渲染正常，但父組件傳入的新 prop 或 store 狀態變動時，子組件畫面完全不更新，也不會報錯。
- **根因：** `props` 與 `reactive()` 是 JavaScript Proxy。一旦使用 ES6 解構語法（`const { count } = props` 或 `const { user } = userStore`），拿到的只是當下的原始純值（primitive），Proxy 的 getter 連結就斷掉了。
- **怎麼做：** 需要解構時，一律使用 `toRefs(props)` 或 `storeToRefs(userStore)`。或是直接以 `props.count`、`userStore.user` 存取。寫 `computed` 時在 getter 內部存取屬性，確保相依性被追蹤。

## 直接修改 Prop 物件的屬性

- **症狀：** Console 噴出 `[Vue warn]: Set operation on key failed: target is readonly`，或狀態在父子組件間不同步，其他監聽該 prop 的 computed 莫名不觸發。
- **根因：** 物件或陣列 prop 透過 reference 傳遞。子組件直接指派屬性（例如 `props.item.name = 'new'`）破壞了單向資料流（one-way data flow）。
- **怎麼做：** 永遠使用 `emit('update:item', ...)` 或 Vue 3.4+ 的 `defineModel()`。需要本地表單編輯時，在 `setup` 內用 `reactive({ ...props.item })` 或 `structuredClone` 建立本地副本，按下儲存時才 emit 給父層。

## Tailwind CSS 動態 Class 被 Purge 移除

- **症狀：** 本地開發時按鈕顏色、badge 狀態顯示正常；`npm run build` 部署到正式環境後，所有動態樣式全部失效變空白。
- **根因：** Tailwind 編譯器在打包時用正規表達式掃描原始碼裡「完整無缺的 class 字串」。用字串拼接（例如 `:class="'bg-' + status + '-500'"`）時，掃描器找不到完整單詞，在生產環境就把該 class 當成未使用而移除。
- **怎麼做：** 原始碼中一律寫出完整的 class 名稱。狀態對照表寫成常數物件：
  ```javascript
  const STATUS_CLASSES = {
    success: 'bg-green-500 text-white',
    error: 'bg-red-500 text-white',
  }
  ```
  在 template 中以 `:class="STATUS_CLASSES[status]"` 引用。

## Pinia Store 在 Action 外直接賦值

- **症狀：** 狀態變更無法被 Pinia devtools 追蹤、持久化插件未被觸發，或在跨頁面時狀態殘留。
- **根因：** 直接在組件中寫 `userStore.items = []` 跳過了 store action 的邏輯校驗與 side effect。在 SSR 渲染時，在 setup 外部直接取得並修改 store 還可能造成跨請求狀態污染。
- **怎麼做：** 狀態的變更與重設一律封裝在 store 的 actions 內；Option Store 重設用 `store.$reset()`，Setup Store 則提供明確的 `reset()` action。組件引用 store 資料應優先作為唯讀依賴。

## `onMounted` 內的全域監聽與 Timer 造成記憶體洩漏

- **症狀：** SPA 頁面切換數次後，瀏覽器記憶體飆高，點擊事件觸發多次（點一次按鈕執行數次 handler），甚至在已離開的頁面噴出 DOM 找不到的錯誤。
- **根因：** `window.addEventListener`、`document.addEventListener` 或 `setInterval` 是全域宿主物件的生命週期，組件 unmount 時 Vue 不會自動回收。
- **怎麼做：** 掛載的監聽器與 timer 必須成對在 `onUnmounted`（或 `onBeforeUnmount`）中呼叫 `removeEventListener` 與 `clearInterval`。或優先使用 `@vueuse/core` 的 `useEventListener`，它會在組件銷毀時自動解除註冊。

## Vite / SSR 建構時存取 Browser 全域物件

- **症狀：** `npm run dev` 正常，但 `npm run build` 或預渲染（SSG/SSR）時噴錯 `ReferenceError: window is not defined` 或 `document is not defined`。
- **根因：** 在 `<script setup>` 的頂層（top-level scope）直接讀取了 `window`、`document` 或 `localStorage`。打包工具在 build 階段是在 Node.js 環境中載入模組，此時瀏覽器環境並不存在。
- **怎麼做：** 存取瀏覽器專屬 API 的邏輯，一律收進 `onMounted()` 生命週期內（`onMounted` 只會在客戶端執行），或在存取前加上環境守衛 `if (typeof window !== 'undefined')`。

## 第三方程式庫實例放進 `ref()` 導致代理過深

- **症狀：** 把 Chart.js、Monaco Editor、Leaflet 地圖或大型複雜物件賦值給 `ref()` 後，組件操作極度卡頓，或噴出遞迴 stack overflow 警告與 `this` 指向錯誤。
- **根因：** `ref()` 會對物件做深度代理（Deep Reactive Proxy），把第三方套件內部複雜的原型鏈與私有屬性全都包裝，破壞了其內部機制並帶來沉重的效能開銷。
- **怎麼做：** 儲存非純資料的大型物件、第三方實例或 DOM 節點時，一律使用 `shallowRef()` 或 `markRaw()`。
