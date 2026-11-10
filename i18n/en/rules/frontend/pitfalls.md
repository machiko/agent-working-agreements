---
source_sha256: 1c07600051c37995e951dc4871e7166771a5ecf7206ac622eef745fe1f4dcaa7
category: frontend
tier: optional
label: "Modern frontend and component pitfalls"
summary: "Cross-framework frontend incidents: memory leaks on React/Vue/Next.js/Svelte component unmount, dynamic Tailwind classes purged, window/document errors during SSR/prerendering, prop mutation breaking one-way data flow, and reactivity lost through destructuring. Loaded only when touching frontend files"
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
incidents:
  - "Dynamically concatenated Tailwind classes were purged in the production build, and all the styles disappeared"
  - "Accessing window during SSR or prerendering broke the build"
  - "Global listeners and timers weren't cleared on component unmount; memory spiked and handlers fired repeatedly"
last_reviewed: 2026-11-10
enforced_by:
  - audit:dynamic-tailwind-class
---

# Modern frontend and component pitfalls

> Applies to modern component-based frontends such as React, Next.js, Vue, Nuxt, and Svelte. Format: symptom → root cause → how.

## Dynamic Tailwind CSS classes removed by purge

- **Symptom:** Button colors and badge states look fine in local dev; after building and deploying to production (`npm run build`), every dynamic style is gone and renders blank.
- **Root cause:** At build time the Tailwind compiler scans source code with static regexes for "complete, intact class strings". With string concatenation (e.g. `` `bg-${status}-500` `` in React/Vue, or `:class="'bg-' + status + '-500'"`), the scanner never sees the full word, so in production the class is treated as unused and removed.
- **How:** Always write full class names in source. Put state mappings in a constant object:
  ```javascript
  const STATUS_CLASSES = {
    success: 'bg-green-500 text-white',
    error: 'bg-red-500 text-white',
    warning: 'bg-amber-500 text-white',
  };
  ```
  Reference it as `STATUS_CLASSES[status]` in JSX/templates; never build class names by dynamic string concatenation.

## Memory leaks from global listeners and timers not cleaned up on unmount

- **Symptom:** After switching between SPA views or pages a few times, browser memory spikes and click events fire multiple times (one click runs the handler several times), and you may even get errors after leaving the page about missing DOM nodes or state updates on an unmounted component.
- **Root cause:** `window.addEventListener`, `document.addEventListener`, and `setInterval` live on the lifecycle of the browser's global host objects; when a component unmounts, the framework does not reclaim listeners that were never removed.
- **How:**
  - **React:** Remove each one explicitly in the `useEffect` cleanup function:
    ```javascript
    useEffect(() => {
      const handler = () => { /* ... */ };
      window.addEventListener('resize', handler);
      return () => window.removeEventListener('resize', handler);
    }, []);
    ```
  - **Vue:** Explicitly call `removeEventListener` / `clearInterval` in `onUnmounted`, or prefer `useEventListener` from `@vueuse/core`.

## Accessing browser globals during SSR / prerender builds

- **Symptom:** Local `npm run dev` works, but `npm run build` or prerendering (Next.js / Nuxt / SvelteKit / Astro SSG) throws `ReferenceError: window is not defined` or `document / localStorage is not defined`.
- **Root cause:** Browser-only objects are read directly in a component's top-level scope or at module load. Modern full-stack bundlers preload and execute modules in a Node.js/Bun environment during build, where no browser environment exists.
- **How:**
  - Always defer access to browser-only objects until inside a client mount lifecycle (React `useEffect`, Vue `onMounted`).
  - When you must call them outside a lifecycle, add an environment guard:
    ```javascript
    if (typeof window !== 'undefined') {
      const token = localStorage.getItem('auth_token');
    }
    ```

## Mutating prop object properties directly breaks one-way data flow

- **Symptom:** State gets out of sync between parent and child, derived values (Computed / Memo) mysteriously stop recomputing, or strict mode warns `target is readonly`.
- **Root cause:** Object and array props are passed by reference. A child assigning to their inner properties directly (e.g. `props.item.name = 'new'`) breaks the framework's one-way data flow and bypasses the parent's state management.
- **How:** Always notify upward through events (React calls the passed-in `onChange(newItem)`, Vue calls `emit('update:item', newItem)`). To edit inside the child, first make a local copy of the state with a deep clone or spread (`structuredClone` or `{ ...props.item }`), and send the update to the parent on save.

## Destructuring loses reactivity and state tracking

- **Symptom:** The first render is correct, but when state or the store changes, the child component's view doesn't update at all, and the console shows no errors.
- **Root cause:** Modern reactive state (Vue `reactive`/`props`, Solid Signals, MobX) tracks dependencies with Proxies or getters underneath. Once you use ES6 destructuring (`const { count } = state`), you only get the current primitive value, and the link to the Proxy's getter is cut.
- **How:** On reactive objects, access properties directly (e.g. `state.count`) or use the framework's destructuring helpers (e.g. Vue `toRefs`, `storeToRefs`); in React, don't destructure a state object into several standalone variables and then miss a dependency inside a closure.
