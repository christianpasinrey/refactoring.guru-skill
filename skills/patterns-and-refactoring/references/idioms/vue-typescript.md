# Vue · Nuxt · TypeScript

[← back to router](../framework-idioms.md)

See also [../frontend-patterns.md](../frontend-patterns.md) for framework-neutral frontend
patterns (state placement, data fetching, rendering strategies).

---

## What Vue already gives you

| Pattern | Where it already lives | Do this, not that |
|---|---|---|
| **Observer** | The reactivity system: `ref`, `reactive`, `computed`, `watch`, `watchEffect` | Never build an event bus for state. Reactivity *is* the observer |
| **Proxy** | Vue 3 reactivity is literally implemented with `Proxy` | |
| **Strategy** | A composable, or a function passed as a prop | A composable is a strategy with state |
| **Template Method** | Scoped slots — the parent owns the algorithm, the consumer supplies the steps | |
| **Composite** | Recursive components; the component tree itself | |
| **Decorator** | Wrapper components; composables composing other composables | |
| **Registry / Provider** | `provide` / `inject`; Pinia stores | `provide`/`inject` for tree-scoped values; Pinia for app-wide |
| **Command** | Pinia actions; emitted events | |
| **Facade** | A composable exposing a narrow API over complex logic | The primary unit of reuse in Vue 3 |
| **Adapter** | An API client layer mapping server DTOs to view models | |
| **State** | A discriminated union in a store, or XState | Not four independent booleans — see below |
| **Memento** | History array in a store; `@vueuse/core`'s `useRefHistory` | Already implemented, do not write it |
| **Flyweight** | `v-memo`; `shallowRef` for large immutable structures | |
| **Iterator** | `v-for` with a stable `:key` | |
| **Lazy Load / Proxy** | `defineAsyncComponent`; route-level code splitting | |
| **Singleton** | A Pinia store — one instance per app | |
| **Null Object** | `?.`, `??`, `withDefaults` on props | |

### Composables are the pattern layer

In Vue 3, the answer to "which pattern?" is usually "a composable". `useUser()`,
`usePagination()`, `useDebouncedSearch()` — each is a Strategy, a Facade, or a Template Method
depending on what it does, expressed as a function that returns reactive state.

**One concern per composable.** A `useEverything()` is a God Object with a hook's name.

**Do not write:** a class-based service layer for the frontend, an event bus for cross-component
state, a hand-rolled reactivity system, or Options API mixins in new code (they have the same
name-collision problems that killed mixins elsewhere).

---

## VueUse before writing anything

`@vueuse/core` implements roughly 200 composables. Before writing a composable for debouncing,
local storage, media queries, intersection observers, clipboard, history/undo, async state, or
event listeners — check whether it already exists. It almost always does, handles the SSR and
cleanup edge cases you would miss, and is tree-shakeable.

This is the same rule as "check the framework first", applied one layer up.

---

## Pinia and state placement

Ask in this order and stop at the first yes:

1. **Can it be derived?** → `computed`. Do not store it.
2. **One component?** → `ref` in that component.
3. **A few nearby components?** → `provide`/`inject`, or props down / events up.
4. **Server data?** → a server-state library (TanStack Query, Pinia Colada, `useFetch`/`useAsyncData` in Nuxt). **Not a Pinia store.**
5. **Genuinely global client state?** → a Pinia store.

**The most valuable rule here: server cache is not client state.** Putting fetched data in
Pinia means hand-rolling caching, invalidation, deduplication, retries and staleness. This one
distinction removes most of a typical store.

**State machines over boolean soup.** A component with `isLoading`, `isError`, `isSuccess`,
`isEditing` has 16 representable combinations, most illegal. A `status` discriminated union has
four. Make illegal states unrepresentable — see
[../functional-patterns.md](../functional-patterns.md#types-as-design).

---

## Vue reactivity gotchas that look like pattern problems

| Symptom | Cause |
|---|---|
| Destructuring a `reactive()` object loses reactivity | Use `toRefs()`, or prefer `ref()` |
| A `watch` on an object does not fire | Needs `deep: true`, or watch a getter |
| A `computed` recomputes constantly | It has a side effect, or depends on a non-stable reference |
| Props mutate and Vue warns | Props are one-way. Emit an event or use `defineModel` |
| `provide`/`inject` value is not reactive | Provide a `ref`, not its `.value` |
| Whole subtree re-renders on any change | One large reactive object. Split by change frequency |

None of these are design problems, but they are frequently misdiagnosed as such and "fixed"
with an unnecessary store or event bus.

---

## Nuxt specifics

| Pattern | Where it lives |
|---|---|
| **Server-side data fetching** | `useAsyncData` / `useFetch` — deduped, SSR-aware, cached by key |
| **BFF** | `server/api/` routes — a backend shaped for this frontend, in the same project |
| **Plugin / Microkernel** | Nuxt modules and plugins |
| **Front Controller** | File-based routing |
| **Chain of Responsibility** | Route middleware; server middleware |
| **Two Step View** | Layouts |
| **Lazy Load** | Automatic route-based code splitting; `Lazy` component prefix |
| **External Configuration Store** | `runtimeConfig` — public and private split |

**The Nuxt-specific trap:** state created at module scope on the server is **shared between
requests and therefore between users**. Always create state inside `useState()` or a setup
context. A module-level `ref` is a cross-user data leak, not a singleton.

---

## Going against the grain

- An event bus for state that reactivity already handles.
- A `services/` layer of classes replicating what composables do better.
- Options API mixins in new code.
- Storing server responses in Pinia instead of a query library.
- `watch` chains that mutate other state — usually a missing `computed`.
- Hand-rolled composables that VueUse already ships.
- Module-scope mutable state in a Nuxt app.
- Deep `provide`/`inject` chains where props would be traceable.
